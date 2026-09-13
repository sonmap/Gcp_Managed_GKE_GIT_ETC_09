output "network_self_link" { value = data.google_compute_network.shared.self_link }
output "gke_subnet_self_link" { value = data.google_compute_subnetwork.gke.self_link }
output "cloudrun_subnet_self_link" { value = google_compute_subnetwork.cloudrun_egress.self_link }
output "task_subnet_name" { value = google_compute_subnetwork.task.name }
