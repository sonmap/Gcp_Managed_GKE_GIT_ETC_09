#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${CICD_PROJECT_ID:-prj-b-cicd-local-236d}"
MODE="${1:-}"
BACKUP_FILE="foundation-state-backup-$(date -u +%Y%m%d-%H%M%S).json"

declare -A ACCOUNTS=(
  [portal]="sa-sandbox-portal"
  [api]="sa-sandbox-api"
  [workflow]="sa-sandbox-workflow"
  [orchestrator]="sa-sandbox-terraform"
  [project_factory]="sa-im-project-factory"
  [network_admin]="sa-im-network-admin"
  [project_iam]="sa-im-project-iam"
  [data_admin]="sa-im-data-admin"
  [gke_admin]="sa-im-gke-admin"
  [lb_admin]="sa-im-lb-admin"
  [group_admin]="sa-sandbox-group-admin"
)

IMPORT_KEYS=()

for key in "${!ACCOUNTS[@]}"; do
  address="google_service_account.automation[\"${key}\"]"
  email="${ACCOUNTS[${key}]}@${PROJECT_ID}.iam.gserviceaccount.com"

  if terraform state show "${address}" >/dev/null 2>&1; then
    continue
  fi

  if gcloud iam service-accounts describe "${email}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    IMPORT_KEYS+=("${key}")
    printf 'IMPORT  %-18s %s\n' "${key}" "${email}"
  fi
done

if (( ${#IMPORT_KEYS[@]} == 0 )); then
  echo "No existing unmanaged Foundation service accounts were found."
  exit 0
fi

if [[ "${MODE}" != "--apply" ]]; then
  echo
  echo "Dry run only. Re-run with --apply to back up state and import these accounts."
  exit 0
fi

terraform state pull > "${BACKUP_FILE}"
echo "State backup: ${BACKUP_FILE}"

for key in "${IMPORT_KEYS[@]}"; do
  address="google_service_account.automation[\"${key}\"]"
  email="${ACCOUNTS[${key}]}@${PROJECT_ID}.iam.gserviceaccount.com"
  terraform import -input=false "${address}"     "projects/${PROJECT_ID}/serviceAccounts/${email}"
done

echo "Existing service-account import completed."
