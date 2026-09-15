locals {
  cloud_run_service_agent = "service-${var.cicd_project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  # Global bootstrap gate. No IAM policy is read or changed until this is
  # explicitly enabled by an account that already has IAM administration access.
  iam_changes_enabled = var.enable_iam_changes

  # Full cross-project/folder IAM requires three explicit gates. This prevents
  # stale local tfvars from expanding the plan unintentionally.
  full_scope = local.iam_changes_enabled && var.iam_scope == "full" && var.allow_full_scope

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

# Foundation executor bootstrap. The caller applying this root must already be
# IAM administrator on every selected project and Shared VPC subnet.
resource "google_compute_subnetwork_iam_member" "foundation_executor_gke_main_network_user" {
  count = local.full_scope && var.manage_foundation_executor_shared_vpc_iam ? 1 : 0

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.gke_main_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_compute_subnetwork_iam_member" "foundation_executor_gke_test_network_user" {
  count = local.full_scope && var.manage_foundation_executor_shared_vpc_iam ? 1 : 0

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.gke_test_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.foundation_executor_service_account}"
}

data "google_project" "gke" {
  count      = local.full_scope && var.manage_foundation_executor_shared_vpc_iam ? 1 : 0
  project_id = var.gke_project_id
}

resource "google_compute_subnetwork_iam_member" "main_gke_service_accounts_network_user" {
  for_each = local.full_scope && var.manage_foundation_executor_shared_vpc_iam ? toset([
    "service-${data.google_project.gke[0].number}@container-engine-robot.iam.gserviceaccount.com",
    "${data.google_project.gke[0].number}@cloudservices.gserviceaccount.com",
    "${data.google_project.gke[0].number}-compute@developer.gserviceaccount.com",
  ]) : toset([])

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.gke_main_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${each.value}"
}

# GKE Shared VPC requires the service project's GKE, Cloud Services, and
# default Compute service accounts to use the selected subnet.
resource "google_compute_subnetwork_iam_member" "cicd_test_gke_service_accounts_network_user" {
  for_each = local.full_scope && var.manage_foundation_executor_shared_vpc_iam ? toset([
    "service-${var.cicd_project_number}@container-engine-robot.iam.gserviceaccount.com",
    "${var.cicd_project_number}@cloudservices.gserviceaccount.com",
    "${var.cicd_project_number}-compute@developer.gserviceaccount.com",
  ]) : toset([])

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.gke_test_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "foundation_executor_gke_admin" {
  count = local.full_scope && var.manage_foundation_executor_gke_project_iam ? 1 : 0

  project = var.gke_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

# The nested GKE workload build impersonates this dedicated service account.
# It needs project-level GKE administration on the Main GKE project.
resource "google_project_iam_member" "gke_admin_gke_project_admin" {
  count = local.full_scope && var.manage_gke_admin_gke_project_iam ? 1 : 0

  project = var.gke_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.gke_admin_service_account}"
}

resource "google_project_iam_member" "foundation_executor_cicd_gke_admin" {
  count = local.full_scope && var.manage_foundation_executor_cicd_iam ? 1 : 0

  project = var.cicd_project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

# The Google provider reads the managed instance groups behind the Autopilot
# node pool after cluster creation.
resource "google_project_iam_member" "foundation_executor_cicd_compute_viewer" {
  count = local.full_scope && var.manage_foundation_executor_cicd_iam ? 1 : 0

  project = var.cicd_project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_project_iam_member" "foundation_executor_cicd_workflows_admin" {
  count = local.full_scope && var.manage_foundation_executor_cicd_iam ? 1 : 0

  project = var.cicd_project_id
  role    = "roles/workflows.admin"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

# Allows the VM Foundation executor to inspect Infrastructure Manager
# deployments and revisions without granting deployment mutation privileges.
resource "google_project_iam_member" "foundation_executor_cicd_config_viewer" {
  count = local.full_scope && var.manage_foundation_executor_cicd_iam ? 1 : 0

  project = var.cicd_project_id
  role    = "roles/config.viewer"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

# Cloud Run Direct VPC egress IAM. Disabled unless full scope is explicitly
# unlocked by an IAM administrator.
resource "google_compute_subnetwork_iam_member" "cloud_run_network_user" {
  count = local.full_scope && var.manage_cloud_run_shared_vpc_iam ? 1 : 0

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.cloudrun_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${local.cloud_run_service_agent}"
}

# Existing sandbox project bootstrap IAM. Disabled unless full scope is unlocked.
resource "google_project_iam_member" "project_factory_existing_project_roles" {
  for_each = local.full_scope && var.manage_project_factory_existing_project_iam ? local.project_factory_roles : toset([])

  project = var.existing_sandbox_project_id
  role    = each.value
  member  = "serviceAccount:${var.project_factory_service_account}"
}

# Shared VPC host roles for the network admin SA. These are also protected by
# the global gate because they require getIamPolicy/setIamPolicy on the host.
resource "google_project_iam_member" "network_admin_host_roles" {
  for_each = local.iam_changes_enabled && var.manage_network_admin_host_iam ? local.network_admin_host_roles : toset([])

  project = var.shared_vpc_host_project_id
  role    = each.value
  member  = "serviceAccount:${var.network_admin_service_account}"
}

# XPN Admin is folder-level and is disabled unless full scope is unlocked.
resource "google_folder_iam_member" "network_admin_shared_vpc_admin" {
  count = local.full_scope && var.manage_network_admin_xpn_iam ? 1 : 0

  folder = var.shared_vpc_admin_folder_id
  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${var.network_admin_service_account}"
}

resource "google_project_iam_member" "workflow_gke_project_roles" {
  for_each = local.full_scope && var.manage_workflow_gke_iam ? local.workflow_gke_project_roles : toset([])

  project = var.gke_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}

resource "google_project_iam_member" "workflow_existing_project_roles" {
  for_each = local.full_scope && var.manage_workflow_existing_project_iam ? local.workflow_existing_project_roles : toset([])

  project = var.existing_sandbox_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}

resource "google_project_iam_member" "workflow_shared_vpc_roles" {
  for_each = local.full_scope && var.manage_workflow_shared_vpc_iam ? local.workflow_shared_vpc_roles : toset([])

  project = var.shared_vpc_host_project_id
  role    = each.value
  member  = "serviceAccount:${var.workflow_service_account}"
}
