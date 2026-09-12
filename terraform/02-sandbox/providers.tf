data "google_client_config" "current" {}

provider "google" {
  project = var.resource_project_id
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

data "google_container_cluster" "sandbox" {
  provider = google.gke
  project  = var.gke_project_id
  name     = var.gke_cluster_name
  location = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.sandbox.endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.sandbox.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.sandbox.endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.sandbox.master_auth[0].cluster_ca_certificate)
  }
}
