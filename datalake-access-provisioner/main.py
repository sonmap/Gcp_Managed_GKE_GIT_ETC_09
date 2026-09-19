import hashlib
import json
import logging
import os
import re
from datetime import datetime, timezone

from flask import Flask, jsonify
from google.api_core.exceptions import PreconditionFailed
from google.cloud import bigquery, storage

app = Flask(__name__)
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("datalake-access-provisioner")

REQUEST_ID_RE = re.compile(r"^DLK-REQ-[A-Z0-9-]{6,64}$")
ALLOWED_ROLE = "roles/bigquery.dataViewer"

CICD_PROJECT = os.environ.get("CICD_PROJECT", "prj-b-cicd-local-236d")
TARGET_PROJECT = os.environ.get("TARGET_PROJECT", "pjt-c-admin")
REQUEST_BUCKET = os.environ["REQUEST_BUCKET"]
REQUEST_PREFIX = os.environ.get("REQUEST_PREFIX", "pending/")
RESULT_PREFIX = os.environ.get("RESULT_PREFIX", "results/")
MAX_REQUESTS = int(os.environ.get("MAX_REQUESTS", "100"))

storage_client = storage.Client(project=CICD_PROJECT)
bigquery_client = bigquery.Client(project=TARGET_PROJECT)


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def validate_email(value, field):
    if not isinstance(value, str) or "@" not in value or value.startswith("@") or value.endswith("@"):
        raise ValueError(f"invalid {field}: {value!r}")
    return value.lower()


def validate_request(payload):
    if not isinstance(payload, dict):
        raise ValueError("request must be a JSON object")

    request_id = payload.get("request_id", "")
    if not REQUEST_ID_RE.fullmatch(request_id):
        raise ValueError("request_id must match DLK-REQ-...")

    if payload.get("approved") is not True:
        raise ValueError("approved must be true")

    action = str(payload.get("action", "")).upper()
    if action not in {"GRANT", "REVOKE"}:
        raise ValueError("action must be GRANT or REVOKE")

    data_project = payload.get("data_project")
    if data_project != TARGET_PROJECT:
        raise ValueError(f"data_project must be {TARGET_PROJECT}")

    role = payload.get("role")
    if role != ALLOWED_ROLE:
        raise ValueError(f"role must be {ALLOWED_ROLE}")

    datasets = payload.get("datasets")
    if not isinstance(datasets, list) or not datasets:
        raise ValueError("datasets must be a non-empty array")
    clean_datasets = []
    for dataset_id in datasets:
        if not isinstance(dataset_id, str) or not re.fullmatch(r"[A-Za-z0-9_]+", dataset_id):
            raise ValueError(f"invalid dataset id: {dataset_id!r}")
        clean_datasets.append(dataset_id)

    principals = payload.get("principals")
    if not isinstance(principals, dict):
        raise ValueError("principals must be an object")

    service_accounts = [
        validate_email(value, "service account")
        for value in principals.get("serviceAccounts", [])
    ]
    users = [
        validate_email(value, "user")
        for value in principals.get("users", [])
    ]
    groups = [
        validate_email(value, "group")
        for value in principals.get("groups", [])
    ]
    if not (service_accounts or users or groups):
        raise ValueError("at least one principal is required")

    return {
        "request_id": request_id,
        "task": payload.get("task", ""),
        "action": action,
        "data_project": data_project,
        "datasets": clean_datasets,
        "role": role,
        "service_accounts": sorted(set(service_accounts)),
        "users": sorted(set(users)),
        "groups": sorted(set(groups)),
    }


def desired_entries(validated):
    entries = []
    for email in validated["service_accounts"]:
        entries.append(("userByEmail", email))
    for email in validated["users"]:
        entries.append(("userByEmail", email))
    for email in validated["groups"]:
        entries.append(("groupByEmail", email))
    return entries


def matches_reader(entry, entity_type, entity_id):
    return (
        entry.role == "READER"
        and entry.entity_type == entity_type
        and entry.entity_id == entity_id
    )


def update_dataset_acl(validated, dataset_id):
    dataset_ref = f"{validated['data_project']}.{dataset_id}"
    dataset = bigquery_client.get_dataset(dataset_ref)
    entries = list(dataset.access_entries or [])
    changed = False
    changes = []

    for entity_type, entity_id in desired_entries(validated):
        exists = any(matches_reader(entry, entity_type, entity_id) for entry in entries)

        if validated["action"] == "GRANT":
            if not exists:
                entries.append(
                    bigquery.AccessEntry(
                        role="READER",
                        entity_type=entity_type,
                        entity_id=entity_id,
                    )
                )
                changed = True
                changes.append(f"GRANT {entity_type}:{entity_id}")
        elif exists:
            entries = [
                entry
                for entry in entries
                if not matches_reader(entry, entity_type, entity_id)
            ]
            changed = True
            changes.append(f"REVOKE {entity_type}:{entity_id}")

    if changed:
        dataset.access_entries = entries
        bigquery_client.update_dataset(dataset, ["access_entries"])

    return {
        "dataset": dataset_ref,
        "changed": changed,
        "changes": changes,
    }


def result_object_name(source_blob):
    digest = hashlib.sha256(source_blob.name.encode("utf-8")).hexdigest()[:12]
    basename = source_blob.name.rsplit("/", 1)[-1]
    generation = source_blob.generation or 0
    return f"{RESULT_PREFIX}{basename}.{generation}.{digest}.result.json"


def write_result(bucket, object_name, result):
    blob = bucket.blob(object_name)
    try:
        blob.upload_from_string(
            json.dumps(result, indent=2, sort_keys=True).encode("utf-8"),
            content_type="application/json",
            if_generation_match=0,
        )
    except PreconditionFailed:
        pass


def process_blob(bucket, source_blob):
    result_name = result_object_name(source_blob)
    if bucket.blob(result_name).exists():
        return {
            "source": source_blob.name,
            "source_generation": source_blob.generation,
            "status": "SKIPPED",
            "reason": "already processed",
        }

    started_at = utc_now()
    try:
        pinned = bucket.blob(source_blob.name, generation=source_blob.generation)
        payload = json.loads(pinned.download_as_bytes())
        validated = validate_request(payload)

        dataset_results = [
            update_dataset_acl(validated, dataset_id)
            for dataset_id in validated["datasets"]
        ]
        result = {
            "request_id": validated["request_id"],
            "task": validated["task"],
            "source": source_blob.name,
            "source_generation": source_blob.generation,
            "status": "SUCCESS",
            "action": validated["action"],
            "data_project": validated["data_project"],
            "datasets": dataset_results,
            "started_at": started_at,
            "finished_at": utc_now(),
        }
        write_result(bucket, result_name, result)
        logger.info("processed %s: %s", source_blob.name, validated["request_id"])
        return result
    except Exception as error:
        result = {
            "source": source_blob.name,
            "source_generation": source_blob.generation,
            "status": "ERROR",
            "error": str(error),
            "started_at": started_at,
            "finished_at": utc_now(),
        }
        write_result(bucket, result_name, result)
        logger.exception("failed processing %s", source_blob.name)
        return result


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/run")
def run_batch():
    bucket = storage_client.bucket(REQUEST_BUCKET)
    blobs = [
        blob
        for blob in storage_client.list_blobs(bucket, prefix=REQUEST_PREFIX)
        if blob.name.endswith(".json")
    ]
    blobs.sort(
        key=lambda blob: (
            blob.updated or datetime.min.replace(tzinfo=timezone.utc),
            blob.name,
        )
    )

    results = []
    for source_blob in blobs[:MAX_REQUESTS]:
        results.append(process_blob(bucket, source_blob))

    return jsonify(
        status="DONE",
        scanned=min(len(blobs), MAX_REQUESTS),
        success=sum(1 for item in results if item.get("status") == "SUCCESS"),
        errors=sum(1 for item in results if item.get("status") == "ERROR"),
        skipped=sum(1 for item in results if item.get("status") == "SKIPPED"),
        results=results,
    ), 200
