data "google_compute_network" "shared" {
  project = var.shared_vpc_host_project_id
  name    = var.network_name
}

# Internal Application Load Balancer frontend: user traffic remains on 172.31.x.
resource "google_compute_subnetwork" "internal_alb_frontend" {
  project                  = var.shared_vpc_host_project_id
  name                     = var.internal_alb_frontend_subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.internal_alb_frontend_subnet_cidr
  private_ip_google_access = true
}

# Legacy host-project reservation retained for state compatibility. The actual
# regional internal ALB frontend IP is allocated in the GKE service project.
resource "google_compute_address" "jupyter_internal_alb" {
  project      = var.shared_vpc_host_project_id
  name         = var.jupyter_internal_alb_ip_name
  region       = var.region
  subnetwork   = google_compute_subnetwork.internal_alb_frontend.id
  address_type = "INTERNAL"
  address      = var.jupyter_internal_alb_ip
}

# sa-im-lb-admin creates the forwarding rule/IP in pjt-d-host01 but consumes
# this Shared VPC frontend subnet from the host project.
resource "google_compute_subnetwork_iam_member" "lb_admin_frontend_network_user" {
  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.internal_alb_frontend.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.lb_admin_service_account_email}"
}

# Google-managed Envoy proxies for a regional internal Application Load Balancer.
# This is not a frontend subnet and must be at least /26.
resource "google_compute_subnetwork" "internal_alb_proxy_only" {
  project       = var.shared_vpc_host_project_id
  name          = var.internal_alb_proxy_subnet_name
  region        = var.region
  network       = data.google_compute_network.shared.id
  ip_cidr_range = var.internal_alb_proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_subnetwork" "gke_main" {
  project                  = var.shared_vpc_host_project_id
  name                     = var.gke_main_subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.gke_main_subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.gke_main_pod_range_name
    ip_cidr_range = var.gke_main_pod_cidr
  }
}

resource "google_compute_subnetwork" "gke_test" {
  project                  = var.shared_vpc_host_project_id
  name                     = var.gke_test_subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.gke_test_subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.gke_test_pod_range_name
    ip_cidr_range = var.gke_test_pod_cidr
  }
}

resource "google_compute_subnetwork" "cloudrun_egress" {
  project                  = var.shared_vpc_host_project_id
  name                     = var.cloudrun_subnet_name
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.cloudrun_subnet_cidr
  private_ip_google_access = true
}

# Reserved VPC peering range used by the Cloud Build private pool configuration.
# It is not a Compute Engine subnet.
resource "google_compute_global_address" "cloudbuild_psa" {
  project       = var.shared_vpc_host_project_id
  name          = var.cloudbuild_psa_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  network       = data.google_compute_network.shared.id
  address       = split("/", var.cloudbuild_psa_cidr)[0]
  prefix_length = tonumber(split("/", var.cloudbuild_psa_cidr)[1])
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = data.google_compute_network.shared.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_psa.name]
}

# Per-task subnet is retained for the sandbox second-stage deployment.
resource "google_compute_subnetwork" "task" {
  project                  = var.shared_vpc_host_project_id
  name                     = "subnet-${var.task_name}-an3"
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.task_subnet_cidr
  private_ip_google_access = true

  lifecycle {
    precondition {
      condition     = tonumber(split("/", var.task_subnet_cidr)[1]) == 24
      error_message = "task_subnet_cidr must be /24."
    }
  }
}

resource "google_compute_subnetwork_iam_member" "task_vm" {
  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.task.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.task_vm_service_account_email}"
}

# Optional and protected by a separate global approval gate because the
# Foundation executor can have subnet/network permissions without
# compute.firewalls.create in the Shared VPC host project. Both switches must
# be true, and the caller must already have firewall administration permission.
resource "google_compute_firewall" "health_checks_to_main_pods" {
  count = var.enable_firewall_changes && var.create_health_check_firewall ? 1 : 0

  project            = var.shared_vpc_host_project_id
  name               = "fw-dev-sbx-gke-allow-l7-healthcheck"
  network            = data.google_compute_network.shared.name
  direction          = "INGRESS"
  source_ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
  destination_ranges = [var.gke_main_pod_cidr]

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
}

# Regional internal ALB data-plane traffic originates from the proxy-only
# subnet and must reach the standalone NEG endpoints on the Jupyter proxy port.
resource "google_compute_firewall" "internal_alb_proxy_to_main_pods" {
  count = var.enable_firewall_changes && var.create_health_check_firewall ? 1 : 0

  project            = var.shared_vpc_host_project_id
  name               = "fw-dev-sbx-gke-allow-ilb-proxy"
  network            = data.google_compute_network.shared.name
  direction          = "INGRESS"
  source_ranges      = [var.internal_alb_proxy_subnet_cidr]
  destination_ranges = [var.gke_main_pod_cidr]

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
}
