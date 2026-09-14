# Apply with an IAM administrator of pjt-d-shared-base.
# Use only with the separate backend prefix admin/sandbox-network-host-iam.

enable_iam_changes = true
iam_scope          = "network-host-only"
allow_full_scope   = false

manage_foundation_executor_iam                   = false
manage_foundation_executor_cicd_iam              = false
manage_foundation_executor_gke_project_iam       = false
manage_foundation_executor_shared_vpc_iam        = false
manage_cloud_run_shared_vpc_iam                  = false
manage_project_factory_existing_project_iam     = false
manage_network_admin_host_iam                    = true
manage_network_admin_xpn_iam                     = false
manage_workflow_gke_iam                          = false
manage_workflow_existing_project_iam             = false
manage_workflow_shared_vpc_iam                   = false

shared_vpc_host_project_id = "pjt-d-shared-base"
network_admin_service_account = "sa-im-network-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
