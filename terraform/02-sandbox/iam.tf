locals {
  project_members = {
    group_viewer = { role = "roles/viewer", member = "group:${var.group_email}" }
    group_bq_job = { role = "roles/bigquery.jobUser", member = "group:${var.group_email}" }
    jupyter_bq_job = { role = "roles/bigquery.jobUser", member = "serviceAccount:${google_service_account.jupyter.email}" }
    vm_log_writer = { role = "roles/logging.logWriter", member = "serviceAccount:${google_service_account.vm.email}" }
    vm_monitor_writer = { role = "roles/monitoring.metricWriter", member = "serviceAccount:${google_service_account.vm.email}" }
  }
}
resource "google_project_iam_member" "task" {
  for_each = local.project_members
  project  = var.resource_project_id
  role     = each.value.role
  member   = each.value.member
}
