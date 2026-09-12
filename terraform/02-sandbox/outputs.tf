output "task_name" { value = var.task_name }
output "namespace" { value = kubernetes_namespace_v1.task.metadata[0].name }
output "group_email" { value = var.group_email }
output "dataset" { value = google_bigquery_dataset.task.dataset_id }
output "bucket" { value = google_storage_bucket.task.name }
output "jupyter_gsa" { value = google_service_account.jupyter.email }
output "jupyter_neg_name" { value = var.enable_jupyterhub ? local.jupyter_neg_name : null }
output "jupyter_oauth_callback_url" { value = var.enable_jupyterhub ? "https://${var.jupyter_domain}/hub/oauth_callback" : null }
