resource "google_compute_global_address" "jupyter" {
  project      = var.gke_project_id
  name         = "ip-${var.alb_name}"
  address_type = "EXTERNAL"
}

# Foundation is created before any sandbox namespace/NEG exists.
# Keep an empty classic External backend service as the URL-map default.
resource "google_compute_backend_service" "default" {
  project               = var.gke_project_id
  name                  = "bes-${var.alb_name}-default"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
}

# Sandbox backend services are created by the per-task Infrastructure Manager
# deployment. Foundation only references them and owns the shared URL map.
data "google_compute_backend_service" "sandbox" {
  for_each = var.sandbox_routes

  project = var.gke_project_id
  name    = each.value.backend_service_name
}

resource "google_compute_url_map" "jupyter" {
  project         = var.gke_project_id
  name            = "urlmap-${var.alb_name}"
  default_service = google_compute_backend_service.default.id

  dynamic "host_rule" {
    for_each = var.sandbox_routes
    content {
      hosts        = [host_rule.value.hostname]
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.sandbox_routes
    content {
      name            = path_matcher.key
      default_service = data.google_compute_backend_service.sandbox[path_matcher.key].id
    }
  }
}

resource "google_compute_target_http_proxy" "jupyter" {
  project = var.gke_project_id
  name    = "http-proxy-${var.alb_name}"
  url_map = google_compute_url_map.jupyter.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.gke_project_id
  name                  = "fr-${var.alb_name}-http"
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_global_address.jupyter.id
  target                = google_compute_target_http_proxy.jupyter.id
  load_balancing_scheme = "EXTERNAL"
}

output "external_ip" {
  value = google_compute_global_address.jupyter.address
}

output "url_map_name" {
  value = google_compute_url_map.jupyter.name
}

output "default_backend_service_name" {
  value = google_compute_backend_service.default.name
}

output "sandbox_routes" {
  value = var.sandbox_routes
}
