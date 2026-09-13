provider "google" {
  project = var.gke_project_id
  region  = var.gke_location
}

data "google_client_config" "current" {}

data "google_container_cluster" "sandbox" {
  project  = var.gke_project_id
  name     = var.gke_cluster_name
  location = var.gke_location
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.sandbox.endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.sandbox.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace_v1" "sandbox" {
  metadata {
    name = var.namespace
    labels = {
      "sandbox/task"       = var.task_name
      "app.kubernetes.io/managed-by" = "infrastructure-manager"
    }
  }
}

resource "kubernetes_resource_quota_v1" "sandbox" {
  metadata {
    name      = "quota-${var.task_name}"
    namespace = kubernetes_namespace_v1.sandbox.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"             = "8"
      "requests.memory"          = "64Gi"
      "limits.cpu"               = "12"
      "limits.memory"            = "96Gi"
      "persistentvolumeclaims"   = "5"
    }
  }
}

resource "kubernetes_service_account_v1" "jupyter" {
  metadata {
    name      = var.jupyter_ksa_name
    namespace = kubernetes_namespace_v1.sandbox.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = var.jupyter_gsa_email
    }
  }
}

resource "kubernetes_role_v1" "task_user" {
  metadata {
    name      = "role-${var.task_name}-user"
    namespace = kubernetes_namespace_v1.sandbox.metadata[0].name
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["pods", "pods/log", "services", "configmaps", "persistentvolumeclaims", "deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "task_group" {
  metadata {
    name      = "rb-${var.task_name}-group"
    namespace = kubernetes_namespace_v1.sandbox.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.task_user.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.group_email
  }
}

output "namespace" { value = kubernetes_namespace_v1.sandbox.metadata[0].name }
output "jupyter_ksa_name" { value = kubernetes_service_account_v1.jupyter.metadata[0].name }
