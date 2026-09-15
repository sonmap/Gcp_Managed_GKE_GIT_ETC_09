#!/usr/bin/env python3
import base64
import json
import os
import subprocess
import sys
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


def gcloud(*args):
    return run(["gcloud", *args])


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
    impersonate = f"--impersonate-service-account={gke_admin}"

    describe = [
        "container", "clusters", "describe", gke["cluster_name"],
        f"--project={gke['project_id']}",
        f"--location={gke['location']}",
        impersonate,
    ]
    # Private Pool has no internet egress. Prefer the GKE private control-plane
    # endpoint, which is reachable through the Shared VPC peering range.
    endpoint = gcloud(*describe, "--format=value(privateEndpoint)")
    if not endpoint:
        endpoint = gcloud(*describe, "--format=value(endpoint)")
    ca_data = gcloud(*describe, "--format=value(masterAuth.clusterCaCertificate)")
    token = gcloud("auth", "print-access-token", impersonate)

    ca_file = Path("/workspace/gke-ca.crt")
    ca_file.write_bytes(base64.b64decode(ca_data))
    kubeconfig = Path("/workspace/kubeconfig.json")
    kubeconfig.write_text(json.dumps({
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [{
            "name": "sandbox",
            "cluster": {
                "server": f"https://{endpoint}",
                "certificate-authority": str(ca_file),
            },
        }],
        "contexts": [{
            "name": "sandbox",
            "context": {"cluster": "sandbox", "user": "gke-admin"},
        }],
        "current-context": "sandbox",
        "users": [{"name": "gke-admin", "user": {"token": token}}],
    }), encoding="utf-8")

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
    child_env = dict(os.environ)
    child_env["KUBECONFIG"] = str(kubeconfig)
    run(["kubectl", "apply", "-f", "-"], input_text=json.dumps(manifest), env=child_env)

    client_id = gcloud(
        "secrets", "versions", "access", "latest",
        "--secret=jupyter-oauth-client-id", f"--project={project}"
    )
    client_secret = gcloud(
        "secrets", "versions", "access", "latest",
        "--secret=jupyter-oauth-client-secret", f"--project={project}"
    )
    values = {
        "hub": {"config": {
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
        }},
        "proxy": {"service": {
            "type": "ClusterIP",
            "annotations": {
                "cloud.google.com/neg": json.dumps(
                    {"exposed_ports": {"80": {"name": f"neg-jupyter-{task}"}}},
                    separators=(",", ":"),
                )
            },
        }},
        "singleuser": {
            "serviceAccountName": ksa,
            "cpu": {"guarantee": 1, "limit": 2},
            "memory": {"guarantee": "8G", "limit": "16G"},
            "storage": {
                "type": "dynamic",
                "capacity": "40Gi",
                "dynamic": {"storageClass": "standard-rwo"},
            },
        },
        "cull": {"enabled": True, "timeout": 3600},
    }
    values_file = Path("/workspace/jupyter-values.json")
    values_file.write_text(json.dumps(values, indent=2), encoding="utf-8")

    registry = f"{region}-docker.pkg.dev"
    access_token = gcloud("auth", "print-access-token")
    run(
        ["helm", "registry", "login", registry, "--username", "oauth2accesstoken",
         "--password-stdin"],
        input_text=access_token,
        env=child_env,
    )
    run([
        "helm", "upgrade", "--install", f"jupyterhub-{task}",
        os.environ["JUPYTER_CHART_URI"],
        f"--version={os.environ['JUPYTER_CHART_VERSION']}",
        f"--namespace={namespace}",
        f"--values={values_file}",
        "--atomic", "--wait", "--timeout=15m",
    ], env=child_env)


if __name__ == "__main__":
    main()
