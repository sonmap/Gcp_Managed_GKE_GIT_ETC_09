resource "google_storage_bucket" "task" {
  project                     = var.resource_project_id
  name                        = "${var.resource_project_id}-${var.task_name}-data"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  versioning { enabled = true }
}
resource "google_storage_bucket_iam_member" "group" {
  bucket = google_storage_bucket.task.name
  role   = "roles/storage.objectUser"
  member = "group:${var.group_email}"
}
resource "google_storage_bucket_iam_member" "jupyter" {
  bucket = google_storage_bucket.task.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.jupyter.email}"
}
