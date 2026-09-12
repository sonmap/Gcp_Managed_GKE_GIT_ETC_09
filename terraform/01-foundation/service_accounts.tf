resource "google_service_account" "provisioner" {
  project      = var.cicd_project_id
  account_id   = "sa-sandbox-api"
  display_name = "Sandbox provisioning API"
}

resource "google_service_account" "terraform" {
  project      = var.cicd_project_id
  account_id   = "sa-sandbox-terraform"
  display_name = "Sandbox Terraform executor"
}

resource "google_project_iam_member" "provisioner_builds_editor" {
  project = var.cicd_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.provisioner.email}"
}

resource "google_project_iam_member" "terraform_log_writer" {
  project = var.cicd_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

