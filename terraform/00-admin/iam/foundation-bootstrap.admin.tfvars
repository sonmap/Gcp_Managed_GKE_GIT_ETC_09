# CI/CD-project-only cumulative profile.
# Uses the existing admin/shared-vpc-iam state because the successful
# prj-b-cicd-local-236d binding is already recorded there.

enable_iam_changes = true
iam_scope          = "full"
allow_full_scope   = true

manage_foundation_executor_iam                   = false
manage_foundation_executor_cicd_iam              = true
manage_foundation_executor_gke_project_iam       = false
manage_foundation_executor_shared_vpc_iam        = false
manage_cloud_run_shared_vpc_iam                  = false
manage_project_factory_existing_project_iam     = false
manage_network_admin_host_iam                    = false
manage_network_admin_xpn_iam                     = false
manage_workflow_gke_iam                          = false
manage_workflow_existing_project_iam             = false
manage_workflow_shared_vpc_iam                   = false

cicd_project_id = "prj-b-cicd-local-236d"
foundation_executor_service_account = "40744085720-compute@developer.gserviceaccount.com"
