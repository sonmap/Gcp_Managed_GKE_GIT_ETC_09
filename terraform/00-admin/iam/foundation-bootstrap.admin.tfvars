# Apply this Git-managed profile only with an IAM administrator identity.
# It grants the minimum bootstrap access required to finish Foundation.

enable_iam_changes = true
iam_scope          = "full"
allow_full_scope   = true

manage_foundation_executor_iam               = true
manage_cloud_run_shared_vpc_iam              = true
manage_project_factory_existing_project_iam = false
manage_network_admin_host_iam                = false
manage_network_admin_xpn_iam                 = false
manage_workflow_gke_iam                      = false
manage_workflow_existing_project_iam         = false
manage_workflow_shared_vpc_iam               = false

cicd_project_id            = "prj-b-cicd-local-236d"
shared_vpc_host_project_id = "pjt-d-shared-base"
gke_project_id             = "pjt-d-host01"
region                     = "asia-northeast3"

foundation_executor_service_account = "40744085720-compute@developer.gserviceaccount.com"

gke_main_subnet_name = "subnet-dev-sbx-gke-01-an3-main"
gke_test_subnet_name = "subnet-dev-cicd-gke-01-an3-test"
cloudrun_subnet_name = "subnet-dev-cicd-run-01-an3-egress"
cicd_project_number  = "587273205772"
