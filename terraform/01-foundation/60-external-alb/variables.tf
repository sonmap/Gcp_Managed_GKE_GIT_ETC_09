variable "gke_project_id" {
  type    = string
  default = "pjt-d-host01"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "alb_name" {
  type    = string
  default = "alb-jupyter-shared"
}
