output "gke_cluster_name" {
  value = google_container_cluster.sandbox.name
}

output "cicd_test_gke_cluster_name" {
  value = google_container_cluster.cicd_test.name
}

output "worker_pool_id" {
  value = google_cloudbuild_worker_pool.terraform.id
}

output "sandbox_build_trigger_id" {
  value = google_cloudbuild_trigger.sandbox_orchestrate.trigger_id
}

output "provisioner_uri" {
  value = google_cloud_run_v2_service.provisioner.uri
}

output "request_bucket" {
  value = google_storage_bucket.requests.name
}

output "bundle_bucket" {
  value = google_storage_bucket.bundles.name
}

output "automation_image" {
  value = local.automation_image_uri
}

output "automation_service_accounts" {
  value = { for key, account in google_service_account.automation : key => account.email }
}
