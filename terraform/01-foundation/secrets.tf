locals {
  automation_secrets = toset([
    "google-workspace-dwd-key",
    "jupyter-oauth-client-id",
    "jupyter-oauth-client-secret",
  ])
}

resource "google_secret_manager_secret" "automation" {
  for_each  = local.automation_secrets
  project   = var.cicd_project_id
  secret_id = each.value
  replication {
    auto {}
  }
  depends_on = [google_project_service.cicd]
}

resource "google_secret_manager_secret_iam_member" "orchestrator" {
  for_each  = local.automation_secrets
  project   = var.cicd_project_id
  secret_id = google_secret_manager_secret.automation[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}
