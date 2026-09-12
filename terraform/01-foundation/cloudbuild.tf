resource "google_cloudbuild_worker_pool" "terraform" {
  project  = var.cicd_project_id
  name     = "pool-sandbox-terraform"
  location = var.region

  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-4"
    no_external_ip = true
  }

  network_config {
    peered_network = data.google_compute_network.shared.id
  }

  depends_on = [google_service_networking_connection.private_service_access]
}

# GitHub App 승인이 필요한 Cloud Build v2 connection은 최초 1회 Console에서
# 생성한 뒤 Terraform import를 권장합니다. 인증 토큰을 코드에 저장하지 않습니다.

