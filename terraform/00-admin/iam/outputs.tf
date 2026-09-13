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
