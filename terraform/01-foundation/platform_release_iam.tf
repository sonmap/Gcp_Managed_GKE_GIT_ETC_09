# Permissions used only by trigger-platform-release.
# The build runs as the existing sandbox orchestrator service account.

resource "google_storage_bucket_iam_member" "orchestrator_platform_release_writer" {
  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_project_iam_member" "orchestrator_cloud_run_developer" {
  project = var.cicd_project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_service_account_iam_member" "orchestrator_uses_api_runtime" {
  service_account_id = google_service_account.automation["api"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}
