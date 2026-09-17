#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path


def run(args, *, input_text=None, env=None):
    result = subprocess.run(
        args,
        input=input_text,
        text=True,
        check=False,
        capture_output=True,
        env=env,
    )
    if result.returncode:
        command = " ".join(args)
        raise RuntimeError(
            f"command failed ({result.returncode}): {command}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result.stdout.strip()


def gcloud(*args, env=None):
    return run(["gcloud", *args], env=env)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: apply_gke_workload.py APPROVED_REQUEST_GCS_URI")

    request_file = Path("/workspace/approved-request.json")
    gcloud("storage", "cp", sys.argv[1], str(request_file))
    request = json.loads(request_file.read_text(encoding="utf-8"))

    task = request["task"]["name"]
    group = request["identity"]["group_email"]
    gke = request["gke"]
    project = os.environ["CICD_PROJECT_ID"]
    region = os.environ["GCP_REGION"]
    gke_admin = os.environ["GKE_ADMIN_SA"]
    # Do not connect directly to the private control-plane IP. A Cloud Build
    # private pool and the GKE control plane use Google-managed networks, so
    # direct Private Endpoint routing requires a separate VPC/HA VPN topology.
    # The DNS endpoint uses the GKE API path and avoids that transit-peering
    # dependency while retaining IAM authentication.
    kubeconfig = Path("/workspace/kubeconfig")
    child_env = dict(os.environ)
    child_env["KUBECONFIG"] = str(kubeconfig)
    child_env["CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"] = gke_admin

    gcloud(
        "container", "clusters", "get-credentials", gke["cluster_name"],
        f"--project={gke['project_id']}",
        f"--location={gke['location']}",
        "--dns-endpoint",
        env=child_env,
    )

    # Read all required runtime secrets before changing Kubernetes resources.
    # This prevents a missing Secret Manager version from leaving a partially
    # applied namespace, RBAC, or service account.
    client_id = gcloud(
        "secrets", "versions", "access", "latest",
        "--secret=jupyter-oauth-client-id", f"--project={project}"
    )
    client_secret = gcloud(
        "secrets", "versions", "access", "latest",
        "--secret=jupyter-oauth-client-secret", f"--project={project}"
    )

    # Authenticate and confirm that the pinned OCI chart exists before
    # changing Kubernetes resources.
    registry = f"{region}-docker.pkg.dev"
    access_token = gcloud("auth", "print-access-token")
    run(
        ["helm", "registry", "login", registry, "--username", "oauth2accesstoken",
         "--password-stdin"],
        input_text=access_token,
        env=child_env,
    )
    run([
        "helm", "show", "chart", os.environ["JUPYTER_CHART_URI"],
        f"--version={os.environ['JUPYTER_CHART_VERSION']}",
    ], env=child_env)

    namespace = gke["namespace"]
    ksa = f"ksa-jupyter-{task}"
    jupyter_gsa = (
        f"gsa-jupyter-{task}@{request['project']['project_id']}.iam.gserviceaccount.com"
    )
    manifest = {
        "apiVersion": "v1",
        "kind": "List",
        "items": [
            {
                "apiVersion": "v1",
                "kind": "Namespace",
                "metadata": {
                    "name": namespace,
                    "labels": {
                        "sandbox/task": task,
                        "app.kubernetes.io/managed-by": "cloud-build",
                    },
                },
            },
            {
                "apiVersion": "v1",
                "kind": "ResourceQuota",
                "metadata": {"name": f"quota-{task}", "namespace": namespace},
                "spec": {"hard": {
                    "requests.cpu": "8",
                    "requests.memory": "64Gi",
                    "limits.cpu": "12",
                    "limits.memory": "96Gi",
                    "persistentvolumeclaims": "5",
                }},
            },
            {
                "apiVersion": "v1",
                "kind": "ServiceAccount",
                "metadata": {
                    "name": ksa,
                    "namespace": namespace,
                    "annotations": {"iam.gke.io/gcp-service-account": jupyter_gsa},
                },
            },
            {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "Role",
                "metadata": {"name": f"role-{task}-user", "namespace": namespace},
                "rules": [
                    {
                        "apiGroups": [""],
                        "resources": [
                            "pods", "pods/log", "services", "configmaps",
                            "persistentvolumeclaims",
                        ],
                        "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"],
                    },
                    {
                        "apiGroups": ["apps"],
                        "resources": ["deployments"],
                        "verbs": ["get", "list", "watch", "create", "update", "patch", "delete"],
                    },
                ],
            },
            {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "RoleBinding",
                "metadata": {"name": f"rb-{task}-group", "namespace": namespace},
                "roleRef": {
                    "apiGroup": "rbac.authorization.k8s.io",
                    "kind": "Role",
                    "name": f"role-{task}-user",
                },
                "subjects": [{
                    "apiGroup": "rbac.authorization.k8s.io",
                    "kind": "Group",
                    "name": group,
                }],
            },
        ],
    }
    run(["kubectl", "apply", "-f", "-"], input_text=json.dumps(manifest), env=child_env)

    # Private GKE nodes in this PoC have no public egress. All JupyterHub
    # runtime images must therefore be pulled from the internal Artifact
    # Registry mirror, not from quay.io.
    image_prefix = f"{region}-docker.pkg.dev/{project}/ar-sandbox-platform"

    values = {
        "hub": {
            "image": {
                "name": f"{image_prefix}/jupyterhub-k8s-hub",
                "tag": os.environ["JUPYTER_CHART_VERSION"],
            },
            "config": {
                "JupyterHub": {"authenticator_class": "google"},
                "Authenticator": {
                    "allow_all": False,
                    "allowed_users": request["identity"]["members"],
                },
                "GoogleOAuthenticator": {
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "oauth_callback_url": (
                        f"https://{gke['jupyter_domain']}/hub/oauth_callback"
                    ),
                    "hosted_domain": ["sonmap.net"],
                    "login_service": "Sonmap Google Account",
                },
            },
            "resources": {
                "requests": {"cpu": "500m", "memory": "1Gi"},
                "limits": {"cpu": "1", "memory": "2Gi"},
            },
        },
        "proxy": {
            "chp": {
                "image": {
                    "name": f"{image_prefix}/jupyterhub-configurable-http-proxy",
                    "tag": "4.6.3",
                },
                "resources": {
                    "requests": {"cpu": "250m", "memory": "512Mi"},
                    "limits": {"cpu": "500m", "memory": "1Gi"},
                },
            },
            # Do not attach the standalone NEG during Helm --wait. If the NEG
            # readiness gate is injected before the load balancer exists, the
            # proxy Pod becomes NotReady and proxy-api has no Ready endpoint.
            # That makes the Hub fail with HTTP 599 and Helm deadlocks.
            "service": {
                "type": "ClusterIP",
            },
        },
        "singleuser": {
            "image": {
                "name": f"{image_prefix}/jupyterhub-k8s-singleuser-sample",
                "tag": os.environ["JUPYTER_CHART_VERSION"],
            },
            "serviceAccountName": ksa,
            "cpu": {"guarantee": 1, "limit": 2},
            "memory": {"guarantee": "8G", "limit": "16G"},
            "storage": {
                "type": "dynamic",
                "capacity": "40Gi",
                "dynamic": {"storageClass": "standard-rwo"},
            },
        },
        # The image pre-puller hook does not declare limits compatible with
        # the sandbox ResourceQuota. Disable it for this constrained PoC;
        # the first user server can pull its image on demand instead.
        "prePuller": {
            "hook": {"enabled": False},
            "continuous": {"enabled": False},
        },
        # GKE Autopilot rejects the chart's custom scheduler. Kubernetes'
        # default scheduler is used when this component is disabled.
        "scheduling": {
            "userScheduler": {"enabled": False},
        },
        "cull": {"enabled": True, "timeout": 3600},
    }
    values_file = Path("/workspace/jupyter-values.json")
    values_file.write_text(json.dumps(values, indent=2), encoding="utf-8")

    run([
        "helm", "upgrade", "--install", f"jupyterhub-{task}",
        os.environ["JUPYTER_CHART_URI"],
        f"--version={os.environ['JUPYTER_CHART_VERSION']}",
        f"--namespace={namespace}",
        f"--values={values_file}",
        "--atomic", "--wait", "--timeout=15m",
    ], env=child_env)

    # Helm must become healthy before the standalone NEG is attached. This
    # avoids a circular dependency where NEG readiness blocks proxy-api,
    # while the load balancer cannot be created until Helm has completed.
    # Let GKE generate the NEG name. The generated name includes the cluster
    # UID and therefore remains collision-free when an Autopilot cluster is
    # deleted and recreated while old NEGs still exist temporarily.
    neg_annotation = json.dumps(
        {"exposed_ports": {"80": {}}},
        separators=(",", ":"),
    )
    run([
        "kubectl", "annotate", "service", "proxy-public",
        f"--namespace={namespace}",
        f"cloud.google.com/neg={neg_annotation}",
        "--overwrite",
    ], env=child_env)

    # GKE creates the standalone NEG asynchronously. The Service can retain a
    # stale cloud.google.com/neg-status annotation briefly after its NEG spec
    # changes, so do not trust the annotation merely because it exists. Wait
    # until the ServiceNetworkEndpointGroup for proxy-public:80 reports
    # Synced=True, then read the current NEG status and build the LB bundle.
    neg_status = None
    for _ in range(30):
        svcnegs = json.loads(run([
            "kubectl", "get", "svcneg",
            f"--namespace={namespace}", "--output=json",
        ], env=child_env))

        synced = False
        for item in svcnegs.get("items", []):
            labels = item.get("metadata", {}).get("labels", {})
            if (
                labels.get("networking.gke.io/service-name") != "proxy-public"
                or labels.get("networking.gke.io/service-port") != "80"
            ):
                continue
            conditions = item.get("status", {}).get("conditions", [])
            if any(
                condition.get("type") == "Synced"
                and condition.get("status") == "True"
                for condition in conditions
            ):
                synced = True
                break

        if synced:
            service = json.loads(run([
                "kubectl", "get", "service", "proxy-public",
                f"--namespace={namespace}", "--output=json",
            ], env=child_env))
            raw_status = service.get("metadata", {}).get("annotations", {}).get(
                "cloud.google.com/neg-status"
            )
            if raw_status:
                candidate = json.loads(raw_status)
                neg_name = candidate.get("network_endpoint_groups", {}).get("80")
                zones = candidate.get("zones", [])
                if neg_name and zones:
                    neg_status = candidate
                    break
        time.sleep(10)

    if not neg_status:
        raise RuntimeError(
            "GKE NEG for proxy-public did not reach Synced=True with a valid "
            "NEG status within 5 minutes"
        )

    neg_name = neg_status.get("network_endpoint_groups", {}).get("80")
    zones = neg_status.get("zones", [])
    if not neg_name or not zones:
        raise RuntimeError(f"Invalid GKE NEG status: {neg_status}")

    neg_self_links = [
        f"projects/{gke['project_id']}/zones/{zone}/networkEndpointGroups/{neg_name}"
        for zone in zones
    ]

    bundle_prefix = sys.argv[1].rsplit("/", 1)[0]
    lb_template = f"{bundle_prefix}/loadbalancer-template.zip"
    lb_bundle = f"{bundle_prefix}/loadbalancer-ready.zip"
    orchestrator_env = dict(os.environ)

    with tempfile.TemporaryDirectory() as temp_dir:
        temp = Path(temp_dir)
        template_path = temp / "loadbalancer-template.zip"
        work = temp / "loadbalancer"
        output_path = temp / "loadbalancer-ready.zip"
        gcloud("storage", "cp", lb_template, str(template_path), env=orchestrator_env)
        with zipfile.ZipFile(template_path) as archive:
            archive.extractall(work)

        variables_path = work / "terraform.auto.tfvars.json"
        variables = json.loads(variables_path.read_text(encoding="utf-8"))
        variables["neg_self_links"] = neg_self_links
        variables_path.write_text(json.dumps(variables, indent=2, sort_keys=True), encoding="utf-8")

        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(work.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(work))
        gcloud("storage", "cp", str(output_path), lb_bundle, env=orchestrator_env)

    deployment_key = hashlib.sha256(
        request["project"]["project_id"].encode("utf-8")
    ).hexdigest()[:8]
    lb_service_account = f"sa-im-lb-admin@{project}.iam.gserviceaccount.com"
    gcloud(
        "infra-manager", "deployments", "apply",
        f"projects/{project}/locations/{region}/deployments/"
        f"im-{task}-{deployment_key}-loadbalancer",
        f"--service-account=projects/{project}/serviceAccounts/{lb_service_account}",
        f"--gcs-source={lb_bundle}",
        f"--worker-pool={os.environ['WORKER_POOL']}",
        "--provider-source=SERVICE_MAINTAINED",
        f"--annotations=request_id={request['request_id']},task={task}",
        "--quiet",
        env=orchestrator_env,
    )


if __name__ == "__main__":
    main()
