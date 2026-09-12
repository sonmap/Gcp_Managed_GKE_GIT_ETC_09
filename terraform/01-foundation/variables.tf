variable "cicd_project_id" { type = string }
variable "shared_vpc_host_project_id" { type = string }
variable "gke_project_id" { type = string }
variable "resource_project_id" { type = string }
variable "region" {
  type = string
  default = "asia-northeast3"
}
variable "zone" {
  type = string
  default = "asia-northeast3-a"
}
variable "network_name" {
  type = string
  default = "vpc-d-shared-base"
}
variable "gke_subnet_name" { type = string }
variable "gke_pod_range_name" { type = string }
variable "gke_service_ipv4_cidr" {
  type = string
  default = "34.118.224.0/20"
}
variable "gke_cluster_name" {
  type = string
  default = "gke-sbx-main-an3"
}
variable "cloudrun_subnet_cidr" { type = string }
variable "cloudbuild_psa_cidr" { type = string }
variable "state_bucket_name" { type = string }
variable "github_owner" {
  type = string
  default = "sonmap"
}
variable "github_repository" {
  type = string
  default = "Gcp_Managed_GKE_GIT_ETC_09"
}
variable "provisioner_image" {
  type = string
  default = ""
}
variable "provisioner_ingress" {
  type = string
  default = "internal-and-cloud-load-balancing"
}
variable "sandbox_build_trigger_id" {
  type = string
  default = ""
}
variable "external_lb_domain" {
  type = string
  default = ""
}
variable "jupyter_neg_self_links" {
  type = list(string)
  default = []
}
variable "iap_oauth2_client_id" {
  type = string
  default = ""
}
variable "iap_oauth2_client_secret" {
  type = string
  default = ""
  sensitive = true
}
variable "gke_pod_cidr" { type = string }
