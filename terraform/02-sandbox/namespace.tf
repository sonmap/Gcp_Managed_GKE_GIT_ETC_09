resource "kubernetes_namespace_v1" "task" {
  metadata {
    name   = var.task_name
    labels = { "sandbox/task" = var.task_name }
  }
}
resource "kubernetes_resource_quota_v1" "task" {
  metadata {
    name      = "quota-${var.task_name}"
    namespace = kubernetes_namespace_v1.task.metadata[0].name
  }
  spec { hard = { "requests.cpu" = "8", "requests.memory" = "64Gi", "limits.cpu" = "12", "limits.memory" = "96Gi", "persistentvolumeclaims" = "5" } }
}
resource "kubernetes_role_v1" "task_user" {
  metadata {
    name      = "role-${var.task_name}-user"
    namespace = kubernetes_namespace_v1.task.metadata[0].name
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
    namespace = kubernetes_namespace_v1.task.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.task_user.metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = var.group_email
    api_group = "rbac.authorization.k8s.io"
  }
}
resource "kubernetes_network_policy_v1" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace_v1.task.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}
