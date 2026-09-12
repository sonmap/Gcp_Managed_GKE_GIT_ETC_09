output "gke_cluster_name" { value = google_container_cluster.sandbox.name }
output "worker_pool_id" { value = google_cloudbuild_worker_pool.terraform.id }
output "sandbox_build_trigger_id" { value = google_cloudbuild_trigger.sandbox_dispatch.trigger_id }
output "terraform_service_account" { value = google_service_account.terraform.email }
output "state_bucket_name" { value = google_storage_bucket.terraform_state.name }
output "provisioner_image" { value = local.provisioner_image_uri }
output "provisioner_uri" { value = google_cloud_run_v2_service.provisioner.uri }
output "jupyter_oauth_secret_ids" { value = { for key, secret in google_secret_manager_secret.jupyter_oauth : key => secret.secret_id } }
output "jupyter_external_ip" { value = try(google_compute_global_address.jupyter[0].address, null) }
