variable "cicd_project_id" {
  type    = string
  default = "prj-b-cicd-local-236d"
}

variable "shared_vpc_host_project_id" {
  type    = string
  default = "pjt-d-shared-base"
}

variable "gke_project_id" {
  type    = string
  default = "pjt-d-host01"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "shared_vpc_network_self_link" {
  type    = string
  default = "projects/pjt-d-shared-base/global/networks/vpc-d-shared-base"
}

variable "gke_main_subnet_self_link" {
  type    = string
  default = "projects/pjt-d-shared-base/regions/asia-northeast3/subnetworks/subnet-dev-sbx-gke-01-an3-main"
}

variable "gke_main_pod_range_name" {
  type    = string
  default = "pods-dev-sbx-gke-01-an3-main"
}

variable "gke_main_pod_cidr" {
  type    = string
  default = "10.240.0.0/20"
}

variable "gke_main_control_plane_cidr" {
  type    = string
  default = "10.253.0.0/28"
}

variable "gke_test_subnet_self_link" {
  type    = string
  default = "projects/pjt-d-shared-base/regions/asia-northeast3/subnetworks/subnet-dev-cicd-gke-01-an3-test"
}

variable "gke_test_pod_range_name" {
  type    = string
  default = "pods-dev-cicd-gke-01-an3-test"
}

variable "gke_test_pod_cidr" {
  type    = string
  default = "10.240.32.0/22"
}

variable "gke_test_control_plane_cidr" {
  type    = string
  default = "10.253.0.16/28"
}

variable "cicd_test_gke_cluster_name" {
  type    = string
  default = "gke-dev-cicd-01-an3"
}

variable "cloudrun_subnet_self_link" {
  type        = string
  default     = null
  nullable    = true
  description = "Deprecated compatibility input. The canonical Foundation subnet name is used unless network design is changed in source."
}

variable "cloudrun_subnet_name" {
  type    = string
  default = "subnet-dev-cicd-run-01-an3-egress"
}

variable "enable_cloud_run_service_changes" {
  type        = bool
  default     = false
  description = "Create Cloud Run and dependent Workflow resources. Enable only after Shared VPC subnet IAM is granted."
}

variable "enable_cloud_run_shared_vpc_iam" {
  type        = bool
  default     = false
  description = "Manage Cloud Run service-agent Network User on the host subnet. Enable only for a caller with Shared VPC subnet IAM permission."
}

variable "enable_gke_cluster_changes" {
  type        = bool
  default     = false
  description = "Create Foundation GKE clusters. Enable only after Shared VPC Network User and container.clusters.create permissions are confirmed."
}

variable "cloudbuild_private_pool_ip_range" {
  type    = string
  default = "10.250.0.0/24"
}

variable "gke_cluster_name" {
  type    = string
  default = "gke-sbx-main-an3"
}

# Deprecated ETC_08 input names are declared temporarily so an older local
# terraform.tfvars does not produce undeclared-variable warnings. Foundation
# uses the explicit gke_main_* and gke_test_* values above.
variable "gke_subnet_self_link" {
  type        = string
  default     = null
  nullable    = true
  description = "Deprecated compatibility input. Use gke_main_subnet_self_link."
}

variable "gke_pod_range_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Deprecated compatibility input. Use gke_main_pod_range_name."
}

variable "gke_pod_cidr" {
  type        = string
  default     = null
  nullable    = true
  description = "Deprecated compatibility input. Use gke_main_pod_cidr."
}

variable "gke_control_plane_cidr" {
  type        = string
  default     = null
  nullable    = true
  description = "Deprecated compatibility input. Use gke_main_control_plane_cidr."
}

variable "state_bucket_name" {
  type    = string
  default = "tfstate-sbx-cicd-236d-40744085720"
}

variable "request_bucket_name" {
  type    = string
  default = ""
}

variable "bundle_bucket_name" {
  type    = string
  default = ""
}

variable "github_owner" {
  type    = string
  default = "sonmap"
}

variable "github_repository" {
  type    = string
  default = "Gcp_Managed_GKE_GIT_ETC_09"
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "foundation_executor_service_account" {
  type    = string
  default = "40744085720-compute@developer.gserviceaccount.com"
}

variable "provisioner_ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_ALL"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.provisioner_ingress)
    error_message = "provisioner_ingress must use a Cloud Run v2 ingress enum value."
  }
}

variable "workspace_admin_subject" {
  type    = string
  default = "admin@sonmap.net"
}

variable "jupyter_chart_uri" {
  type    = string
  default = "oci://asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/jupyterhub"
}

variable "jupyter_chart_version" {
  type    = string
  default = "4.2.0"
}
