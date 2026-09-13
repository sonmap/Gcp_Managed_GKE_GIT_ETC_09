provider "google" {
  project = var.gke_project_id
}

resource "google_compute_security_policy" "jupyter" {
  project = var.gke_project_id
  name    = "armor-jupyter-${var.task_name}"

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "JupyterHub performs Google identity authentication."
  }
}

resource "google_compute_health_check" "jupyter" {
  project = var.gke_project_id
  name    = "hc-jupyter-${var.task_name}"

  http_health_check {
    port         = 8000
    request_path = "/hub/health"
  }
}

resource "google_compute_backend_service" "jupyter" {
  project               = var.gke_project_id
  name                  = "bes-jupyter-${var.task_name}"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.jupyter.id]
  security_policy       = google_compute_security_policy.jupyter.id

  dynamic "backend" {
    for_each = toset(var.neg_self_links)
    content {
      group                 = backend.value
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.neg_self_links) > 0
      error_message = "At least one Jupyter standalone NEG self link is required."
    }
  }
}

resource "google_compute_managed_ssl_certificate" "jupyter" {
  project = var.gke_project_id
  name    = "cert-jupyter-${var.task_name}"

  managed {
    domains = [var.jupyter_domain]
  }
}

resource "google_compute_global_address" "jupyter" {
  project = var.gke_project_id
  name    = "ip-jupyter-${var.task_name}"
}

resource "google_compute_url_map" "jupyter" {
  project         = var.gke_project_id
  name            = "urlmap-jupyter-${var.task_name}"
  default_service = google_compute_backend_service.jupyter.id
}

resource "google_compute_target_https_proxy" "jupyter" {
  project          = var.gke_project_id
  name             = "https-proxy-jupyter-${var.task_name}"
  url_map          = google_compute_url_map.jupyter.id
  ssl_certificates = [google_compute_managed_ssl_certificate.jupyter.id]
}

resource "google_compute_global_forwarding_rule" "jupyter" {
  project               = var.gke_project_id
  name                  = "fr-jupyter-${var.task_name}-https"
  ip_address            = google_compute_global_address.jupyter.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.jupyter.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

output "external_ip" { value = google_compute_global_address.jupyter.address }
