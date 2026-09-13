#!/usr/bin/env python3
import base64
import json
import os
import subprocess
import sys
from pathlib import Path


def gcloud(*args: str) -> str:
    return subprocess.run(["gcloud", *args], check=True, capture_output=True, text=True).stdout.strip()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: write_kubeconfig.py REQUEST_JSON OUTPUT_FILE")
    request = json.loads(Path(sys.argv[1]).read_text())
    gke = request["gke"]
    impersonate = f"--impersonate-service-account={os.environ['GKE_ADMIN_SA']}"
    base = ["container", "clusters", "describe", gke["cluster_name"],
            f"--project={gke['project_id']}", f"--location={gke['location']}", impersonate]
    endpoint = gcloud(*base, "--format=value(endpoint)")
    ca_data = gcloud(*base, "--format=value(masterAuth.clusterCaCertificate)")
    token = gcloud("auth", "print-access-token", impersonate)
    output = Path(sys.argv[2])
    ca_file = output.with_suffix(".ca.crt")
    ca_file.write_bytes(base64.b64decode(ca_data))
    config = {
        "apiVersion": "v1", "kind": "Config",
        "clusters": [{"name": "sandbox", "cluster": {"server": f"https://{endpoint}", "certificate-authority": str(ca_file)}}],
        "contexts": [{"name": "sandbox", "context": {"cluster": "sandbox", "user": "build"}}],
        "current-context": "sandbox",
        "users": [{"name": "build", "user": {"token": token}}],
    }
    output.write_text(json.dumps(config))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
