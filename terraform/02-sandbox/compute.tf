resource "google_service_account" "vm" {
  project      = var.resource_project_id
  account_id   = "sa-vm-${var.task_name}"
  display_name = "VM ${var.task_name}"
}
resource "google_compute_instance" "task" {
  project      = var.resource_project_id
  name         = "vm-${var.task_name}-01"
  zone         = var.zone
  machine_type = var.vm_machine_type
  tags = ["sandbox", var.task_name]
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = var.vm_boot_disk_gb
      type  = "pd-balanced"
    }
  }
  network_interface {
    subnetwork         = google_compute_subnetwork.task.self_link
    subnetwork_project = var.shared_vpc_host_project_id
  }
  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }
  deletion_protection = true
  depends_on = [google_compute_subnetwork_iam_member.vm_network_user]
}
