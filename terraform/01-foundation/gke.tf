# Main JupyterHub cluster in the GKE service project.
resource "google_container_cluster" "sandbox" {
  count = var.enable_gke_cluster_changes || var.enable_gke_main_cluster_changes ? 1 : 0

  provider = google-beta
  project  = var.gke_project_id
  name     = var.gke_cluster_name
  location = var.region

  enable_autopilot    = true
  network             = var.shared_vpc_network_self_link
  subnetwork          = var.gke_main_subnet_self_link
  networking_mode     = "VPC_NATIVE"
  deletion_protection = true

  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_main_pod_range_name
  }

  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = false
    master_ipv4_cidr_block    = var.gke_main_control_plane_cidr
  }

  workload_identity_config {
    workload_pool = "${var.gke_project_id}.svc.id.goog"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.gke]
}

# Small Autopilot cluster in the CI/CD project for Python program tests.
resource "google_container_cluster" "cicd_test" {
  count = var.enable_gke_cluster_changes || var.enable_gke_test_cluster_changes ? 1 : 0

  provider = google-beta
  project  = var.cicd_project_id
  name     = var.cicd_test_gke_cluster_name
  location = var.region

  enable_autopilot    = true
  network             = var.shared_vpc_network_self_link
  subnetwork          = var.gke_test_subnet_self_link
  networking_mode     = "VPC_NATIVE"
  deletion_protection = true

  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_test_pod_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.gke_test_control_plane_cidr
  }

  workload_identity_config {
    workload_pool = "${var.cicd_project_id}.svc.id.goog"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.cicd["container.googleapis.com"]]
}
