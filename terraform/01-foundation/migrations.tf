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
