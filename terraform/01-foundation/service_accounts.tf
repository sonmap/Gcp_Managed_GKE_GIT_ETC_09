locals {
  automation_service_accounts = {
    portal          = { account_id = "sa-sandbox-portal", display_name = "Approved sandbox portal caller" }
    api             = { account_id = "sa-sandbox-api", display_name = "Approved sandbox request API" }
    # Preserve the existing account_id so the foundation state migration does
    # not replace the already-created execution identity.
    orchestrator    = { account_id = "sa-sandbox-terraform", display_name = "Sandbox Cloud Build orchestrator" }
    project_factory = { account_id = "sa-im-project-factory", display_name = "Infra Manager project factory" }
    network_admin   = { account_id = "sa-im-network-admin", display_name = "Infra Manager shared network administrator" }
    project_iam     = { account_id = "sa-im-project-iam", display_name = "Infra Manager project IAM administrator" }
    data_admin      = { account_id = "sa-im-data-admin", display_name = "Infra Manager sandbox data administrator" }
    gke_admin       = { account_id = "sa-im-gke-admin", display_name = "Infra Manager GKE administrator" }
    lb_admin        = { account_id = "sa-im-lb-admin", display_name = "Infra Manager load balancer administrator" }
    group_admin     = { account_id = "sa-sandbox-group-admin", display_name = "Google Workspace group administrator" }
  }
}

# The VM execution identity needs these two bootstrap roles to create the
# request/bundle buckets and Secret Manager secrets in the CI/CD project.
resource "google_project_iam_member" "foundation_executor_bootstrap_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/secretmanager.admin",
  ])

  project = var.cicd_project_id
  role    = each.value
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

# The VM execution identity creates the Cloud Build trigger during foundation.
resource "google_project_iam_member" "foundation_executor_cloud_build_editor" {
  project = var.cicd_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_project_iam_member" "orchestrator_worker_pool_user" {
  project = var.cicd_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_project_iam_member" "deployment_account_cicd_roles" {
  for_each = {
    for pair in setproduct(
      toset(["project_factory", "network_admin", "project_iam", "data_admin", "gke_admin", "lb_admin"]),
      toset(["roles/cloudbuild.workerPoolUser", "roles/logging.logWriter"])
    ) : "${pair[0]}:${pair[1]}" => { account = pair[0], role = pair[1] }
  }

  project = var.cicd_project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.automation[each.value.account].email}"
}

resource "google_service_account" "automation" {
  for_each     = local.automation_service_accounts
  project      = var.cicd_project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

resource "google_project_iam_member" "api_build_editor" {
  project = var.cicd_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.automation["api"].email}"
}

resource "google_service_account_iam_member" "api_uses_orchestrator" {
  service_account_id = google_service_account.automation["orchestrator"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.automation["api"].email}"
}

# Allows the controlled VM execution identity to obtain an ID token as the
# portal caller for the initial approved-JSON end-to-end test.
resource "google_service_account_iam_member" "foundation_executor_impersonates_portal" {
  service_account_id = google_service_account.automation["portal"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_service_account_iam_member" "foundation_executor_uses_runtime_accounts" {
  for_each = toset(["api", "orchestrator"])

  service_account_id = google_service_account.automation[each.value].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_project_iam_member" "orchestrator_roles" {
  for_each = toset([
    "roles/config.admin",
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
  ])
  project = var.cicd_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_service_account_iam_member" "orchestrator_uses_deployment_accounts" {
  for_each = toset(["project_factory", "network_admin", "project_iam", "data_admin", "gke_admin", "lb_admin"])

  service_account_id = google_service_account.automation[each.value].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

resource "google_service_account_iam_member" "orchestrator_impersonates_runtime_accounts" {
  for_each = toset(["gke_admin", "lb_admin"])

  service_account_id = google_service_account.automation[each.value].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

# Folder, Billing, Shared VPC and target-project roles are deliberately not
# granted here. Central, network and project IAM administrators grant those
# roles to the corresponding deployment service accounts before automation.
