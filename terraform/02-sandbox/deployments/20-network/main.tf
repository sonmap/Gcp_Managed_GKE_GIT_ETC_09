provider "google" {
  project = var.host_project_id
  region  = var.region
}

data "google_compute_network" "shared" {
  project = var.host_project_id
  name    = var.network_name
}

resource "google_compute_subnetwork" "sandbox" {
  count = var.network_required ? 1 : 0

  project                  = var.host_project_id
  name                     = var.subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = var.private_google_access

  lifecycle {
    precondition {
      condition     = !var.network_required || can(cidrhost(var.subnet_cidr, 0))
      error_message = "subnet_cidr must be a valid CIDR when network_required=true."
    }
    precondition {
      condition     = !var.network_required || tonumber(split("/", var.subnet_cidr)[1]) == 24
      error_message = "Approved sandbox subnet must use a /24 prefix."
    }
  }
}

resource "google_compute_shared_vpc_service_project" "sandbox" {
  count = var.network_required && var.shared_vpc_join ? 1 : 0

  host_project    = var.host_project_id
  service_project = var.service_project_id
}

output "subnet_self_link" {
  value = var.network_required ? google_compute_subnetwork.sandbox[0].self_link : null
}
