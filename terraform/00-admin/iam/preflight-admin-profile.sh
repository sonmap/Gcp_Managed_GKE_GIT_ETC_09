#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-}"

case "${PROFILE}" in
  cicd)
    PROJECT_ID="prj-b-cicd-local-236d"
    PROFILE_FILE="foundation-bootstrap.admin.tfvars"
    BACKEND_PREFIX="admin/shared-vpc-iam"
    ;;
  gke)
    PROJECT_ID="pjt-d-host01"
    PROFILE_FILE="foundation-gke-project.admin.tfvars"
    BACKEND_PREFIX="admin/foundation-gke-project-iam"
    ;;
  shared-vpc)
    PROJECT_ID="pjt-d-shared-base"
    PROFILE_FILE="foundation-shared-vpc.admin.tfvars"
    BACKEND_PREFIX="admin/foundation-shared-vpc-iam"
    ;;
  *)
    echo "Usage: bash preflight-admin-profile.sh {cicd|gke|shared-vpc}"
    exit 2
    ;;
esac

CALLER="$(gcloud config get-value account 2>/dev/null)"
echo "Caller         : ${CALLER}"
echo "Target project : ${PROJECT_ID}"
echo "Profile        : ${PROFILE_FILE}"
echo "Backend prefix : ${BACKEND_PREFIX}"

if ! gcloud projects get-iam-policy "${PROJECT_ID}"   --format="value(etag)" >/dev/null 2>&1; then
  echo
  echo "BLOCKED: ${CALLER} cannot read the IAM policy of ${PROJECT_ID}."
  echo "Do not run Terraform with this identity."
  echo "Use an IAM administrator of ${PROJECT_ID}."
  exit 1
fi

echo
echo "IAM policy read check passed."
echo "The caller must also have resourcemanager.projects.setIamPolicy."
echo "Proceed with the matching Git-managed profile only after that is confirmed."
