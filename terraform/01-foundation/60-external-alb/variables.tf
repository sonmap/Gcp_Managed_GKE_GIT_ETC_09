variable "gke_project_id" {
  type    = string
  default = "pjt-d-host01"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "alb_name" {
  type    = string
  default = "alb-jupyter-shared"
}

# The certificate content/private key is intentionally not stored in Git.
# Create or rotate the self-managed certificate out-of-band, then reference it
# here by Compute SSL certificate resource name.
variable "ssl_certificate_name" {
  type    = string
  default = "cert-jupyter-sbx01-self"
}

# Deprecated compatibility input. Per-sandbox host/path routes are now added
# by automation-runner/reconcile_postdeploy.py and are not Foundation state.
variable "sandbox_routes" {
  type = map(object({
    hostname             = string
    backend_service_name = string
  }))
  default = {}
}
