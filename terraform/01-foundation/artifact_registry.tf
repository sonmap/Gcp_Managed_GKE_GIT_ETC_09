resource "google_artifact_registry_repository" "platform" {
  project       = var.cicd_project_id
  location      = var.region
  repository_id = "ar-sandbox-platform"
  format        = "DOCKER"
  depends_on    = [google_project_service.cicd]
}

resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  project    = var.cicd_project_id
  location   = var.region
  repository = google_artifact_registry_repository.platform.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.cicd.number}-compute@developer.gserviceaccount.com"
}
