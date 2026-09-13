locals {
  cloud_run_service_agent = "service-${var.cicd_project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  project_factory_roles = toset([
    "roles/browser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])
}

resource "google_compute_subnetwork_iam_member" "cloud_run_network_user" {
  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.cloudrun_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${local.cloud_run_service_agent}"
}

resource "google_project_iam_member" "cloud_run_network_viewer" {
  project = var.shared_vpc_host_project_id
  role    = "roles/compute.networkViewer"
  member  = "serviceAccount:${local.cloud_run_service_agent}"
}

# This root is executed by a top-level administrator. The lower-privileged
# 01-foundation executor cannot bootstrap IAM on an existing business project.
resource "google_project_iam_member" "project_factory_existing_project_roles" {
  for_each = local.project_factory_roles

  project = var.existing_sandbox_project_id
  role    = each.value
  member  = "serviceAccount:${var.project_factory_service_account}"
}
