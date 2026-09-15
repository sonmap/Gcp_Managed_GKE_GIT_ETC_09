#!/usr/bin/env bash
# Add Jupyter OAuth values as Secret Manager versions without writing the
# secret values to Git, Terraform variables, plan files, or Terraform state.
set -euo pipefail

CICD_PROJECT_ID="${CICD_PROJECT_ID:-prj-b-cicd-local-236d}"
CLIENT_ID_SECRET="jupyter-oauth-client-id"
CLIENT_SECRET_SECRET="jupyter-oauth-client-secret"

for secret_name in "${CLIENT_ID_SECRET}" "${CLIENT_SECRET_SECRET}"; do
  if ! gcloud secrets describe "${secret_name}"     --project="${CICD_PROJECT_ID}" >/dev/null 2>&1; then
    echo "Secret metadata is missing: ${secret_name}" >&2
    echo "Apply terraform/01-foundation first; Terraform owns secret metadata." >&2
    exit 1
  fi
done

read -r -p "Jupyter OAuth client ID: " OAUTH_CLIENT_ID
read -r -s -p "Jupyter OAuth client secret: " OAUTH_CLIENT_SECRET
echo

if [ -z "${OAUTH_CLIENT_ID}" ] || [ -z "${OAUTH_CLIENT_SECRET}" ]; then
  echo "OAuth client ID and client secret must both be non-empty." >&2
  exit 2
fi

printf '%s' "${OAUTH_CLIENT_ID}" |
  gcloud secrets versions add "${CLIENT_ID_SECRET}"     --project="${CICD_PROJECT_ID}"     --data-file=-

printf '%s' "${OAUTH_CLIENT_SECRET}" |
  gcloud secrets versions add "${CLIENT_SECRET_SECRET}"     --project="${CICD_PROJECT_ID}"     --data-file=-

unset OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET

for secret_name in "${CLIENT_ID_SECRET}" "${CLIENT_SECRET_SECRET}"; do
  latest_state="$(gcloud secrets versions describe latest     --secret="${secret_name}"     --project="${CICD_PROJECT_ID}"     --format='value(state)')"
  if [ "${latest_state}" != "ENABLED" ]; then
    echo "Latest version is not ENABLED for ${secret_name}: ${latest_state}" >&2
    exit 1
  fi
done

echo "Jupyter OAuth Secret Manager versions are ENABLED."
