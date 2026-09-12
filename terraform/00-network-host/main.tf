data "google_compute_network" "shared" {
  project = var.shared_vpc_host_project_id
  name    = var.network_name
}
data "google_compute_subnetwork" "gke" {
  project = var.shared_vpc_host_project_id
  region  = var.region
  name    = var.gke_subnet_name
}
resource "google_compute_subnetwork" "cloudrun_egress" {
  project = var.shared_vpc_host_project_id
  name = "subnet-cloudrun-egress-an3"
  region = var.region
  network = data.google_compute_network.shared.id
  ip_cidr_range = var.cloudrun_subnet_cidr
  private_ip_google_access = true
}
resource "google_compute_global_address" "cloudbuild_psa" {
  project = var.shared_vpc_host_project_id
  name = "psa-cloudbuild"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  network = data.google_compute_network.shared.id
  address = split("/", var.cloudbuild_psa_cidr)[0]
  prefix_length = tonumber(split("/", var.cloudbuild_psa_cidr)[1])
}
resource "google_service_networking_connection" "private_service_access" {
  network = data.google_compute_network.shared.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_psa.name]
}
resource "google_compute_subnetwork" "task" {
  project = var.shared_vpc_host_project_id
  name = "subnet-${var.task_name}-an3"
  region = var.region
  network = data.google_compute_network.shared.id
  ip_cidr_range = var.task_subnet_cidr
  private_ip_google_access = true
  lifecycle {
    precondition {
      condition = tonumber(split("/", var.task_subnet_cidr)[1]) == 24
      error_message = "task_subnet_cidr must be /24."
    }
  }
}
resource "google_compute_subnetwork_iam_member" "task_vm" {
  project = var.shared_vpc_host_project_id
  region = var.region
  subnetwork = google_compute_subnetwork.task.name
  role = "roles/compute.networkUser"
  member = "serviceAccount:${var.task_vm_service_account_email}"
}
resource "google_compute_firewall" "health_checks_to_pods" {
  project = var.shared_vpc_host_project_id
  name = "fw-allow-google-hc-jupyter-pods"
  network = data.google_compute_network.shared.name
  direction = "INGRESS"
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  destination_ranges = [var.gke_pod_cidr]
  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
}
