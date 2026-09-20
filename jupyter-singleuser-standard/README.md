# Jupyter SingleUser Standard Image

This component builds the internal Jupyter Notebook image used by `jupyter-user01`, `jupyter-user02`, and later user Pods.

## Image

Base image:

```text
asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-sample:4.2.0
```

Standard image:

```text
asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-standard:4.2.0-r1-test
```

Included software:

- Google Cloud CLI
- git
- jq
- unzip
- pandas
- pyarrow
- db-dtypes
- google-cloud-bigquery
- google-cloud-storage

The image keeps the upstream `jovyan` user and `/home/jovyan` home directory.

## 1. Build

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09/jupyter-singleuser-standard
chmod +x build-gcloud.sh
./build-gcloud.sh
```

The build is regional (`asia-northeast3`) and explicitly uses the existing regional staging bucket to avoid organization policy failures such as:

```text
HTTPError 412: 'us' violates constraint 'constraints/gcp.resourceLocations'
```

The validated source-read IAM binding is applied idempotently by the script:

```bash
gcloud storage buckets add-iam-policy-binding \
  gs://prj-b-cicd-local-236d-datalake-build-staging \
  --member="serviceAccount:587273205772-compute@developer.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

This fixes the Cloud Build source error:

```text
587273205772-compute@developer.gserviceaccount.com does not have storage.objects.get access
```

## 2. Verify Artifact Registry

```bash
gcloud artifacts docker images list \
  asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform \
  --include-tags \
  --filter="package~jupyterhub-k8s-singleuser-standard"
```

```bash
gcloud artifacts docker images describe \
  asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-standard:4.2.0-r1-test
```

## 3. Optional standalone Pod test

`sbx01` has a ResourceQuota requiring CPU and memory limits, so do not use a bare `kubectl run` without resources.

```bash
kubectl -n sbx01 apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: jupyter-image-check
spec:
  restartPolicy: Never
  containers:
  - name: jupyter-image-check
    image: asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-standard:4.2.0-r1-test
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "1"
        memory: "2Gi"
EOF
```

```bash
kubectl -n sbx01 exec jupyter-image-check -- sh -c '
whoami
echo HOME=$HOME
python --version
gcloud --version | head -5
git --version
jq --version
python -c "import pandas, pyarrow; from google.cloud import bigquery, storage; print(pandas.__version__); print(pyarrow.__version__); print(\"BigQuery/GCS=OK\")"
cat /etc/sandbox-image-version
'
```

Cleanup:

```bash
kubectl -n sbx01 delete pod jupyter-image-check
```

## 4. Helm rollout to sbx01

The source automation now points new SingleUser Pods to the standard image. For an immediate manual test of the existing release:

```bash
gcloud auth print-access-token | \
helm registry login asia-northeast3-docker.pkg.dev \
  --username oauth2accesstoken \
  --password-stdin
```

```bash
helm upgrade jupyterhub-sbx01 \
  oci://asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub \
  --version 4.2.0 \
  --namespace sbx01 \
  --reuse-values \
  --set singleuser.image.name=asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub-k8s-singleuser-standard \
  --set singleuser.image.tag=4.2.0-r1-test \
  --wait \
  --timeout 15m
```

Verify:

```bash
helm get values jupyterhub-sbx01 -n sbx01 | grep -A8 singleuser:
```

## 5. Recreate user01 with the new image

Do not delete `claim-user01`.

```bash
kubectl -n sbx01 get pvc claim-user01
kubectl -n sbx01 delete pod jupyter-user01 --wait=true
```

After `user01` signs in again, JupyterHub/KubeSpawner creates a new Pod with the configured standard image and reconnects the existing PVC.

```bash
kubectl -n sbx01 get pod jupyter-user01 \
  -o jsonpath='IMAGE={.spec.containers[0].image}{"\n"}'
```

Expected image:

```text
.../jupyterhub-k8s-singleuser-standard:4.2.0-r1-test
```

## 6. Verify inside Jupyter Notebook

```python
import shutil
import subprocess

for cmd in ["python", "gcloud", "git", "jq"]:
    print("\n==", cmd, "==")
    path = shutil.which(cmd)
    print("PATH =", path)
    if path:
        result = subprocess.run([cmd, "--version"], capture_output=True, text=True)
        print(result.stdout or result.stderr)
```

```python
import pandas
import pyarrow
from google.cloud import bigquery
from google.cloud import storage

print("pandas =", pandas.__version__)
print("pyarrow =", pyarrow.__version__)
print("BigQuery = OK")
print("GCS = OK")
```

## Data persistence

The container filesystem is replaceable, but the user home PVC is retained:

```text
Container image software     -> replaced when Pod is recreated
/home/jovyan on user PVC     -> retained
claim-user01 (40Gi)          -> retained
```

Do not delete the user PVC during an image upgrade.
