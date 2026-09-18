#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time
from pathlib import Path


def run(args, *, env=None):
    result = subprocess.run(
        args,
        text=True,
        check=False,
        capture_output=True,
        env=env,
    )
    if result.returncode:
        command = " ".join(args)
        raise RuntimeError(
            f"command failed ({result.returncode}): {command}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result.stdout.strip()


def gcloud(*args, env=None):
    return run(["gcloud", *args], env=env)


def expected_backend(path_matcher, backend_name):
    service = path_matcher.get("defaultService", "")
    return service.endswith(f"/backendServices/{backend_name}")


def wait_for_backend_healthy(project, backend_name, env):
    last_states = []
    for _ in range(30):
        raw = gcloud(
            "compute", "backend-services", "get-health", backend_name,
            f"--project={project}", "--global", "--format=json", env=env,
        )
        payload = json.loads(raw or "[]")
        states = []
        for entry in payload:
            for health in entry.get("status", {}).get("healthStatus", []):
                states.append(health.get("healthState", "UNKNOWN"))
        last_states = states
        if "HEALTHY" in states:
            print(f"backend {backend_name} is HEALTHY: {states}")
            return
        time.sleep(10)
    raise RuntimeError(
        f"backend {backend_name} did not become HEALTHY within 5 minutes; "
        f"last health states={last_states}"
    )


def reconcile_url_map(project, url_map_name, task, hostname, backend_name, env):
    raw = gcloud(
        "compute", "url-maps", "describe", url_map_name,
        f"--project={project}", "--global", "--format=json", env=env,
    )
    config = json.loads(raw)

    path_matchers = {
        item.get("name"): item
        for item in config.get("pathMatchers", [])
        if item.get("name")
    }
    current_matcher = path_matchers.get(task)
    if current_matcher is None:
        gcloud(
            "compute", "url-maps", "add-path-matcher", url_map_name,
            f"--project={project}", "--global",
            f"--path-matcher-name={task}",
            f"--default-service={backend_name}",
            env=env,
        )
    elif not expected_backend(current_matcher, backend_name):
        raise RuntimeError(
            f"URL map path matcher {task} already exists but does not point to {backend_name}: "
            f"{current_matcher.get('defaultService')}"
        )

    raw = gcloud(
        "compute", "url-maps", "describe", url_map_name,
        f"--project={project}", "--global", "--format=json", env=env,
    )
    config = json.loads(raw)
    hostname_rules = [
        item for item in config.get("hostRules", [])
        if hostname in item.get("hosts", [])
    ]
    if not hostname_rules:
        gcloud(
            "compute", "url-maps", "add-host-rule", url_map_name,
            f"--project={project}", "--global",
            f"--hosts={hostname}",
            f"--path-matcher-name={task}",
            env=env,
        )
    elif any(item.get("pathMatcher") != task for item in hostname_rules):
        raise RuntimeError(
            f"hostname {hostname} is already registered to a different path matcher: "
            f"{hostname_rules}"
        )

    # Final read-back verification. Do not silently accept partial ALB routing.
    raw = gcloud(
        "compute", "url-maps", "describe", url_map_name,
        f"--project={project}", "--global", "--format=json", env=env,
    )
    config = json.loads(raw)
    path_matchers = {
        item.get("name"): item
        for item in config.get("pathMatchers", [])
        if item.get("name")
    }
    matcher = path_matchers.get(task)
    host_ok = any(
        hostname in item.get("hosts", []) and item.get("pathMatcher") == task
        for item in config.get("hostRules", [])
    )
    if matcher is None or not expected_backend(matcher, backend_name) or not host_ok:
        raise RuntimeError(
            f"URL map reconciliation failed for {hostname} -> {backend_name}"
        )
    print(f"URL map route ready: {hostname} -> {backend_name}")


def verify_workload_identity(request, env):
    task = request["task"]["name"]
    namespace = request["gke"]["namespace"]
    project_id = request["project"]["project_id"]
    ksa = f"ksa-jupyter-{task}"
    expected_gsa = f"gsa-jupyter-{task}@{project_id}.iam.gserviceaccount.com"
    actual_gsa = run([
        "kubectl", "get", "serviceaccount", ksa,
        f"--namespace={namespace}",
        "--output=jsonpath={.metadata.annotations.iam\\.gke\\.io/gcp-service-account}",
    ], env=env)
    if actual_gsa != expected_gsa:
        raise RuntimeError(
            f"KSA/GSA mismatch: {namespace}/{ksa} -> {actual_gsa!r}, expected {expected_gsa!r}"
        )
    print(f"Workload Identity annotation ready: {namespace}/{ksa} -> {expected_gsa}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: reconcile_postdeploy.py APPROVED_REQUEST_JSON")

    request = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    task = request["task"]["name"]
    gke = request["gke"]
    cicd_project = os.environ["CICD_PROJECT_ID"]
    gke_admin = os.environ["GKE_ADMIN_SA"]
    lb_admin = os.environ.get(
        "LB_ADMIN_SA",
        f"sa-im-lb-admin@{cicd_project}.iam.gserviceaccount.com",
    )
    url_map_name = os.environ.get("SHARED_URL_MAP_NAME", "urlmap-alb-jupyter-shared")
    backend_name = f"bes-jupyter-{task}"

    # Kubernetes verification uses the dedicated GKE admin identity.
    gke_env = dict(os.environ)
    gke_env["CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"] = gke_admin
    verify_workload_identity(request, gke_env)

    # Shared ALB changes are made only through the dedicated LB admin identity.
    lb_env = dict(os.environ)
    lb_env["CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT"] = lb_admin

    wait_for_backend_healthy(gke["project_id"], backend_name, lb_env)
    reconcile_url_map(
        gke["project_id"],
        url_map_name,
        task,
        gke["jupyter_domain"],
        backend_name,
        lb_env,
    )


if __name__ == "__main__":
    main()
