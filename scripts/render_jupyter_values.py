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
    values = {
        "hub": {
            "config": {
                "JupyterHub": {"authenticator_class": "google"},
                "Authenticator": {"allow_all": False, "allowed_users": request["identity"]["members"]},
                "GoogleOAuthenticator": {
                    "client_id": os.environ["JUPYTER_OAUTH_CLIENT_ID"],
                    "client_secret": os.environ["JUPYTER_OAUTH_CLIENT_SECRET"],
                    "oauth_callback_url": f"https://{request['gke']['jupyter_domain']}/hub/oauth_callback",
                    "hosted_domain": ["sonmap.net"],
                    "login_service": "Sonmap Google Account",
                },
            }
        },
        "proxy": {
            "service": {
                "type": "ClusterIP",
                "annotations": {
                    "cloud.google.com/neg": json.dumps(
                        {"exposed_ports": {"80": {"name": f"neg-jupyter-{task}"}}}, separators=(",", ":")
                    )
                },
            }
        },
        "singleuser": {
            "serviceAccountName": f"ksa-jupyter-{task}",
            "cpu": {"guarantee": 1, "limit": 2},
            "memory": {"guarantee": "8G", "limit": "16G"},
            "storage": {"type": "dynamic", "capacity": "40Gi", "dynamic": {"storageClass": "standard-rwo"}},
        },
        "cull": {"enabled": True, "timeout": 3600},
    }
    with open(sys.argv[2], "w", encoding="utf-8") as stream:
        json.dump(values, stream, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
