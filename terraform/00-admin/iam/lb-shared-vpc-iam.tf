# Shared VPC permissions required by the Infrastructure Manager load-balancer
# service account when a regional internal HTTPS load balancer is created in
# pjt-d-host01 but uses the frontend subnet from pjt-d-shared-base.
resource "google_project_iam_member" "lb_admin_shared_vpc_network_viewer" {
  count = local.full_scope && var.manage_lb_admin_shared_vpc_iam ? 1 : 0

  project = var.shared_vpc_host_project_id
  role    = "roles/compute.networkViewer"
  member  = "serviceAccount:${var.lb_admin_service_account}"
}

resource "google_compute_subnetwork_iam_member" "lb_admin_frontend_subnet_network_user" {
  count = local.full_scope && var.manage_lb_admin_shared_vpc_iam ? 1 : 0

  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = var.lb_frontend_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.lb_admin_service_account}"
}
