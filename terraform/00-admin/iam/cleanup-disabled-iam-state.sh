#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
BACKUP_FILE="admin-iam-state-backup-$(date -u +%Y%m%d-%H%M%S).json"

RESOURCE_PREFIXES=(
  "google_compute_subnetwork_iam_member.cloud_run_network_user"
  "google_project_iam_member.cloud_run_network_viewer"
  "google_project_iam_member.project_factory_existing_project_roles"
  "google_project_iam_member.network_admin_host_roles"
  "google_folder_iam_member.network_admin_shared_vpc_admin"
  "google_project_iam_member.workflow_gke_project_roles"
  "google_project_iam_member.workflow_existing_project_roles"
  "google_project_iam_member.workflow_shared_vpc_roles"
)

mapfile -t STATE_ADDRESSES < <(
  terraform state list | while IFS= read -r address; do
    for prefix in "${RESOURCE_PREFIXES[@]}"; do
      if [[ "${address}" == "${prefix}" || "${address}" == "${prefix}"'['* ]]; then
        printf '%s\n' "${address}"
        break
      fi
    done
  done
)

if (( ${#STATE_ADDRESSES[@]} == 0 )); then
  echo "No disabled IAM resources remain in Terraform state."
  exit 0
fi

echo "Disabled IAM resources still recorded in state:"
printf '  %s\n' "${STATE_ADDRESSES[@]}"

if [[ "${MODE}" != "--apply" ]]; then
  echo
  echo "Dry run only. Re-run with --apply to back up state and forget these addresses."
  exit 0
fi

terraform state pull > "${BACKUP_FILE}"
echo "State backup: ${BACKUP_FILE}"

for address in "${STATE_ADDRESSES[@]}"; do
  terraform state rm "${address}"
done

echo "State cleanup completed. No real GCP IAM binding was deleted."
echo "Run: terraform plan -out=admin-iam.tfplan"
