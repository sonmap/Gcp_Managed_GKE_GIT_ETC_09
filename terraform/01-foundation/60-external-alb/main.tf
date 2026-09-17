resource "google_compute_global_address" "jupyter" {
  project      = var.gke_project_id
  name         = "ip-${var.alb_name}"
  address_type = "EXTERNAL"
}

# Foundation must be deployable before any sandbox namespace/NEG exists.
# Use a private placeholder backend bucket as the URL-map default target.
# Sandbox host rules will later route jupyter-sbxXX domains to NEG backend services.
resource "google_storage_bucket" "placeholder" {
  project                     = var.gke_project_id
  name                        = "${var.gke_project_id}-${var.alb_name}-placeholder"
  location                    = "ASIA-NORTHEAST3"
  uniform_bucket_level_access = true
  force_destroy               = true

  public_access_prevention = "enforced"
}

resource "google_compute_backend_bucket" "placeholder" {
  project     = var.gke_project_id
  name        = "bb-${var.alb_name}-placeholder"
  bucket_name = google_storage_bucket.placeholder.name
  enable_cdn  = false
}

resource "google_compute_url_map" "jupyter" {
  project         = var.gke_project_id
  name            = "urlmap-${var.alb_name}"
  default_service = google_compute_backend_bucket.placeholder.id
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

output "placeholder_backend_bucket_name" {
  value = google_compute_backend_bucket.placeholder.name
}
