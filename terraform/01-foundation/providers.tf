provider "google" {
  project = var.cicd_project_id
  region  = var.region
}

provider "google" {
  alias   = "host"
  project = var.shared_vpc_host_project_id
  region  = var.region
}

provider "google" {
  alias   = "gke"
  project = var.gke_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.cicd_project_id
  region  = var.region
}

