locals {
  project_members = {
    group_bq_job = {
      role   = "roles/bigquery.jobUser"
      member = "group:${var.group_email}"
    }
    jupyter_bq_job = {
      role   = "roles/bigquery.jobUser"
      member = "serviceAccount:${google_service_account.jupyter.email}"
    }
  }
}

resource "google_project_iam_member" "task" {
  for_each = local.project_members
  project  = var.resource_project_id
  role     = each.value.role
  member   = each.value.member
}
