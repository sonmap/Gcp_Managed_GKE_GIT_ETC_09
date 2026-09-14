# Apply with an IAM administrator of the approved existing sandbox project.
# Use the separate backend prefix admin/sandbox-existing-project-iam.

enable_iam_changes = true
iam_scope          = "full"
allow_full_scope   = true

manage_foundation_executor_iam                   = false
manage_foundation_executor_cicd_iam              = false
manage_foundation_executor_gke_project_iam       = false
manage_foundation_executor_shared_vpc_iam        = false
manage_cloud_run_shared_vpc_iam                  = false
manage_project_factory_existing_project_iam     = true
manage_network_admin_host_iam                    = false
manage_network_admin_xpn_iam                     = false
manage_workflow_gke_iam                          = false
manage_workflow_existing_project_iam             = false
manage_workflow_shared_vpc_iam                   = false

existing_sandbox_project_id     = "pjt-net-hub-base"
project_factory_service_account = "sa-im-project-factory@prj-b-cicd-local-236d.iam.gserviceaccount.com"
