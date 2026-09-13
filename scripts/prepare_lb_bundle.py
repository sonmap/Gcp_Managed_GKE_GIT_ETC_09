#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare_lb_bundle.py REQUEST_JSON TEMPLATE_ZIP OUTPUT_ZIP")
    with open(sys.argv[1], encoding="utf-8") as stream:
        request = json.load(stream)
    task = request["task"]["name"]
    project = request["gke"]["project_id"]
    result = subprocess.run(
        ["gcloud", "compute", "network-endpoint-groups", "list", f"--project={project}",
         f"--filter=name=neg-jupyter-{task}", "--format=json(selfLink)",
         f"--impersonate-service-account={os.environ['LB_ADMIN_SA']}"],
        check=True, capture_output=True, text=True,
    )
    negs = [item["selfLink"] for item in json.loads(result.stdout)]
    if not negs:
        raise RuntimeError(f"no standalone NEG found for neg-jupyter-{task}")

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        with zipfile.ZipFile(sys.argv[2]) as archive:
            archive.extractall(root)
        variable_file = root / "terraform.auto.tfvars.json"
        variables = json.loads(variable_file.read_text())
        variables["neg_self_links"] = negs
        variable_file.write_text(json.dumps(variables, indent=2, sort_keys=True))
        shutil.make_archive(os.path.splitext(sys.argv[3])[0], "zip", root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
