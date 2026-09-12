resource "google_compute_subnetwork" "task" {
  provider                 = google.host
  project                  = var.shared_vpc_host_project_id
  name                     = "subnet-${var.task_name}-an3"
  region                   = var.region
  network                  = data.google_compute_network.shared.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  lifecycle {
    precondition {
      condition     = tonumber(split("/", var.subnet_cidr)[1]) == 24
      error_message = "subnet_cidr must be a /24 CIDR."
    }
  }
}

resource "google_compute_subnetwork_iam_member" "vm_network_user" {
  provider   = google.host
  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.task.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.vm.email}"
}

