# Cost-stop profile: removes only the runtime resources that are already
# managed in the Foundation Terraform state. Apply with -var-file, never rename
# this file to *.auto.tfvars.
#
# Preserved intentionally:
# - Terraform state bucket and request/bundle buckets
# - automation service accounts and IAM bootstrap
# - Artifact Registry, Cloud Build trigger, and private worker pool
# - all pre-existing pjt-net-hub-base resources

enable_gke_cluster_changes      = false
enable_gke_main_cluster_changes = false
enable_gke_test_cluster_changes = false
gke_deletion_protection         = false

enable_cloud_run_service_changes = false
enable_cloud_run_shared_vpc_iam  = false
