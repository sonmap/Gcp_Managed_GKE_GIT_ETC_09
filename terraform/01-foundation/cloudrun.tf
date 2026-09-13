
locals {
  cloudrun_subnet_name = element(reverse(split("/", var.cloudrun_subnet_self_link)), 0)
}

# In Shared VPC, Cloud Run's Google-managed service agent must be allowed to
# attach its Direct VPC Egress interface to the host-project subnet.
resource "google_compute_subnetwork_iam_member" "cloud_run_service_agent_network_user" {
  provider   = google.host
  project    = var.shared_vpc_host_project_id
  region     = var.region
  subnetwork = local.cloudrun_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.cicd.number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [google_project_service.cicd["run.googleapis.com"]]
}

resource "google_cloud_run_v2_service" "provisioner" {
  project  = var.cicd_project_id
  name     = "run-sandbox-provisioner"
  location = var.region
  ingress             = var.provisioner_ingress
  deletion_protection = false

  template {
    service_account = google_service_account.automation["api"].email
    timeout         = "300s"
    containers {
      image = local.provisioner_image_uri
      env {
        name  = "PROVISIONER_SOURCE_VERSION"
        value = local.provisioner_source_hash
      }
      env {
        name  = "GCP_PROJECT"
        value = var.cicd_project_id
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "BUILD_TRIGGER_ID"
        value = google_cloudbuild_trigger.sandbox_orchestrate.trigger_id
      }
      env {
        name  = "WORKER_POOL"
        value = google_cloudbuild_worker_pool.terraform.id
      }
      env {
        name  = "JUPYTER_CHART_URI"
        value = var.jupyter_chart_uri
      }
      env {
        name  = "JUPYTER_CHART_VERSION"
        value = var.jupyter_chart_version
      }
      env {
        name  = "REQUEST_BUCKET"
        value = google_storage_bucket.requests.name
      }
      env {
        name  = "BUNDLE_BUCKET"
        value = google_storage_bucket.bundles.name
      }
      env {
        name  = "GITHUB_REPOSITORY"
        value = "${var.github_owner}/${var.github_repository}"
      }
    }
    vpc_access {
      network_interfaces {
        network    = var.shared_vpc_network_self_link
        subnetwork = var.cloudrun_subnet_self_link
        tags       = ["cloud-run-sandbox-provisioner"]
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
  }
  depends_on = [
    terraform_data.provisioner_image,
    google_compute_subnetwork_iam_member.cloud_run_service_agent_network_user,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "provisioner_invoker" {
  project  = var.cicd_project_id
  location = var.region
  name     = google_cloud_run_v2_service.provisioner.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.automation["portal"].email}"
}
