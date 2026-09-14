# Apply only with an IAM administrator of folder 154455658682.
# Use the separate backend prefix admin/sandbox-network-xpn-iam.

enable_iam_changes = true
iam_scope          = "full"
allow_full_scope   = true

manage_foundation_executor_iam                   = false
manage_foundation_executor_cicd_iam              = false
manage_foundation_executor_gke_project_iam       = false
manage_foundation_executor_shared_vpc_iam        = false
manage_cloud_run_shared_vpc_iam                  = false
manage_project_factory_existing_project_iam     = false
manage_network_admin_host_iam                    = false
manage_network_admin_xpn_iam                     = true
manage_workflow_gke_iam                          = false
manage_workflow_existing_project_iam             = false
manage_workflow_shared_vpc_iam                   = false

shared_vpc_admin_folder_id = "154455658682"
network_admin_service_account = "sa-im-network-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
