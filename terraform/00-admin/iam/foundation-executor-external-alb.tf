# Foundation Terraform on instance-son creates the shared classic External HTTP(S) ALB
# in pjt-d-host01. Grant only the load-balancer administration role required for
# global address, backend service, URL map, target proxy, and forwarding rule.
resource "google_project_iam_member" "foundation_executor_external_alb_admin" {
  count = local.full_scope && var.manage_foundation_executor_gke_project_iam ? 1 : 0

  project = var.gke_project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${var.foundation_executor_service_account}"
}
