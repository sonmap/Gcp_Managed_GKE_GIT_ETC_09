resource "google_cloud_run_v2_service" "provisioner" {
  count    = var.provisioner_image == "" ? 0 : 1
  project  = var.cicd_project_id
  name     = "run-sandbox-provisioner"
  location = var.region
  ingress  = var.provisioner_ingress

  template {
    service_account = google_service_account.provisioner.email
    containers {
      image = var.provisioner_image
      env { name = "GCP_PROJECT", value = var.cicd_project_id }
      env { name = "GCP_REGION", value = var.region }
      env { name = "WORKER_POOL", value = google_cloudbuild_worker_pool.terraform.id }
      env { name = "GITHUB_REPOSITORY", value = "${var.github_owner}/${var.github_repository}" }
      env { name = "BUILD_TRIGGER_ID", value = var.sandbox_build_trigger_id }
    }
    vpc_access {
      network_interfaces {
        network    = data.google_compute_network.shared.id
        subnetwork = google_compute_subnetwork.cloudrun_egress.id
        tags       = ["cloud-run-sandbox-provisioner"]
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "provisioner_invoker" {
  count    = var.provisioner_image == "" ? 0 : 1
  project  = var.cicd_project_id
  location = var.region
  name     = google_cloud_run_v2_service.provisioner[0].name
  role     = "roles/run.invoker"
  member   = "group:pgrp-gcp-dev-l2-admin@sonmap.net"
}
