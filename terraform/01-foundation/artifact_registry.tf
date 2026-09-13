resource "google_artifact_registry_repository" "platform" {
  project       = var.cicd_project_id
  location      = var.region
  repository_id = "ar-sandbox-platform"
  format        = "DOCKER"
  depends_on    = [google_project_service.cicd]
}

