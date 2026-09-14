resource "google_cloud_run_v2_service_iam_member" "workflow_invokes_provisioner" {
  project  = var.cicd_project_id
  location = var.region
  name     = google_cloud_run_v2_service.provisioner.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.automation["workflow"].email}"
}

resource "google_workflows_workflow" "sandbox_provision" {
  project         = var.cicd_project_id
  region          = var.region
  name            = "workflow-dev-sbx-01-an3-provision"
  description     = "Validate and submit approved sandbox provisioning requests"
  service_account = google_service_account.automation["workflow"].email

  call_log_level      = "LOG_ERRORS_ONLY"
  deletion_protection = false

  source_contents = <<-YAML
    main:
      params: [args]
      steps:
        - invoke_provisioner:
            call: http.post
            args:
              url: "${google_cloud_run_v2_service.provisioner.uri}/provision"
              auth:
                type: OIDC
                audience: "${google_cloud_run_v2_service.provisioner.uri}"
              headers:
                Content-Type: "application/json"
              body: $${args}
            result: provision_response
        - return_result:
            return: $${provision_response.body}
  YAML

  depends_on = [
    google_project_service.cicd["workflows.googleapis.com"],
    google_project_iam_member.workflow_cicd_roles,
    google_service_account_iam_member.foundation_executor_uses_runtime_accounts["workflow"],
    google_cloud_run_v2_service_iam_member.workflow_invokes_provisioner,
  ]
}
