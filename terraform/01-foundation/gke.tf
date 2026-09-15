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
  deletion_protection = var.gke_deletion_protection

  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_main_pod_range_name
  }

  # Cloud Build private workers have no public internet path. Keep the
  # Kubernetes API on the Shared VPC private control-plane endpoint.
  private_cluster_config {
    enable_private_nodes      = true
    enable_private_endpoint   = true
    master_ipv4_cidr_block    = var.gke_main_control_plane_cidr
  }

  # GKE requires Master Authorized Networks when the private endpoint is enabled.
  # Allow only the Private Pool PSA range and the IAP-admin VM subnet.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.cloudbuild_private_pool_ip_range
      display_name = "cloud-build-private-pool"
    }
    cidr_blocks {
      cidr_block   = var.admin_access_cidr
      display_name = "admin-vm-subnet"
    }
  }

  # Cloud Build Private Pool reaches the API through the GKE DNS endpoint.
  # IAM remains required; this setting only allows traffic to that endpoint.
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = var.gke_dns_endpoint_allow_external_traffic
    }
  }

  workload_identity_config {
    workload_pool = "${var.gke_project_id}.svc.id.goog"
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
  deletion_protection = var.gke_deletion_protection

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

  depends_on = [google_project_service.cicd["container.googleapis.com"]]
}
