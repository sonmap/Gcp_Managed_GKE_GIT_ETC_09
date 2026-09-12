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

variable "region" {
  type    = string
  default = "asia-northeast3"
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

variable "enable_jupyterhub" {
  description = "Deploy JupyterHub and its standalone NEG in the sandbox namespace."
  type        = bool
  default     = true
}

variable "jupyter_domain" {
  description = "Public DNS name used by the external HTTPS load balancer."
  type        = string
  default     = "jupyter-sbx01.sonmap.net"
}

variable "jupyter_oauth_client_id" {
  description = "Google OAuth web client ID for JupyterHub."
  type        = string
  sensitive   = true
}

variable "jupyter_oauth_client_secret" {
  description = "Google OAuth web client secret for JupyterHub."
  type        = string
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
