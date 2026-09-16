variable "gke_project_id" { type = string }
variable "task_name" { type = string }
variable "jupyter_domain" { type = string }
variable "neg_self_links" { type = list(string) }

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "shared_vpc_host_project_id" {
  type    = string
  default = "pjt-d-shared-base"
}

variable "shared_vpc_network_name" {
  type    = string
  default = "vpc-d-shared-base"
}

variable "frontend_subnet_name" {
  type    = string
  default = "subnet-dev-sbx-ing-01-an3-ilb"
}
