#!/usr/bin/env python3
import json
import os
import sys


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: render_jupyter_values.py REQUEST_JSON OUTPUT_JSON")
    with open(sys.argv[1], encoding="utf-8") as stream:
        request = json.load(stream)

    task = request["task"]["name"]
    # GoogleOAuthenticator with hosted_domain returns the local-part username
    # (for example user01 for user01@sonmap.net). Normalize the approved email
    # members to the same form before passing them to JupyterHub allowed_users.
    allowed_users = [
        member.split("@", 1)[0]
        for member in request["identity"]["members"]
    ]

    image_prefix = os.environ.get(
        "JUPYTER_IMAGE_PREFIX",
        "asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform",
    )
    chart_version = os.environ.get("JUPYTER_CHART_VERSION", "4.2.0")
    chp_tag = os.environ.get("JUPYTER_CHP_TAG", "4.6.3")
    singleuser_image = os.environ.get(
        "JUPYTER_SINGLEUSER_IMAGE",
        f"{image_prefix}/jupyterhub-k8s-singleuser-standard",
    )
    singleuser_image_tag = os.environ.get(
        "JUPYTER_SINGLEUSER_IMAGE_TAG",
        "4.2.0-r1-test",
    )

    values = {
        "hub": {
            "image": {
                "name": f"{image_prefix}/jupyterhub-k8s-hub",
                "tag": chart_version,
            },
            "config": {
                "JupyterHub": {"authenticator_class": "google"},
                "Authenticator": {
                    "allow_all": False,
                    "allowed_users": allowed_users,
                },
                "GoogleOAuthenticator": {
                    "client_id": os.environ["JUPYTER_OAUTH_CLIENT_ID"],
                    "client_secret": os.environ["JUPYTER_OAUTH_CLIENT_SECRET"],
                    "oauth_callback_url": f"https://{request['gke']['jupyter_domain']}/hub/oauth_callback",
                    "hosted_domain": ["sonmap.net"],
                    "strip_domain": True,
                    "login_service": "Sonmap Google Account",
                },
            },
            "resources": {
                "requests": {"cpu": "500m", "memory": "1Gi"},
                "limits": {"cpu": "1", "memory": "2Gi"},
            },
        },
        "proxy": {
            # Autopilot requires >=500m requested CPU for a Pod using
            # safe-to-evict=false. Protect the single CHP endpoint from
            # voluntary node scale-down to avoid transient NEG endpoint loss.
            "annotations": {
                "cluster-autoscaler.kubernetes.io/safe-to-evict": "false",
            },
            "chp": {
                "image": {
                    "name": f"{image_prefix}/jupyterhub-configurable-http-proxy",
                    "tag": chp_tag,
                },
                "resources": {
                    "requests": {"cpu": "500m", "memory": "512Mi"},
                    "limits": {"cpu": "500m", "memory": "1Gi"},
                },
            },
            # NEG is attached only after Helm becomes healthy. The automation
            # then waits for ServiceNetworkEndpointGroup Synced=True and reads
            # the GKE-generated NEG name from cloud.google.com/neg-status.
            "service": {"type": "ClusterIP"},
        },
        "singleuser": {
            "image": {
                "name": singleuser_image,
                "tag": singleuser_image_tag,
            },
            "serviceAccountName": f"ksa-jupyter-{task}",
            "cpu": {"guarantee": 1, "limit": 2},
            "memory": {"guarantee": "8G", "limit": "16G"},
            "storage": {
                "type": "dynamic",
                "capacity": "40Gi",
                "dynamic": {"storageClass": "standard-rwo"},
            },
            # GKE Autopilot rejects the privileged block-cloud-metadata
            # init container (NET_ADMIN). Workload Identity instead requires
            # access to the GKE metadata server.
            "cloudMetadata": {"blockWithIptables": False},
            "networkPolicy": {
                "enabled": True,
                "egressAllowRules": {"cloudMetadataServer": True},
            },
        },
        "prePuller": {
            "hook": {"enabled": False},
            "continuous": {"enabled": False},
        },
        "scheduling": {"userScheduler": {"enabled": False}},
        "cull": {"enabled": True, "timeout": 3600},
    }
    with open(sys.argv[2], "w", encoding="utf-8") as stream:
        json.dump(values, stream, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
