output "network_self_link" {
  value = data.google_compute_network.shared.self_link
}

output "internal_alb_frontend_subnet_self_link" {
  value = google_compute_subnetwork.internal_alb_frontend.self_link
}

output "jupyter_internal_alb_ip" {
  value = google_compute_address.jupyter_internal_alb.address
}

output "internal_alb_proxy_subnet_self_link" {
  value = google_compute_subnetwork.internal_alb_proxy_only.self_link
}

output "gke_main_subnet_self_link" {
  value = google_compute_subnetwork.gke_main.self_link
}

output "gke_main_pod_range_name" {
  value = var.gke_main_pod_range_name
}

output "gke_test_subnet_self_link" {
  value = google_compute_subnetwork.gke_test.self_link
}

output "gke_test_pod_range_name" {
  value = var.gke_test_pod_range_name
}

output "cloudrun_subnet_self_link" {
  value = google_compute_subnetwork.cloudrun_egress.self_link
}

output "cloudbuild_private_pool_ip_range" {
  value = var.cloudbuild_psa_cidr
}

output "task_subnet_name" {
  value = google_compute_subnetwork.task.name
}
