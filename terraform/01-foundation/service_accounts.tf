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

resource "google_project_iam_member" "terraform_cicd" {
  for_each = toset([
    "roles/cloudbuild.workerPoolUser",
    "roles/logging.logWriter",
  ])

  project = var.cicd_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_resource_project" {
  for_each = toset([
    "roles/bigquery.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ])

  project = var.resource_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_project_iam_member" "terraform_gke_project" {
  for_each = toset([
    "roles/container.admin",
  ])

  project = var.gke_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_service_account_iam_member" "provisioner_uses_terraform" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.provisioner.email}"
}

resource "google_service_account_iam_member" "foundation_executor_uses_terraform" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.foundation_executor_service_account}"
}
