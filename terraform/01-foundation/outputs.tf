output "gke_cluster_name" { value = google_container_cluster.sandbox.name }
output "worker_pool_id" { value = google_cloudbuild_worker_pool.terraform.id }
output "terraform_service_account" { value = google_service_account.terraform.email }
output "state_bucket_name" { value = google_storage_bucket.terraform_state.name }
output "provisioner_uri" { value = try(google_cloud_run_v2_service.provisioner[0].uri, null) }
output "jupyter_external_ip" { value = try(google_compute_global_address.jupyter[0].address, null) }
