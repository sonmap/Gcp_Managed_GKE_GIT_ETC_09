locals {
  provisioner_image_uri = "${var.region}-docker.pkg.dev/${var.cicd_project_id}/ar-sandbox-platform/run-sandbox-provisioner:latest"
  automation_image_uri  = "${var.region}-docker.pkg.dev/${var.cicd_project_id}/ar-sandbox-platform/sandbox-automation-runner:latest"
  provisioner_source_hash = sha256(join("", [
    filesha256("${path.module}/../../cloudrun-provisioner/Dockerfile"),
    filesha256("${path.module}/../../cloudrun-provisioner/main.py"),
    filesha256("${path.module}/../../cloudrun-provisioner/requirements.txt"),
    filesha256("${path.module}/../../cloudrun-provisioner/sandbox-request.schema.json"),
  ]))
  automation_source_hash = sha256(join("", [
    filesha256("${path.module}/../../automation-runner/Dockerfile"),
    filesha256("${path.module}/../../automation-runner/requirements.txt"),
  ]))
}

resource "terraform_data" "automation_image" {
  triggers_replace = [local.automation_image_uri, local.automation_source_hash]
  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit "${path.module}/../../automation-runner" \
        --project="${var.cicd_project_id}" \
        --region="${var.region}" \
        --tag="${local.automation_image_uri}" \
        --quiet
    EOT
  }
  depends_on = [google_artifact_registry_repository.platform]
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
  triggers_replace = [local.provisioner_image_uri, local.provisioner_source_hash]
  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit "${path.module}/../../cloudrun-provisioner" \
        --project="${var.cicd_project_id}" \
        --region="${var.region}" \
        --tag="${local.provisioner_image_uri}" \
        --quiet
    EOT
  }
  depends_on = [google_artifact_registry_repository.platform]
}

resource "google_cloudbuild_trigger" "sandbox_orchestrate" {
  project         = var.cicd_project_id
  location        = var.region
  name            = "trigger-sandbox-orchestrate"
  description     = "Run approved sandbox request through Infrastructure Manager"
  service_account = google_service_account.automation["orchestrator"].id
  filename        = "cloudbuild/sandbox-orchestrate.yaml"

  github {
    owner = var.github_owner
    name  = var.github_repository
    push { branch = "^manual-only$" }
  }

  substitutions = {
    _ACTION                  = "create"
    _REQUEST_ID              = "REPLACE_REQUEST_ID"
    _REQUEST_URI             = "gs://REPLACE/approved-request.json"
    _BUNDLE_PREFIX           = "gs://REPLACE/requests/REPLACE_REQUEST_ID/REPLACE_SHA"
    _TASK_NAME               = "sbx01"
    _GKE_NAMESPACE           = "sbx01"
    _WORKER_POOL             = google_cloudbuild_worker_pool.terraform.id
    _WORKSPACE_ADMIN_SUBJECT = var.workspace_admin_subject
    _PROJECT_FACTORY_SA      = google_service_account.automation["project_factory"].email
    _NETWORK_ADMIN_SA        = google_service_account.automation["network_admin"].email
    _PROJECT_IAM_SA          = google_service_account.automation["project_iam"].email
    _DATA_ADMIN_SA           = google_service_account.automation["data_admin"].email
    _GKE_ADMIN_SA            = google_service_account.automation["gke_admin"].email
    _LB_ADMIN_SA             = google_service_account.automation["lb_admin"].email
    _JUPYTER_CHART            = var.jupyter_chart_uri
    _JUPYTER_CHART_VERSION    = var.jupyter_chart_version
    _AUTOMATION_IMAGE         = local.automation_image_uri
  }

  depends_on = [terraform_data.automation_image]
}
