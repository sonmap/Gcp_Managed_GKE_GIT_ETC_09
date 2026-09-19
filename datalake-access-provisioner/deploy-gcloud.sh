#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CICD_PROJECT="${CICD_PROJECT:-prj-b-cicd-local-236d}"
DATA_PROJECT="${DATA_PROJECT:-pjt-c-admin}"
REGION="${REGION:-asia-northeast3}"
AR_REPOSITORY="${AR_REPOSITORY:-ar-sandbox-platform}"
SERVICE="${SERVICE:-datalake-access-provisioner}"
RUNTIME_SA_NAME="${RUNTIME_SA_NAME:-sa-datalake-access-admin}"
SCHEDULER_SA_NAME="${SCHEDULER_SA_NAME:-sa-datalake-scheduler}"
SCHEDULER_JOB="${SCHEDULER_JOB:-datalake-access-provisioner-5m}"
REQUEST_BUCKET="${REQUEST_BUCKET:-${CICD_PROJECT}-datalake-access-requests}"
BUILD_STAGING_BUCKET="${BUILD_STAGING_BUCKET:-${CICD_PROJECT}-datalake-build-staging}"
ROLE_ID="${ROLE_ID:-datalakeDatasetAclAdmin}"

RUNTIME_SA="${RUNTIME_SA_NAME}@${CICD_PROJECT}.iam.gserviceaccount.com"
SCHEDULER_SA="${SCHEDULER_SA_NAME}@${CICD_PROJECT}.iam.gserviceaccount.com"
CUSTOM_ROLE="projects/${DATA_PROJECT}/roles/${ROLE_ID}"
PROJECT_NUMBER="$(gcloud projects describe "${CICD_PROJECT}" --format='value(projectNumber)')"
BUILD_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
TAG="$(date -u +%Y%m%d-%H%M%S)"
IMAGE="${REGION}-docker.pkg.dev/${CICD_PROJECT}/${AR_REPOSITORY}/${SERVICE}:${TAG}"

printf '\n[1/8] Enable APIs\n'
gcloud services enable \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com \
  --project="${CICD_PROJECT}"

gcloud services enable bigquery.googleapis.com --project="${DATA_PROJECT}"

printf '\n[2/8] Create service accounts\n'
if ! gcloud iam service-accounts describe "${RUNTIME_SA}" --project="${CICD_PROJECT}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${RUNTIME_SA_NAME}" \
    --project="${CICD_PROJECT}" \
    --display-name="Data Lake dataset ACL administrator"
fi

if ! gcloud iam service-accounts describe "${SCHEDULER_SA}" --project="${CICD_PROJECT}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${SCHEDULER_SA_NAME}" \
    --project="${CICD_PROJECT}" \
    --display-name="Cloud Scheduler caller for Data Lake access provisioner"
fi

printf '\n[3/8] Create/update minimal BigQuery custom role\n'
if gcloud iam roles describe "${ROLE_ID}" --project="${DATA_PROJECT}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" \
    --project="${DATA_PROJECT}" \
    --title="Data Lake Dataset ACL Admin" \
    --description="Read and update BigQuery dataset ACL only" \
    --permissions="bigquery.datasets.get,bigquery.datasets.update" \
    --stage=GA
else
  gcloud iam roles create "${ROLE_ID}" \
    --project="${DATA_PROJECT}" \
    --title="Data Lake Dataset ACL Admin" \
    --description="Read and update BigQuery dataset ACL only" \
    --permissions="bigquery.datasets.get,bigquery.datasets.update" \
    --stage=GA
fi

gcloud projects add-iam-policy-binding "${DATA_PROJECT}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="${CUSTOM_ROLE}" \
  --condition=None >/dev/null

printf '\n[4/8] Create request/result and regional Cloud Build staging buckets\n'
if ! gcloud storage buckets describe "gs://${REQUEST_BUCKET}" --project="${CICD_PROJECT}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${REQUEST_BUCKET}" \
    --project="${CICD_PROJECT}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
fi

gcloud storage buckets add-iam-policy-binding "gs://${REQUEST_BUCKET}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/storage.objectViewer" >/dev/null

gcloud storage buckets add-iam-policy-binding "gs://${REQUEST_BUCKET}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/storage.objectCreator" >/dev/null

# Keep Cloud Build source/log objects separate from the approval request bucket.
# The current Cloud Build default service account is the CICD project's Compute
# Engine default SA; grant it access only to this dedicated regional bucket.
if ! gcloud storage buckets describe "gs://${BUILD_STAGING_BUCKET}" --project="${CICD_PROJECT}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUILD_STAGING_BUCKET}" \
    --project="${CICD_PROJECT}" \
    --location="${REGION}" \
    --uniform-bucket-level-access
fi

gcloud storage buckets add-iam-policy-binding "gs://${BUILD_STAGING_BUCKET}" \
  --member="serviceAccount:${BUILD_SA}" \
  --role="roles/storage.objectAdmin" >/dev/null

# The same Build SA must be able to push the immutable container image.
gcloud artifacts repositories add-iam-policy-binding "${AR_REPOSITORY}" \
  --project="${CICD_PROJECT}" \
  --location="${REGION}" \
  --member="serviceAccount:${BUILD_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null

printf 'Cloud Build SA: %s\n' "${BUILD_SA}"
printf 'Build staging : gs://%s\n' "${BUILD_STAGING_BUCKET}"

printf '\n[5/8] Build immutable container image\n'
# Organization policy restricts Cloud Storage locations. Stage source and logs
# explicitly in an asia-northeast3 bucket so Cloud Build never falls back to a
# US multi-region bucket.
gcloud builds submit "${SCRIPT_DIR}" \
  --project="${CICD_PROJECT}" \
  --region="${REGION}" \
  --default-buckets-behavior=regional-user-owned-bucket \
  --gcs-source-staging-dir="gs://${BUILD_STAGING_BUCKET}/source" \
  --gcs-log-dir="gs://${BUILD_STAGING_BUCKET}/logs" \
  --tag="${IMAGE}"

printf '\n[6/8] Deploy private Cloud Run service\n'
gcloud run deploy "${SERVICE}" \
  --project="${CICD_PROJECT}" \
  --region="${REGION}" \
  --image="${IMAGE}" \
  --service-account="${RUNTIME_SA}" \
  --no-allow-unauthenticated \
  --timeout=300 \
  --max-instances=1 \
  --concurrency=1 \
  --set-env-vars="CICD_PROJECT=${CICD_PROJECT},TARGET_PROJECT=${DATA_PROJECT},REQUEST_BUCKET=${REQUEST_BUCKET},REQUEST_PREFIX=pending/,RESULT_PREFIX=results/,MAX_REQUESTS=100"

SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
  --project="${CICD_PROJECT}" \
  --region="${REGION}" \
  --format='value(status.url)')"

gcloud run services add-iam-policy-binding "${SERVICE}" \
  --project="${CICD_PROJECT}" \
  --region="${REGION}" \
  --member="serviceAccount:${SCHEDULER_SA}" \
  --role="roles/run.invoker" >/dev/null

printf '\n[7/8] Create/update Cloud Scheduler: every 5 minutes\n'
SCHEDULER_ARGS=(
  --project="${CICD_PROJECT}"
  --location="${REGION}"
  --schedule='*/5 * * * *'
  --time-zone='Asia/Seoul'
  --uri="${SERVICE_URL}/run"
  --http-method=POST
  --oidc-service-account-email="${SCHEDULER_SA}"
  --oidc-token-audience="${SERVICE_URL}"
  --headers='Content-Type=application/json'
  --message-body='{"source":"cloud-scheduler"}'
  --attempt-deadline=300s
)

if gcloud scheduler jobs describe "${SCHEDULER_JOB}" \
  --project="${CICD_PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
  gcloud scheduler jobs update http "${SCHEDULER_JOB}" "${SCHEDULER_ARGS[@]}"
else
  gcloud scheduler jobs create http "${SCHEDULER_JOB}" "${SCHEDULER_ARGS[@]}"
fi

printf '\n[8/8] Done\n'
printf 'Cloud Run    : %s\n' "${SERVICE_URL}"
printf 'Request GCS  : gs://%s/pending/\n' "${REQUEST_BUCKET}"
printf 'Result GCS   : gs://%s/results/\n' "${REQUEST_BUCKET}"
printf 'Scheduler    : %s (*/5 * * * *, Asia/Seoul)\n' "${SCHEDULER_JOB}"
printf 'Release image: %s\n' "${IMAGE}"
