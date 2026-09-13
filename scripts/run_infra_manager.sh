#!/usr/bin/env bash
set -euo pipefail

: "${ACTION:?}"
: "${REQUEST_ID:?}"
: "${REQUEST_FILE:?}"
: "${BUNDLE_PREFIX:?}"
: "${IM_PROJECT_ID:?}"
: "${IM_REGION:?}"
: "${IM_WORKER_POOL:?}"

task_name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["task"]["name"])' "$REQUEST_FILE")"
network_required="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1]))["network"]["required"]).lower())' "$REQUEST_FILE")"

apply_deployment() {
  local suffix="$1"
  local archive="$2"
  local service_account="$3"
  gcloud infra-manager deployments apply \
    "projects/${IM_PROJECT_ID}/locations/${IM_REGION}/deployments/im-${task_name}-${suffix}" \
    --service-account="projects/${IM_PROJECT_ID}/serviceAccounts/${service_account}" \
    --gcs-source="${BUNDLE_PREFIX}/${archive}" \
    --worker-pool="${IM_WORKER_POOL}" \
    --annotations="request_id=${REQUEST_ID},task=${task_name}" \
    --quiet
}

if [[ "$ACTION" != "create" ]]; then
  echo "Only CREATE is enabled in the first automated release. DESTROY requires a separate retention workflow." >&2
  exit 2
fi

apply_deployment project project.zip "$IM_PROJECT_FACTORY_SA"
if [[ "$network_required" == "true" ]]; then
  apply_deployment network network.zip "$IM_NETWORK_ADMIN_SA"
fi
apply_deployment iam project-iam.zip "$IM_PROJECT_IAM_SA"
apply_deployment data data.zip "$IM_DATA_ADMIN_SA"
apply_deployment gke-access gke-jupyter.zip "$IM_GKE_ADMIN_SA"
