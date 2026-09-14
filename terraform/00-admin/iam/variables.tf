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
  description = "Infrastructure Manager identity that creates Shared VPC subnets and firewall rules."
  type        = string
  default     = "sa-im-network-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com"
}

variable "iam_scope" {
  description = "Safety gate for this IAM root. network-host-only manages only sa-im-network-admin project roles. full is eligible for cross-project/folder IAM only when allow_full_scope=true."
  type        = string
  default     = "network-host-only"

  validation {
    condition     = contains(["network-host-only", "full"], var.iam_scope)
    error_message = "iam_scope must be network-host-only or full."
  }
}

variable "allow_full_scope" {
  description = "Second safety gate. Cross-project/folder IAM is disabled unless this is explicitly true together with iam_scope=full."
  type        = bool
  default     = false
}

variable "manage_cloud_run_shared_vpc_iam" {
  description = "Manage Cloud Run service-agent network IAM in the Shared VPC host project. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}

variable "manage_project_factory_existing_project_iam" {
  description = "Manage Project Factory bootstrap IAM on the existing sandbox project. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}

variable "manage_network_admin_host_iam" {
  description = "Manage Network Admin and Security Admin roles for sa-im-network-admin in the Shared VPC host project."
  type        = bool
  default     = true
}

variable "manage_network_admin_xpn_iam" {
  description = "Manage folder-level XPN Admin for sa-im-network-admin. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}

variable "manage_workflow_gke_iam" {
  description = "Manage Workflow IAM on the GKE project. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}

variable "manage_workflow_existing_project_iam" {
  description = "Manage Workflow IAM on the existing sandbox project. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}

variable "manage_workflow_shared_vpc_iam" {
  description = "Manage Workflow read-only IAM on the Shared VPC host project. Effective only when iam_scope=full and allow_full_scope=true."
  type        = bool
  default     = false
}
