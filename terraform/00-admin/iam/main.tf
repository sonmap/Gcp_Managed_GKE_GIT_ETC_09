locals {
  cloud_run_service_agent = "service-${var.cicd_project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  project_factory_roles = toset([
    "roles/browser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  network_admin_host_roles = toset([
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
  ])

  workflow_gke_project_roles = toset([
    "roles/container.developer",
  ])

  workflow_existing_project_roles = toset([
    "roles/browser",
  ])

  workflow_shared_vpc_roles = toset([
    "roles/compute.networkViewer",
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

# The Infrastructure Manager network deployment creates subnets and, when
# enabled, Shared VPC firewall rules in the host project.
resource "google_project_iam_member" "network_admin_host_roles" {
  for_each = local.network_admin_host_roles

  project = var.shared_vpc_host_project_id
  role    = each.value
  member  = "serviceAccount:${var.network_admin_service_account}"
}

# roles/compute.xpnAdmin can only be granted at folder or organization level.
# The common folder contains both the host and approved service project.
resource "google_folder_iam_member" "network_admin_shared_vpc_admin" {
  folder = var.shared_vpc_admin_folder_id
  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${var.network_admin_service_account}"
}

# Workflow is allowed to manage Kubernetes workloads, but not to create,
# delete, or reconfigure the pjt-d-host01 GKE cluster infrastructure.
resource "google_project_iam_member" "workflow_gke_project_roles" {
  for_each = local.workflow_gke_project_roles

  project = var.gke_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}

# Workflow can verify the approved existing sandbox project. Data mutation
# remains delegated to sa-im-data-admin.
resource "google_project_iam_member" "workflow_existing_project_roles" {
  for_each = local.workflow_existing_project_roles

  project = var.existing_sandbox_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}

# Workflow may inspect Shared VPC resources; network mutation remains delegated
# to sa-im-network-admin.
resource "google_project_iam_member" "workflow_shared_vpc_roles" {
  for_each = local.workflow_shared_vpc_roles

  project = var.shared_vpc_host_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}
