resource "google_cloud_run_v2_service" "provisioner" {
  project  = var.cicd_project_id
  name     = "run-sandbox-provisioner"
  location = var.region
  ingress  = var.provisioner_ingress

  template {
    service_account = google_service_account.automation["api"].email
    timeout         = "300s"
    containers {
      image = local.provisioner_image_uri
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
  depends_on = [terraform_data.provisioner_image]
}

resource "google_cloud_run_v2_service_iam_member" "provisioner_invoker" {
  project  = var.cicd_project_id
  location = var.region
  name     = google_cloud_run_v2_service.provisioner.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.automation["portal"].email}"
}
