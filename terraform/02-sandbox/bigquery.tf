resource "google_bigquery_dataset" "task" {
  project                    = var.resource_project_id
  dataset_id                 = "${replace(var.task_name, "-", "_")}_main"
  location                   = var.region
  delete_contents_on_destroy = false
  depends_on                 = [google_project_service.sandbox]
}
resource "google_bigquery_dataset_iam_member" "group_editor" {
  project    = var.resource_project_id
  dataset_id = google_bigquery_dataset.task.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "group:${var.group_email}"
}
resource "google_bigquery_dataset_iam_member" "jupyter_editor" {
  project    = var.resource_project_id
  dataset_id = google_bigquery_dataset.task.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.jupyter.email}"
}
