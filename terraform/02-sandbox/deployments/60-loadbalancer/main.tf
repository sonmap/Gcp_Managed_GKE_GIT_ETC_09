provider "google" {
  project = var.gke_project_id
  region  = var.region
}

data "google_compute_network" "shared" {
  project = var.shared_vpc_host_project_id
  name    = var.shared_vpc_network_name
}

data "google_compute_subnetwork" "frontend" {
  project = var.shared_vpc_host_project_id
  name    = var.frontend_subnet_name
  region  = var.region
}

resource "google_compute_region_health_check" "jupyter" {
  project = var.gke_project_id
  region  = var.region
  name    = "hc-jupyter-${var.task_name}"

  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/hub/health"
  }
}

resource "google_compute_region_backend_service" "jupyter" {
  project               = var.gke_project_id
  region                = var.region
  name                  = "bes-jupyter-${var.task_name}"
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_region_health_check.jupyter.id]

  dynamic "backend" {
    for_each = toset(var.neg_self_links)
    content {
      group                 = backend.value
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.neg_self_links) > 0
      error_message = "At least one Jupyter standalone NEG self link is required."
    }
  }
}

resource "google_certificate_manager_dns_authorization" "jupyter" {
  project     = var.gke_project_id
  name        = "dnsauth-jupyter-${var.task_name}"
  location    = var.region
  type        = "PER_PROJECT_RECORD"
  domain      = var.jupyter_domain
  description = "Regional DNS authorization for ${var.jupyter_domain}"
}

resource "google_certificate_manager_certificate" "jupyter" {
  project     = var.gke_project_id
  name        = "cert-jupyter-${var.task_name}"
  location    = var.region
  description = "Regional Google-managed certificate for ${var.jupyter_domain}"

  managed {
    domains = [var.jupyter_domain]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.jupyter.id,
    ]
  }
}

resource "google_compute_region_url_map" "jupyter" {
  project         = var.gke_project_id
  region          = var.region
  name            = "urlmap-jupyter-${var.task_name}"
  default_service = google_compute_region_backend_service.jupyter.id
}

resource "google_compute_region_target_https_proxy" "jupyter" {
  project = var.gke_project_id
  region  = var.region
  name    = "https-proxy-jupyter-${var.task_name}"
  url_map = google_compute_region_url_map.jupyter.id

  certificate_manager_certificates = [
    "//certificatemanager.googleapis.com/${google_certificate_manager_certificate.jupyter.id}",
  ]
}

# The internal IPv4 resource must be created in the same service project as
# the forwarding rule, while its address is allocated from the Shared VPC
# frontend subnet in the host project.
resource "google_compute_address" "jupyter" {
  project      = var.gke_project_id
  region       = var.region
  name         = "ip-jupyter-${var.task_name}"
  address_type = "INTERNAL"
  subnetwork   = data.google_compute_subnetwork.frontend.id
}

resource "google_compute_forwarding_rule" "jupyter" {
  project               = var.gke_project_id
  region                = var.region
  name                  = "fr-jupyter-${var.task_name}-https"
  ip_protocol           = "TCP"
  ip_address            = google_compute_address.jupyter.id
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.jupyter.id
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = data.google_compute_network.shared.id
  subnetwork            = data.google_compute_subnetwork.frontend.id
  allow_global_access   = true
}

output "internal_ip" {
  value = google_compute_address.jupyter.address
}

output "dns_authorization_record_name" {
  value = google_certificate_manager_dns_authorization.jupyter.dns_resource_record[0].name
}

output "dns_authorization_record_type" {
  value = google_certificate_manager_dns_authorization.jupyter.dns_resource_record[0].type
}

output "dns_authorization_record_data" {
  value = google_certificate_manager_dns_authorization.jupyter.dns_resource_record[0].data
}
