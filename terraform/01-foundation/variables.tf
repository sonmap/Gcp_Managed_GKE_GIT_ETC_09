variable "cicd_project_id" { type = string }
variable "shared_vpc_host_project_id" { type = string }
variable "gke_project_id" { type = string }
variable "region" {
  type    = string
  default = "asia-northeast3"
}
variable "shared_vpc_network_self_link" { type = string }
variable "gke_subnet_self_link" { type = string }
variable "cloudrun_subnet_self_link" { type = string }
variable "gke_pod_range_name" { type = string }
variable "gke_pod_cidr" { type = string }
variable "gke_cluster_name" {
  type    = string
  default = "gke-sbx-main-an3"
}
variable "state_bucket_name" { type = string }
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
  default = "feat/two-stage-sandbox-platform"
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

variable "existing_sandbox_project_ids" {
  description = "Approved existing projects prepared for sandbox data resources"
  type        = set(string)
  default     = ["pjt-net-hub-base"]
}
