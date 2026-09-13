import hashlib
import hmac
import ipaddress
import io
import json
import os
import re
import shutil
import tempfile
import zipfile
from pathlib import Path

import requests
from flask import Flask, jsonify, request
from google.api_core.exceptions import PreconditionFailed
from google.cloud import storage
from google.cloud.devtools import cloudbuild_v1
from jsonschema import Draft202012Validator, FormatChecker

app = Flask(__name__)
REQUEST_RE = re.compile(r"^REQ-[A-Z0-9-]{6,64}$")
SCHEMA = json.loads(Path(__file__).with_name("sandbox-request.schema.json").read_text())
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=FormatChecker())

STAGES = {
    "10-project": "project.zip",
    "20-network": "network.zip",
    "30-project-iam": "project-iam.zip",
    "40-data": "data.zip",
    "50-gke-jupyter": "gke-jupyter.zip",
    "60-loadbalancer": "loadbalancer-template.zip",
}


def parse_gs_uri(uri: str) -> tuple[str, str]:
    if not uri.startswith("gs://"):
        raise ValueError("approved_json_uri must use gs://")
    bucket, separator, name = uri[5:].partition("/")
    if not bucket or not separator or not name:
        raise ValueError("approved_json_uri must include bucket and object")
    return bucket, name


def download_approved_request(uri: str, generation: int, expected_sha256: str) -> tuple[dict, bytes]:
    bucket_name, object_name = parse_gs_uri(uri)
    if bucket_name != os.environ["REQUEST_BUCKET"]:
        raise ValueError("request bucket is not allowed")

    blob = storage.Client().bucket(bucket_name).blob(object_name, generation=generation)
    raw = blob.download_as_bytes()
    actual_hash = hashlib.sha256(raw).hexdigest()
    if not hmac.compare_digest(actual_hash, expected_sha256.lower()):
        raise ValueError("request sha256 mismatch")

    payload = json.loads(raw)
    errors = sorted(VALIDATOR.iter_errors(payload), key=lambda error: list(error.path))
    if errors:
        location = ".".join(str(value) for value in errors[0].path) or "$"
        raise ValueError(f"request schema validation failed at {location}: {errors[0].message}")
    validate_semantics(payload)
    return payload, raw


def validate_semantics(payload: dict) -> None:
    task = payload["task"]["name"]
    if payload["identity"]["group_email"] != f"pgrp-gcp-dev-{task}@sonmap.net":
        raise ValueError("group_email must match the approved task name")
    if payload["gke"]["namespace"] != task:
        raise ValueError("GKE namespace must match the approved task name")

    network = payload["network"]
    if network["required"]:
        if network.get("subnet_name") != f"subnet-{task}-an3":
            raise ValueError("subnet_name must match the approved task name")
        try:
            subnet = ipaddress.ip_network(network.get("subnet_cidr", ""), strict=True)
        except ValueError as error:
            raise ValueError("subnet_cidr must be a valid network address") from error
        if subnet.version != 4 or subnet.prefixlen != 24:
            raise ValueError("approved sandbox subnet must be IPv4 /24")
    elif network["shared_vpc_join"]:
        raise ValueError("shared_vpc_join cannot be true when network.required is false")


def download_repository(repository: str, commit_sha: str, destination: Path) -> Path:
    allowed_repository = os.environ.get("GITHUB_REPOSITORY", "sonmap/Gcp_Managed_GKE_GIT_ETC_09")
    if repository != allowed_repository:
        raise ValueError("repository is not allowed")

    url = f"https://api.github.com/repos/{repository}/zipball/{commit_sha}"
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN", "")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    response = requests.get(url, headers=headers, timeout=60)
    response.raise_for_status()

    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
        base = destination.resolve()
        for member in archive.infolist():
            target = (destination / member.filename).resolve()
            if base not in target.parents and target != base:
                raise ValueError("unsafe repository archive path")
        archive.extractall(destination)

    roots = [path for path in destination.iterdir() if path.is_dir()]
    if len(roots) != 1:
        raise ValueError("unexpected GitHub archive layout")
    return roots[0]


def stage_variables(payload: dict) -> dict[str, dict]:
    task = payload["task"]
    project = payload["project"]
    network = payload["network"]
    data = payload["data"]
    gke = payload["gke"]
    task_name = task["name"]
    jupyter_ksa = f"ksa-jupyter-{task_name}"
    jupyter_gsa = f"gsa-jupyter-{task_name}@{project['project_id']}.iam.gserviceaccount.com"
    cicd_project = os.environ["GCP_PROJECT"]

    return {
        "10-project": {
            "project_id": project["project_id"], "project_name": project["project_name"],
            "folder_id": project["folder_id"], "billing_account": project["billing_account"],
            "task_name": task_name, "expires_on": task["expires_on"], "region": network["region"],
            "project_iam_service_account": f"sa-im-project-iam@{cicd_project}.iam.gserviceaccount.com",
            "data_admin_service_account": f"sa-im-data-admin@{cicd_project}.iam.gserviceaccount.com",
        },
        "20-network": {
            "network_required": network["required"], "host_project_id": network["host_project_id"],
            "service_project_id": project["project_id"], "network_name": network["network_name"],
            "region": network["region"], "subnet_name": network.get("subnet_name") or "",
            "subnet_cidr": network.get("subnet_cidr") or "",
            "private_google_access": network.get("private_google_access", True),
            "shared_vpc_join": network["shared_vpc_join"],
        },
        "30-project-iam": {
            "project_id": project["project_id"], "group_email": payload["identity"]["group_email"],
        },
        "40-data": {
            "project_id": project["project_id"], "region": network["region"], "task_name": task_name,
            "group_email": payload["identity"]["group_email"],
            "bigquery_dataset": data["bigquery_dataset"], "gcs_bucket": data["gcs_bucket"],
            "gke_project_id": gke["project_id"], "gke_namespace": gke["namespace"],
            "jupyter_ksa_name": jupyter_ksa,
        },
        "50-gke-jupyter": {
            "gke_project_id": gke["project_id"], "gke_cluster_name": gke["cluster_name"],
            "gke_location": gke["location"], "namespace": gke["namespace"], "task_name": task_name,
            "group_email": payload["identity"]["group_email"], "jupyter_ksa_name": jupyter_ksa,
            "jupyter_gsa_email": jupyter_gsa,
        },
        "60-loadbalancer": {
            "gke_project_id": gke["project_id"], "task_name": task_name,
            "jupyter_domain": gke["jupyter_domain"], "neg_self_links": [],
        },
    }


def zip_directory(source: Path) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source))
    return output.getvalue()


def upload_immutable(blob, content: bytes, content_type: str) -> None:
    try:
        blob.upload_from_string(content, content_type=content_type, if_generation_match=0)
    except PreconditionFailed:
        existing = blob.download_as_bytes()
        if hashlib.sha256(existing).digest() != hashlib.sha256(content).digest():
            raise ValueError(f"immutable bundle conflict: gs://{blob.bucket.name}/{blob.name}")


def assemble_bundles(payload: dict, raw_request: bytes) -> tuple[str, dict]:
    request_id = payload["request_id"]
    commit_sha = payload["source"]["commit_sha"]
    prefix = f"requests/{request_id}/{commit_sha}"
    bucket = storage.Client().bucket(os.environ["BUNDLE_BUCKET"])
    variables = stage_variables(payload)
    manifest = {"request_id": request_id, "commit_sha": commit_sha, "bundles": {}}

    with tempfile.TemporaryDirectory() as temp_dir:
        temp = Path(temp_dir)
        repository_root = download_repository(payload["source"]["repository"], commit_sha, temp / "repo")
        deployment_root = repository_root / "terraform" / "02-sandbox" / "deployments"
        for stage, archive_name in STAGES.items():
            source = deployment_root / stage
            if not source.is_dir():
                raise ValueError(f"missing Terraform root module: {stage}")
            work = temp / "work" / stage
            shutil.copytree(source, work)
            (work / "terraform.auto.tfvars.json").write_text(
                json.dumps(variables[stage], indent=2, sort_keys=True), encoding="utf-8"
            )
            archive = zip_directory(work)
            object_name = f"{prefix}/{archive_name}"
            upload_immutable(bucket.blob(object_name), archive, "application/zip")
            manifest["bundles"][stage] = {
                "uri": f"gs://{bucket.name}/{object_name}",
                "sha256": hashlib.sha256(archive).hexdigest(),
            }

        upload_immutable(bucket.blob(f"{prefix}/approved-request.json"), raw_request, "application/json")
        upload_immutable(
            bucket.blob(f"{prefix}/manifest.json"),
            json.dumps(manifest, indent=2, sort_keys=True).encode(),
            "application/json",
        )
    return f"gs://{bucket.name}/{prefix}", manifest


def start_build(payload: dict, request_uri: str, bundle_prefix: str):
    project = os.environ["GCP_PROJECT"]
    region = os.environ["GCP_REGION"]
    source = cloudbuild_v1.RepoSource(
        commit_sha=payload["source"]["commit_sha"],
        substitutions={
            "_ACTION": payload["action"].lower(), "_REQUEST_ID": payload["request_id"],
            "_REQUEST_URI": request_uri, "_BUNDLE_PREFIX": bundle_prefix,
            "_TASK_NAME": payload["task"]["name"], "_GKE_NAMESPACE": payload["gke"]["namespace"],
        },
    )
    return cloudbuild_v1.CloudBuildClient().run_build_trigger(
        request=cloudbuild_v1.RunBuildTriggerRequest(
            name=f"projects/{project}/locations/{region}/triggers/{os.environ['BUILD_TRIGGER_ID']}",
            source=source,
        )
    )


def start_build_once(payload: dict, request_uri: str, bundle_prefix: str) -> tuple[str, bool]:
    bucket_name, prefix = parse_gs_uri(bundle_prefix)
    lock = storage.Client().bucket(bucket_name).blob(f"{prefix}/dispatch.json")
    starting = json.dumps({"request_id": payload["request_id"], "status": "STARTING"}).encode()
    try:
        lock.upload_from_string(starting, content_type="application/json", if_generation_match=0)
    except PreconditionFailed:
        previous = json.loads(lock.download_as_bytes())
        operation = previous.get("operation")
        if operation:
            return operation, True
        raise ValueError("this approved request is already being dispatched")

    lock.reload()
    generation = lock.generation
    try:
        operation = start_build(payload, request_uri, bundle_prefix).operation.name
        dispatched = json.dumps({
            "request_id": payload["request_id"], "status": "DISPATCHED", "operation": operation,
        }).encode()
        lock.upload_from_string(
            dispatched, content_type="application/json", if_generation_match=generation
        )
        return operation, False
    except Exception:
        lock.delete(if_generation_match=generation)
        raise


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/provision")
def provision():
    body = request.get_json(silent=True) or {}
    request_id = body.get("request_id", "")
    if not REQUEST_RE.fullmatch(request_id):
        return jsonify(error="invalid request_id"), 400
    try:
        request_uri = body["approved_json_uri"]
        _, request_object = parse_gs_uri(request_uri)
        if request_object != f"approved/{request_id}/request.json":
            raise ValueError("approved_json_uri must use approved/<request_id>/request.json")
        payload, raw = download_approved_request(request_uri, int(body["generation"]), body["sha256"])
        if payload["request_id"] != request_id:
            raise ValueError("request_id does not match approved JSON")
        bundle_prefix, manifest = assemble_bundles(payload, raw)
        operation, duplicate = start_build_once(payload, request_uri, bundle_prefix)
    except (KeyError, TypeError, ValueError, requests.RequestException) as error:
        return jsonify(error=str(error), request_id=request_id), 400
    except Exception:
        app.logger.exception("provisioning request failed")
        return jsonify(error="internal provisioning error", request_id=request_id), 500
    return jsonify(
        request_id=request_id, status="ACCEPTED", bundle_prefix=bundle_prefix,
        operation=operation, duplicate=duplicate, bundle_count=len(manifest["bundles"]),
    ), 202
