output "existing_sandbox_project_id" {
  value = var.existing_sandbox_project_id
}

output "project_factory_roles" {
  value = sort(tolist(local.project_factory_roles))
}

output "shared_vpc_admin_folder_id" {
  value = var.shared_vpc_admin_folder_id
}

output "network_admin_roles" {
  value = concat(
    sort(tolist(local.network_admin_host_roles)),
    ["roles/compute.xpnAdmin"],
  )
}

output "workflow_service_account" {
  value = var.workflow_service_account
}

output "workflow_cross_project_roles" {
  value = {
    gke_project      = sort(tolist(local.workflow_gke_project_roles))
    existing_project = sort(tolist(local.workflow_existing_project_roles))
    shared_vpc_host  = sort(tolist(local.workflow_shared_vpc_roles))
  }
}
