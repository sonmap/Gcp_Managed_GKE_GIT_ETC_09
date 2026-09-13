resource "google_storage_bucket" "terraform_state" {
  project                     = var.cicd_project_id
  name                        = var.state_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning { enabled = true }
}

resource "google_storage_bucket_iam_member" "terraform_state" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

# Cloud Build uses the project's Compute Engine default service account in this
# environment. It must read the source archive staged in the regional state
# bucket before it can build either automation image.
resource "google_storage_bucket_iam_member" "cloud_build_reads_staged_source" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${data.google_project.cicd.number}-compute@developer.gserviceaccount.com"
}
