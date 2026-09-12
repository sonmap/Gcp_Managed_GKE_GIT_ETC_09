data "google_compute_network" "shared" {
  provider = google.host
  name     = var.network_name
  project  = var.shared_vpc_host_project_id
}

data "google_compute_subnetwork" "gke" {
  provider = google.host
  name     = var.gke_subnet_name
  region   = var.region
  project  = var.shared_vpc_host_project_id
}

