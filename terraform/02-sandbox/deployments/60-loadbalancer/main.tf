provider "google" {
  project = var.gke_project_id
  region  = var.region
}

# Each sandbox owns only its global health check and EXTERNAL backend service.
# The shared Classic External ALB (IP / forwarding rule / proxy / URL map) is
# created once by terraform/01-foundation/60-external-alb.
resource "google_compute_health_check" "jupyter" {
  project = var.gke_project_id
  name    = "hc-jupyter-${var.task_name}"

  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path       = "/hub/health"
  }
}

resource "google_compute_backend_service" "jupyter" {
  project               = var.gke_project_id
  name                  = "bes-jupyter-${var.task_name}"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.jupyter.id]

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

output "backend_service_name" {
  value = google_compute_backend_service.jupyter.name
}

output "backend_service_self_link" {
  value = google_compute_backend_service.jupyter.self_link
}

output "health_check_name" {
  value = google_compute_health_check.jupyter.name
}
