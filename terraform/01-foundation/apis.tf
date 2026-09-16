locals {
  cicd_apis = toset([
    "artifactregistry.googleapis.com", "cloudbuild.googleapis.com",
    "run.googleapis.com", "secretmanager.googleapis.com",
    "serviceusage.googleapis.com", "servicenetworking.googleapis.com",
    "config.googleapis.com", "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com", "iamcredentials.googleapis.com",
    "admin.googleapis.com", "compute.googleapis.com",
    "container.googleapis.com", "workflows.googleapis.com"
  ])
  gke_apis = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
  ])
}

resource "google_project_service" "cicd" {
  for_each           = local.cicd_apis
  project            = var.cicd_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "gke" {
  provider           = google.gke
  for_each           = local.gke_apis
  project            = var.gke_project_id
  service            = each.value
  disable_on_destroy = false
}

# This provider version has no google_project_service_identity resource.
# Create the Infrastructure Manager service agent with gcloud, then Terraform
# can safely grant it access to the sandbox bundle bucket.
resource "terraform_data" "infra_manager_service_identity" {
  provisioner "local-exec" {
    command = "gcloud beta services identity create --project=${var.cicd_project_id} --service=config.googleapis.com --quiet"
  }

  depends_on = [google_project_service.cicd["config.googleapis.com"]]
}
