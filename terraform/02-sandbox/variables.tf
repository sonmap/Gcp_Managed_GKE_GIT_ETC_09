variable "task_name" {
  type = string
  default = "sbx01"
}
variable "resource_project_id" {
  type = string
  default = "pjt-c-admin"
}
variable "gke_project_id" {
  type = string
  default = "pjt-d-host01"
}
variable "shared_vpc_host_project_id" {
  type = string
  default = "pjt-d-shared-base"
}
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
variable "subnet_cidr" { type = string }
variable "gke_cluster_name" {
  type = string
  default = "gke-sbx-main-an3"
}
variable "group_email" {
  type = string
  default = "pgrp-gcp-dev-sbx01@sonmap.net"
}
variable "users" {
  type = set(string)
  default = ["user01@sonmap.net", "user02@sonmap.net", "user03@sonmap.net"]
}
variable "vm_machine_type" {
  type = string
  default = "e2-standard-2"
}
variable "vm_boot_disk_gb" {
  type = number
  default = 50
}

