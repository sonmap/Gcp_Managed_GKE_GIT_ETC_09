output "existing_sandbox_project_id" {
  value = var.existing_sandbox_project_id
}

output "project_factory_roles" {
  value = sort(tolist(local.project_factory_roles))
}
