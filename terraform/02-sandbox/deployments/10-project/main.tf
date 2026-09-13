provider "google" {}

resource "google_project" "sandbox" {
  project_id      = var.project_id
  name            = var.project_name
  folder_id       = var.folder_id
  billing_account = var.billing_account
  deletion_policy = "PREVENT"

  labels = {
    environment = "sandbox"
    task        = var.task_name
    expires-on  = replace(var.expires_on, "-", "")
    managed-by  = "infrastructure-manager"
  }
}

locals {
  required_services = toset([
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each           = local.required_services
  project            = google_project.sandbox.project_id
  service            = each.value
  disable_on_destroy = false
}

locals {
  bootstrap_roles = {
    project_iam_admin = {
      member = "serviceAccount:${var.project_iam_service_account}"
      role   = "roles/resourcemanager.projectIamAdmin"
    }
    data_bigquery_admin = {
      member = "serviceAccount:${var.data_admin_service_account}"
      role   = "roles/bigquery.admin"
    }
    data_storage_admin = {
      member = "serviceAccount:${var.data_admin_service_account}"
      role   = "roles/storage.admin"
    }
    data_service_account_admin = {
      member = "serviceAccount:${var.data_admin_service_account}"
      role   = "roles/iam.serviceAccountAdmin"
    }
    data_project_iam_admin = {
      member = "serviceAccount:${var.data_admin_service_account}"
      role   = "roles/resourcemanager.projectIamAdmin"
    }
    data_service_usage = {
      member = "serviceAccount:${var.data_admin_service_account}"
      role   = "roles/serviceusage.serviceUsageConsumer"
    }
  }
}

resource "google_project_iam_member" "bootstrap" {
  for_each = local.bootstrap_roles
  project  = google_project.sandbox.project_id
  role     = each.value.role
  member   = each.value.member
}

output "project_id" { value = google_project.sandbox.project_id }
output "project_number" { value = google_project.sandbox.number }
