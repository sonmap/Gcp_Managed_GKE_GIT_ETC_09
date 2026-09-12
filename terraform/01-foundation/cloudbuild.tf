locals {
  provisioner_image_uri = "${var.region}-docker.pkg.dev/${var.cicd_project_id}/ar-sandbox-platform/run-sandbox-provisioner:latest"
  provisioner_source_hash = sha256(join("", [
    filesha256("${path.module}/../../cloudrun-provisioner/Dockerfile"),
    filesha256("${path.module}/../../cloudrun-provisioner/main.py"),
    filesha256("${path.module}/../../cloudrun-provisioner/requirements.txt"),
  ]))
}

resource "google_cloudbuild_worker_pool" "terraform" {
  project  = var.cicd_project_id
  name     = "pool-sandbox-terraform"
  location = var.region

  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-4"
    no_external_ip = true
  }

  network_config {
    peered_network = var.shared_vpc_network_self_link
  }
}

resource "terraform_data" "provisioner_image" {
  triggers_replace = [
    local.provisioner_image_uri,
    local.provisioner_source_hash,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit "${path.module}/../../cloudrun-provisioner"         --project="${var.cicd_project_id}"         --region="${var.region}"         --tag="${local.provisioner_image_uri}"         --quiet
    EOT
  }

  depends_on = [google_artifact_registry_repository.platform]
}

resource "google_cloudbuild_trigger" "sandbox_dispatch" {
  project         = var.cicd_project_id
  location        = var.region
  name            = "trigger-sandbox-dispatch"
  description     = "Cloud Run initiated Terraform provisioning for sandbox tasks"
  service_account = google_service_account.terraform.id
  filename        = "cloudbuild/sandbox-dispatch.yaml"

  github {
    owner = var.github_owner
    name  = var.github_repository

    push {
      branch = "^${var.github_branch}$"
    }
  }

  substitutions = {
    _ACTION            = "plan"
    _TASK_NAME         = var.default_task_name
    _GROUP_EMAIL       = var.default_group_email
    _STATE_BUCKET      = var.state_bucket_name
    _WORKER_POOL       = google_cloudbuild_worker_pool.terraform.id
    _JUPYTER_DOMAIN    = var.jupyter_domain
    _ENABLE_JUPYTERHUB = "true"
  }

  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"

  depends_on = [
    google_project_iam_member.terraform_cicd,
    google_project_iam_member.terraform_resource_project,
    google_project_iam_member.terraform_gke_project,
    google_secret_manager_secret_iam_member.terraform,
  ]
}
