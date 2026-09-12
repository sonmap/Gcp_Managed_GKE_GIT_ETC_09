import ipaddress
import os
import re

from flask import Flask, jsonify, request
from google.cloud.devtools import cloudbuild_v1

app = Flask(__name__)
TASK_RE = re.compile(r"^[a-z][a-z0-9-]{2,19}$")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/provision")
def provision():
    body = request.get_json(silent=True) or {}
    task = body.get("task_name", "")
    cidr = body.get("subnet_cidr", "")
    action = body.get("action", "plan")
    group = body.get("group_email", "pgrp-gcp-dev-sbx01@sonmap.net")

    if not TASK_RE.fullmatch(task):
        return jsonify(error="invalid task_name"), 400
    try:
        network = ipaddress.ip_network(cidr, strict=True)
        if network.version != 4 or network.prefixlen != 24:
            raise ValueError
    except ValueError:
        return jsonify(error="subnet_cidr must be a valid IPv4 /24"), 400
    if action not in {"plan", "apply", "destroy"}:
        return jsonify(error="action must be plan, apply, or destroy"), 400
    if not group.endswith("@sonmap.net"):
        return jsonify(error="group domain is not allowed"), 400

    project = os.environ["GCP_PROJECT"]
    region = os.environ["GCP_REGION"]
    trigger_id = os.environ["BUILD_TRIGGER_ID"]
    client = cloudbuild_v1.CloudBuildClient()
    operation = client.run_build_trigger(
        project_id=project,
        trigger_id=trigger_id,
        source=cloudbuild_v1.RepoSource(
            branch_name="main",
            substitutions={
                "_ACTION": action,
                "_TASK_NAME": task,
                "_SUBNET_CIDR": cidr,
                "_GROUP_EMAIL": group,
            },
        ),
    )
    return jsonify(status="accepted", operation=operation.operation.name), 202

