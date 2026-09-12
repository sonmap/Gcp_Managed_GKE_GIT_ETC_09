resource "google_service_account" "jupyter" {
  project      = var.resource_project_id
  account_id   = "gsa-jupyter-${var.task_name}"
  display_name = "Jupyter ${var.task_name}"
}
resource "kubernetes_service_account_v1" "jupyter" {
  metadata {
    name        = "ksa-jupyter-${var.task_name}"
    namespace   = kubernetes_namespace_v1.task.metadata[0].name
    annotations = { "iam.gke.io/gcp-service-account" = google_service_account.jupyter.email }
  }
}
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.jupyter.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gke_project_id}.svc.id.goog[${var.task_name}/${kubernetes_service_account_v1.jupyter.metadata[0].name}]"
}

