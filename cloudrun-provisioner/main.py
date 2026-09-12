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
    task = body.get("task_name", "sbx01")
    action = body.get("action", "plan")
    group = body.get("group_email", "pgrp-gcp-dev-sbx01@sonmap.net")

    if not TASK_RE.fullmatch(task):
        return jsonify(error="invalid task_name"), 400
    if action not in {"plan", "apply", "destroy"}:
        return jsonify(error="action must be plan, apply, or destroy"), 400
    if not group.endswith("@sonmap.net"):
        return jsonify(error="group domain is not allowed"), 400

    project = os.environ["GCP_PROJECT"]
    region = os.environ["GCP_REGION"]
    trigger_id = os.environ["BUILD_TRIGGER_ID"]
    branch = os.environ["GITHUB_BRANCH"]

    substitutions = {
        "_ACTION": action,
        "_TASK_NAME": task,
        "_GROUP_EMAIL": group,
        "_STATE_BUCKET": os.environ["STATE_BUCKET"],
        "_WORKER_POOL": os.environ["WORKER_POOL"],
        "_JUPYTER_DOMAIN": os.environ["JUPYTER_DOMAIN"],
        "_ENABLE_JUPYTERHUB": "true",
    }

    client = cloudbuild_v1.CloudBuildClient()
    operation = client.run_build_trigger(
        request=cloudbuild_v1.RunBuildTriggerRequest(
            name=f"projects/{project}/locations/{region}/triggers/{trigger_id}",
            source=cloudbuild_v1.RepoSource(
                branch_name=branch,
                substitutions=substitutions,
            ),
        )
    )
    return jsonify(
        status="accepted",
        action=action,
        task_name=task,
        operation=operation.operation.name,
    ), 202
