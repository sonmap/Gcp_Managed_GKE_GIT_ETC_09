locals {
  request_bucket_name = var.request_bucket_name != "" ? var.request_bucket_name : "${var.cicd_project_id}-sandbox-requests"
  bundle_bucket_name  = var.bundle_bucket_name != "" ? var.bundle_bucket_name : "${var.cicd_project_id}-sandbox-bundles"
}

data "google_project" "cicd" {
  project_id = var.cicd_project_id
}

resource "google_storage_bucket" "requests" {
  project                     = var.cicd_project_id
  name                        = local.request_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  versioning { enabled = true }
}

resource "google_storage_bucket" "bundles" {
  project                     = var.cicd_project_id
  name                        = local.bundle_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  versioning { enabled = true }
}

resource "google_storage_bucket_iam_member" "api_reads_requests" {
  bucket = google_storage_bucket.requests.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.automation["api"].email}"
}

resource "google_storage_bucket_iam_member" "portal_creates_approved_requests" {
  bucket = google_storage_bucket.requests.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.automation["portal"].email}"
}

resource "google_storage_bucket_iam_member" "api_writes_bundles" {
  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.automation["api"].email}"
}

resource "google_storage_bucket_iam_member" "orchestrator_reads_bundles" {
  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_storage_bucket_iam_member" "orchestrator_updates_runtime_bundle" {
  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_storage_bucket_iam_member" "deployment_accounts_read_bundles" {
  for_each = toset(["project_factory", "network_admin", "project_iam", "data_admin", "gke_admin", "lb_admin"])

  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.automation[each.value].email}"
}

resource "google_storage_bucket_iam_member" "infra_manager_service_agent_reads_bundles" {
  bucket = google_storage_bucket.bundles.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.cicd.number}@gcp-sa-config.iam.gserviceaccount.com"
}
