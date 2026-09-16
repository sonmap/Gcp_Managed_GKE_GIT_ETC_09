variable "shared_vpc_host_project_id" { type = string }
variable "network_name" { type = string }
variable "region" { type = string }

variable "internal_alb_frontend_subnet_name" { type = string }
variable "internal_alb_frontend_subnet_cidr" { type = string }
variable "jupyter_internal_alb_ip_name" { type = string }
variable "jupyter_internal_alb_ip" { type = string }
variable "internal_alb_proxy_subnet_name" { type = string }
variable "internal_alb_proxy_subnet_cidr" { type = string }

variable "lb_admin_service_account_email" {
  type    = string
  default = "sa-im-lb-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

variable "gke_main_subnet_name" { type = string }
variable "gke_main_subnet_cidr" { type = string }
variable "gke_main_pod_range_name" { type = string }
variable "gke_main_pod_cidr" { type = string }
variable "gke_test_subnet_name" { type = string }
variable "gke_test_subnet_cidr" { type = string }
variable "gke_test_pod_range_name" { type = string }
variable "gke_test_pod_cidr" { type = string }

variable "cloudrun_subnet_name" { type = string }
variable "cloudrun_subnet_cidr" { type = string }
variable "cloudbuild_psa_name" { type = string }
variable "cloudbuild_psa_cidr" { type = string }

variable "task_name" { type = string }
variable "task_subnet_cidr" { type = string }
variable "task_vm_service_account_email" { type = string }

variable "enable_firewall_changes" {
  type        = bool
  description = "Global approval gate for firewall mutations. Keep false unless the caller already has compute.firewalls.create in the Shared VPC host project."
  default     = false
}

variable "create_health_check_firewall" {
  type        = bool
  description = "Create the GKE L7 health-check and internal ALB proxy firewall rules only when enable_firewall_changes is also true."
  default     = false
}
