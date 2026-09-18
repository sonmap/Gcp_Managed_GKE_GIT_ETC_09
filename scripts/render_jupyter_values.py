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

    values = {
        "hub": {
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
            }
        },
        "proxy": {
            # NEG is attached only after Helm becomes healthy. The automation
            # then waits for ServiceNetworkEndpointGroup Synced=True and reads
            # the GKE-generated NEG name from cloud.google.com/neg-status.
            "service": {"type": "ClusterIP"},
        },
        "singleuser": {
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
        "cull": {"enabled": True, "timeout": 3600},
    }
    with open(sys.argv[2], "w", encoding="utf-8") as stream:
        json.dump(values, stream, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
