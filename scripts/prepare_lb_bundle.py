#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def run(args):
    result = subprocess.run(args, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare_lb_bundle.py REQUEST_JSON TEMPLATE_ZIP OUTPUT_ZIP")

    with open(sys.argv[1], encoding="utf-8") as stream:
        request = json.load(stream)

    namespace = request["gke"]["namespace"]
    project = request["gke"]["project_id"]

    # The caller retries this script while the standalone NEG controller is
    # reconciling. Only trust neg-status after the matching svcneg reports
    # Synced=True; stale neg-status can otherwise point to an old cluster NEG.
    svcnegs = json.loads(run([
        "kubectl", "get", "svcneg",
        f"--namespace={namespace}", "--output=json",
    ]))

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

    if not synced:
        raise RuntimeError("proxy-public:80 ServiceNetworkEndpointGroup is not Synced=True yet")

    service = json.loads(run([
        "kubectl", "get", "service", "proxy-public",
        f"--namespace={namespace}", "--output=json",
    ]))
    raw_status = service.get("metadata", {}).get("annotations", {}).get(
        "cloud.google.com/neg-status"
    )
    if not raw_status:
        raise RuntimeError("proxy-public has no cloud.google.com/neg-status yet")

    neg_status = json.loads(raw_status)
    neg_name = neg_status.get("network_endpoint_groups", {}).get("80")
    zones = neg_status.get("zones", [])
    if not neg_name or not zones:
        raise RuntimeError(f"invalid GKE NEG status: {neg_status}")

    negs = [
        f"projects/{project}/zones/{zone}/networkEndpointGroups/{neg_name}"
        for zone in zones
    ]

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        with zipfile.ZipFile(sys.argv[2]) as archive:
            archive.extractall(root)
        variable_file = root / "terraform.auto.tfvars.json"
        variables = json.loads(variable_file.read_text(encoding="utf-8"))
        variables["neg_self_links"] = negs
        variable_file.write_text(
            json.dumps(variables, indent=2, sort_keys=True), encoding="utf-8"
        )
        shutil.make_archive(os.path.splitext(sys.argv[3])[0], "zip", root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
