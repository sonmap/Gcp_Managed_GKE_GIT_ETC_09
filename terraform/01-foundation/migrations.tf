moved {
  from = google_service_account.provisioner
  to   = google_service_account.automation["api"]
}

moved {
  from = google_service_account.terraform
  to   = google_service_account.automation["orchestrator"]
}

moved {
  from = google_project_iam_member.provisioner_builds_editor
  to   = google_project_iam_member.api_build_editor
}

moved {
  from = google_project_iam_member.terraform_cicd["roles/logging.logWriter"]
  to   = google_project_iam_member.orchestrator_roles["roles/logging.logWriter"]
}

moved {
  from = google_project_iam_member.terraform_cicd["roles/cloudbuild.workerPoolUser"]
  to   = google_project_iam_member.orchestrator_worker_pool_user
}

moved {
  from = google_service_account_iam_member.provisioner_uses_terraform
  to   = google_service_account_iam_member.api_uses_orchestrator
}

moved {
  from = google_service_account_iam_member.foundation_executor_uses_terraform
  to   = google_service_account_iam_member.foundation_executor_uses_runtime_accounts["orchestrator"]
}


# Existing Infrastructure Manager service accounts were created before this
# Foundation state. Declarative imports keep Git configuration and state
# adoption in the same Terraform workflow.
import {
  to = google_service_account.automation["project_factory"]
  id = "projects/prj-b-cicd-local-236d/serviceAccounts/sa-im-project-factory@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

import {
  to = google_service_account.automation["network_admin"]
  id = "projects/prj-b-cicd-local-236d/serviceAccounts/sa-im-network-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

import {
  to = google_service_account.automation["project_iam"]
  id = "projects/prj-b-cicd-local-236d/serviceAccounts/sa-im-project-iam@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

import {
  to = google_service_account.automation["data_admin"]
  id = "projects/prj-b-cicd-local-236d/serviceAccounts/sa-im-data-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}


# The first Autopilot creation reached the node-pool read phase before the
# executor had compute.instanceGroupManagers.list. Adopt the cluster if the
# provider could not persist it in state; this is a no-op when already managed.
import {
  to = google_container_cluster.cicd_test[0]
  id = "projects/prj-b-cicd-local-236d/locations/asia-northeast3/clusters/gke-dev-cicd-01-an3"
}
