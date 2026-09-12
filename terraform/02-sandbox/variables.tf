variable "task_name" {
  type    = string
  default = "sbx01"
}
variable "resource_project_id" {
  type    = string
  default = "pjt-c-admin"
}
variable "gke_project_id" {
  type    = string
  default = "pjt-d-host01"
}
variable "shared_vpc_host_project_id" {
  type    = string
  default = "pjt-d-shared-base"
}
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
variable "subnet_cidr" { type = string }
variable "task_subnet_name" {
  type    = string
  default = "subnet-sbx01-an3"
}
variable "gke_cluster_name" {
  type    = string
  default = "gke-sbx-main-an3"
}
variable "group_email" {
  type    = string
  default = "pgrp-gcp-dev-sbx01@sonmap.net"
}
variable "users" {
  type    = set(string)
  default = ["user01@sonmap.net", "user02@sonmap.net", "user03@sonmap.net"]
}
variable "vm_machine_type" {
  type    = string
  default = "e2-standard-2"
}
variable "vm_boot_disk_gb" {
  type    = number
  default = 50
}

variable "enable_jupyterhub" {
  description = "Deploy JupyterHub and its standalone NEG in the sandbox namespace."
  type        = bool
  default     = false
}

variable "jupyter_domain" {
  description = "Public DNS name used by the external HTTPS load balancer."
  type        = string
  default     = ""
}

variable "jupyter_oauth_client_id" {
  description = "Google OAuth web client ID for JupyterHub."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jupyter_oauth_client_secret" {
  description = "Google OAuth web client secret for JupyterHub."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jupyterhub_chart_version" {
  description = "Zero to JupyterHub Helm chart version."
  type        = string
  default     = "4.2.0"
}

variable "jupyter_notebook_storage" {
  description = "Persistent home storage allocated to each Jupyter user."
  type        = string
  default     = "40Gi"
}
