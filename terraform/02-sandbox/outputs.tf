output "task_name" { value = var.task_name }
output "namespace" { value = kubernetes_namespace_v1.task.metadata[0].name }
output "group_email" { value = var.group_email }
output "subnet" { value = google_compute_subnetwork.task.name }
output "subnet_cidr" { value = google_compute_subnetwork.task.ip_cidr_range }
output "dataset" { value = google_bigquery_dataset.task.dataset_id }
output "bucket" { value = google_storage_bucket.task.name }
output "vm_name" { value = google_compute_instance.task.name }
output "vm_internal_ip" { value = google_compute_instance.task.network_interface[0].network_ip }
output "jupyter_gsa" { value = google_service_account.jupyter.email }

