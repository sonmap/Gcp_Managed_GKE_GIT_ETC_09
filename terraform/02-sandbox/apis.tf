locals {
  required_apis = toset(["bigquery.googleapis.com", "compute.googleapis.com", "iam.googleapis.com", "storage.googleapis.com"])
}
resource "google_project_service" "sandbox" {
  for_each           = local.required_apis
  project            = var.resource_project_id
  service            = each.value
  disable_on_destroy = false
}

