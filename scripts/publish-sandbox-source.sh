#!/usr/bin/env bash
set -euo pipefail

# Publish the approved 02-sandbox Terraform source from the VM to the
# internal GCS bundle bucket. Cloud Run consumes this immutable archive;
# it does not download Terraform source from GitHub.
#
# Usage:
#   ./scripts/publish-sandbox-source.sh BUCKET_NAME RELEASE_ID

bucket_name="${1:?Usage: $0 BUCKET_NAME RELEASE_ID}"
release_id="${2:?Usage: $0 BUCKET_NAME RELEASE_ID}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repo_root/terraform/02-sandbox/deployments"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

archive="$work_dir/sandbox-source.zip"
object="platform-releases/$release_id/sandbox-source.zip"

test -d "$source_root"
(
  cd "$repo_root"
  zip -qr "$archive" terraform/02-sandbox/deployments
)

sha256="$(sha256sum "$archive" | awk '{print $1}')"
gcloud storage cp "$archive" "gs://$bucket_name/$object"

generation="$(gcloud storage objects describe "gs://$bucket_name/$object" --format='value(generation)')"

cat <<EOF
archive_uri=gs://$bucket_name/$object
generation=$generation
sha256=$sha256
EOF
