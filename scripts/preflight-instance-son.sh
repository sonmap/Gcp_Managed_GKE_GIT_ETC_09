#!/usr/bin/env bash
set -euo pipefail
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud compute instances describe instance-son --project=pjt-c-admin --zone=asia-northeast3-b --format='yaml(serviceAccounts)'
curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
echo
for project in pjt-c-admin pjt-d-host01 prj-b-cicd-local-236d; do
  gcloud projects describe "$project" --format='value(projectId)'
done
echo 'Preflight read checks completed. Run terraform plan before apply.'
