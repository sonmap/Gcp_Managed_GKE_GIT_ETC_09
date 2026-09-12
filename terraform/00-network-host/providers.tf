provider "google" {
  project = var.shared_vpc_host_project_id
  region  = var.region
}
