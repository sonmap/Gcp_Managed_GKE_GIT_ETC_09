variable "shared_vpc_host_project_id" {
  type    = string
  default = "pjt-d-shared-base"
}

variable "shared_vpc_admin_folder_id" {
  description = "Common folder containing the Shared VPC host and approved service project."
  type        = string
  default     = "154455658682"
}

variable "region" {
  type    = string
  default = "asia-northeast3"
}

variable "cloudrun_subnet_name" {
  type    = string
  default = "subnet-dev-cicd-run-01-an3-egress"
}

variable "cicd_project_number" {
  description = "Numeric project number of prj-b-cicd-local-236d."
  type        = string
  default     = "587273205772"
}

variable "gke_project_id" {
  description = "Project containing the main JupyterHub GKE Autopilot cluster."
  type        = string
  default     = "pjt-d-host01"
}

variable "existing_sandbox_project_id" {
  description = "Existing project approved for sandbox data resources."
  type        = string
  default     = "pjt-net-hub-base"
}

variable "workflow_service_account" {
  description = "Workflow runtime identity created in prj-b-cicd-local-236d."
  type        = string
  default     = "sa-sandbox-workflow@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

variable "project_factory_service_account" {
  description = "Infrastructure Manager identity that prepares an existing sandbox project."
  type        = string
  default     = "sa-im-project-factory@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

variable "network_admin_service_account" {
  description = "Infrastructure Manager identity that creates Shared VPC subnets and service-project associations."
  type        = string
  default     = "sa-im-network-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}
