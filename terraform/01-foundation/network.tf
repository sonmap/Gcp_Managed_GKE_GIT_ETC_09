resource "google_compute_subnetwork" "cloudrun_egress" {
  provider                 = google.host
  project                  = var.shared_vpc_host_project_id
  name                     = "subnet-cloudrun-egress-an3"
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.cloudrun_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_global_address" "cloudbuild_psa" {
  provider      = google.host
  project       = var.shared_vpc_host_project_id
  name          = "psa-cloudbuild"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = data.google_compute_network.shared.id
  address       = split("/", var.cloudbuild_psa_cidr)[0]
  prefix_length = tonumber(split("/", var.cloudbuild_psa_cidr)[1])
}

resource "google_service_networking_connection" "private_service_access" {
  provider                = google.host
  network                 = data.google_compute_network.shared.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_psa.name]
}

