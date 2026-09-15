data "google_project" "gke" {
  project_id = var.gke_project_id
}

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

# Autopilot nodes use the Compute Engine default service account of the GKE
# project. The JupyterHub images are stored in the separate CI/CD project, so
# this narrow cross-project reader grant is required for node image pulls.
resource "google_artifact_registry_repository_iam_member" "gke_nodes_reader" {
  project    = var.cicd_project_id
  location   = var.region
  repository = google_artifact_registry_repository.platform.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_project.gke.number}-compute@developer.gserviceaccount.com"
}
