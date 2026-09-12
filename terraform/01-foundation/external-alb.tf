# The GKE standalone NEGs and the backend service must be in the GKE service
# project. The Shared VPC network and firewall policy remain in the host project.
locals { create_external_alb = var.external_lb_domain != "" && length(var.jupyter_neg_self_links) > 0 }

resource "google_compute_security_policy" "jupyter" {
  count   = local.create_external_alb ? 1 : 0
  project = var.gke_project_id
  name    = "armor-jupyterhub"
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    description = "IAP performs identity enforcement; add corporate IP allow rules when known."
  }
}

resource "google_compute_health_check" "jupyter" {
  count   = local.create_external_alb ? 1 : 0
  project = var.gke_project_id
  name    = "hc-jupyterhub"
  http_health_check {
    port = 8000
    request_path = "/hub/health"
  }
}

resource "google_compute_backend_service" "jupyter" {
  count                 = local.create_external_alb ? 1 : 0
  project               = var.gke_project_id
  name                  = "bes-jupyterhub"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.jupyter[0].id]
  security_policy       = google_compute_security_policy.jupyter[0].id

  dynamic "backend" {
    for_each = var.jupyter_neg_self_links
    content {
      group = backend.value
      balancing_mode = "RATE"
      max_rate_per_endpoint = 100
    }
  }

  dynamic "iap" {
    for_each = var.iap_oauth2_client_id == "" ? [] : [1]
    content {
      enabled              = true
      oauth2_client_id     = var.iap_oauth2_client_id
      oauth2_client_secret = var.iap_oauth2_client_secret
    }
  }
}

resource "google_compute_managed_ssl_certificate" "jupyter" {
  count   = local.create_external_alb ? 1 : 0
  project = var.gke_project_id
  name    = "cert-jupyterhub"
  managed { domains = [var.external_lb_domain] }
}

resource "google_compute_global_address" "jupyter" {
  count   = local.create_external_alb ? 1 : 0
  project = var.gke_project_id
  name    = "ip-jupyterhub-external"
}

resource "google_compute_url_map" "jupyter" {
  count           = local.create_external_alb ? 1 : 0
  project         = var.gke_project_id
  name            = "urlmap-jupyterhub"
  default_service = google_compute_backend_service.jupyter[0].id
}

resource "google_compute_target_https_proxy" "jupyter" {
  count            = local.create_external_alb ? 1 : 0
  project          = var.gke_project_id
  name             = "https-proxy-jupyterhub"
  url_map          = google_compute_url_map.jupyter[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.jupyter[0].id]
}

resource "google_compute_global_forwarding_rule" "jupyter" {
  count                 = local.create_external_alb ? 1 : 0
  project               = var.gke_project_id
  name                  = "fr-jupyterhub-https"
  ip_address            = google_compute_global_address.jupyter[0].id
  port_range            = "443"
  target                = google_compute_target_https_proxy.jupyter[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
