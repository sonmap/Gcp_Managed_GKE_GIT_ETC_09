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

# The platform-release Cloud Build runs as the sandbox orchestrator SA and
# publishes immutable runner/provisioner tags plus the compatibility :latest tag.
resource "google_artifact_registry_repository_iam_member" "orchestrator_release_writer" {
  project    = var.cicd_project_id
  location   = var.region
  repository = google_artifact_registry_repository.platform.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
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

# The workspace operator may perform an emergency/manual Helm upgrade from
# instance-son. Helm OCI pull requires repository read permission for the
# active gcloud user; keep the grant repository-scoped rather than project-wide.
resource "google_artifact_registry_repository_iam_member" "workspace_admin_reader" {
  project    = var.cicd_project_id
  location   = var.region
  repository = google_artifact_registry_repository.platform.name
  role       = "roles/artifactregistry.reader"
  member     = "user:${var.workspace_admin_subject}"
}
