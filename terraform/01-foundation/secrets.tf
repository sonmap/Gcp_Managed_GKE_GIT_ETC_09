locals {
  jupyter_oauth_secrets = {
    client_id     = "jupyter-oauth-client-id"
    client_secret = "jupyter-oauth-client-secret"
  }
}

resource "google_secret_manager_secret" "jupyter_oauth" {
  for_each  = local.jupyter_oauth_secrets
  project   = var.cicd_project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.cicd]
}

resource "google_secret_manager_secret_iam_member" "terraform" {
  for_each  = google_secret_manager_secret.jupyter_oauth
  project   = var.cicd_project_id
  secret_id = each.value.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.terraform.email}"
}
