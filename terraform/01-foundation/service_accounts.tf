locals {
  automation_service_accounts = {
    portal          = { account_id = "sa-sandbox-portal", display_name = "Approved sandbox portal caller" }
    api             = { account_id = "sa-sandbox-api", display_name = "Approved sandbox request API" }
    workflow        = { account_id = "sa-sandbox-workflow", display_name = "Sandbox provisioning workflow runtime" }
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
    "roles/logging.viewer",
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

# Every Infrastructure Manager deployment identity needs roles/config.agent in
# the CI/CD project. This also permits access to Infra Manager's regional
# blueprint-config bucket.
resource "google_project_iam_member" "deployment_account_cicd_roles" {
  for_each = {
    for pair in setproduct(
      toset(["project_factory", "network_admin", "project_iam", "data_admin", "gke_admin", "lb_admin"]),
      toset([
        "roles/cloudbuild.workerPoolUser",
        "roles/config.agent",
        "roles/logging.logWriter",
      ])
    ) : "${pair[0]}:${pair[1]}" => { account = pair[0], role = pair[1] }
  }

  project = var.cicd_project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.automation[each.value.account].email}"
}

# Existing project_factory, network_admin, project_iam, and data_admin accounts
# are adopted declaratively by the import blocks in migrations.tf.
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

resource "google_project_iam_member" "api_worker_pool_user" {
  project = var.cicd_project_id
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${google_service_account.automation["api"].email}"
}

resource "google_service_account_iam_member" "api_uses_orchestrator" {
  service_account_id = google_service_account.automation["orchestrator"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.automation["api"].email}"
}

# Allows the controlled VM execution identity and workspace administrator to
# obtain an ID token as the portal caller for end-to-end tests.
resource "google_service_account_iam_member" "workspace_admin_impersonates_portal_for_test" {
  service_account_id = google_service_account.automation["portal"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.workspace_admin_subject}"
}

resource "google_service_account_iam_member" "foundation_executor_impersonates_portal" {
  service_account_id = google_service_account.automation["portal"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.foundation_executor_service_account}"
}

resource "google_service_account_iam_member" "foundation_executor_uses_runtime_accounts" {
  for_each = toset(["api", "orchestrator", "workflow"])

  service_account_id = google_service_account.automation[each.value].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.foundation_executor_service_account}"
}

# Workflow can invoke Cloud Run, submit Cloud Builds to the private pool, and
# access workloads in the CI/CD project's Python test GKE cluster.
resource "google_project_iam_member" "workflow_cicd_roles" {
  for_each = toset([
    "roles/cloudbuild.builds.editor",
    "roles/cloudbuild.workerPoolUser",
    "roles/container.developer",
    "roles/logging.logWriter",
  ])

  project = var.cicd_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.automation["workflow"].email}"
}

resource "google_project_iam_member" "portal_invokes_workflow" {
  project = var.cicd_project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.automation["portal"].email}"
}

resource "google_project_iam_member" "orchestrator_roles" {
  for_each = toset([
    "roles/config.admin",
    "roles/cloudbuild.builds.editor",
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/secretmanager.secretAccessor",
    "roles/storage.objectViewer",
  ])
  project = var.cicd_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
}

# Cloud Build requires iam.serviceAccounts.actAs when the orchestrator
# submits a nested build using its own execution identity.
resource "google_service_account_iam_member" "orchestrator_uses_self" {
  service_account_id = google_service_account.automation["orchestrator"].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.automation["orchestrator"].email}"
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

# Cross-project IAM is managed by terraform/00-admin/iam and is executed
# with a top-level administrator identity.
