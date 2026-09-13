provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "jupyter" {
  project      = var.project_id
  account_id   = "gsa-jupyter-${var.task_name}"
  display_name = "Jupyter ${var.task_name}"
}

resource "google_bigquery_dataset" "sandbox" {
  project                    = var.project_id
  dataset_id                 = var.bigquery_dataset
  location                   = var.region
  delete_contents_on_destroy = false

  labels = {
    task       = var.task_name
    managed-by = "infrastructure-manager"
  }
}

resource "google_bigquery_dataset_iam_member" "group" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sandbox.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "group:${var.group_email}"
}

resource "google_bigquery_dataset_iam_member" "jupyter" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.sandbox.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.jupyter.email}"
}

resource "google_project_iam_member" "jupyter_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.jupyter.email}"
}

resource "google_storage_bucket" "sandbox" {
  project                     = var.project_id
  name                        = var.gcs_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    task       = var.task_name
    managed-by = "infrastructure-manager"
  }
}

resource "google_storage_bucket_iam_member" "group" {
  bucket = google_storage_bucket.sandbox.name
  role   = "roles/storage.objectUser"
  member = "group:${var.group_email}"
}

resource "google_storage_bucket_iam_member" "jupyter" {
  bucket = google_storage_bucket.sandbox.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.jupyter.email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.jupyter.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gke_project_id}.svc.id.goog[${var.gke_namespace}/${var.jupyter_ksa_name}]"
}

output "jupyter_service_account" { value = google_service_account.jupyter.email }
output "dataset_id" { value = google_bigquery_dataset.sandbox.dataset_id }
output "bucket_name" { value = google_storage_bucket.sandbox.name }
