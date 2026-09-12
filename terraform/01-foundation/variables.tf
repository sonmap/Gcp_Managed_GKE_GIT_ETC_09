variable "cicd_project_id" { type = string }
variable "shared_vpc_host_project_id" { type = string }
variable "gke_project_id" { type = string }
variable "resource_project_id" { type = string }

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "zone" {
  type    = string
  default = "asia-northeast3-a"
}

variable "network_name" {
  type    = string
  default = "vpc-d-shared-base"
}

variable "shared_vpc_network_self_link" { type = string }
variable "gke_subnet_self_link" { type = string }
variable "cloudrun_subnet_self_link" { type = string }
variable "gke_pod_range_name" { type = string }

variable "gke_service_ipv4_cidr" {
  type    = string
  default = "34.118.224.0/20"
}

variable "gke_cluster_name" {
  type    = string
  default = "gke-sbx-main-an3"
}

variable "state_bucket_name" { type = string }

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

variable "provisioner_ingress" {
  type    = string
  default = "all"
}

variable "provisioner_invoker_group_email" {
  type    = string
  default = "pgrp-gcp-dev-sbx01@sonmap.net"
}

variable "foundation_executor_service_account" {
  type    = string
  default = "40744085720-compute@developer.gserviceaccount.com"
}

variable "default_task_name" {
  type    = string
  default = "sbx01"
}

variable "default_group_email" {
  type    = string
  default = "pgrp-gcp-dev-sbx01@sonmap.net"
}

variable "jupyter_domain" {
  type    = string
  default = "jupyter-sbx01.sonmap.net"
}

variable "external_lb_domain" {
  type    = string
  default = ""
}

variable "jupyter_neg_self_links" {
  type    = list(string)
  default = []
}

variable "iap_oauth2_client_id" {
  type    = string
  default = ""
}

variable "iap_oauth2_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gke_pod_cidr" { type = string }
