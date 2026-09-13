variable "shared_vpc_host_project_id" {
  type    = string
  default = "pjt-d-shared-base"
}
variable "region" {
  type    = string
  default = "asia-northeast3"
}
variable "cloudrun_subnet_name" {
  type    = string
  default = "subnet-cloudrun-egress-an3"
}
variable "cicd_project_number" {
  description = "Numeric project number of prj-b-cicd-local-236d."
  type        = string
  default     = "587273205772"
}
