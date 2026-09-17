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

# Central route registry for the one shared External ALB.
# Each sandbox creates its own global EXTERNAL backend service separately;
# this Foundation state is the only state allowed to update the shared URL map.
variable "sandbox_routes" {
  type = map(object({
    hostname             = string
    backend_service_name = string
  }))

  default = {
    sbx01 = {
      hostname             = "jupyter-sbx01.sonmap.net"
      backend_service_name = "bes-jupyter-sbx01"
    }
  }
}
