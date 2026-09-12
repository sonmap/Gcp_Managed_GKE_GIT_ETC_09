resource "google_container_cluster" "sandbox" {
  provider = google-beta
  project  = var.gke_project_id
  name     = var.gke_cluster_name
  location = var.region

  enable_autopilot    = true
  network             = var.shared_vpc_network_self_link
  subnetwork          = var.gke_subnet_self_link
  networking_mode     = "VPC_NATIVE"
  deletion_protection = true

  ip_allocation_policy {
    cluster_secondary_range_name  = var.gke_pod_range_name
    services_ipv4_cidr_block       = var.gke_service_ipv4_cidr
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  workload_identity_config {
    workload_pool = "${var.gke_project_id}.svc.id.goog"
  }

  depends_on = [google_project_service.gke]
}
