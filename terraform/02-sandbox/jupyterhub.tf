locals {
  jupyter_neg_name = "neg-jupyter-${var.task_name}"

  jupyterhub_values = {
    hub = {
      config = {
        JupyterHub = {
          authenticator_class = "google"
        }
        Authenticator = {
          allow_all     = false
          allowed_users = sort(tolist(var.users))
        }
        GoogleOAuthenticator = {
          client_id          = var.jupyter_oauth_client_id
          client_secret      = var.jupyter_oauth_client_secret
          oauth_callback_url = "https://${var.jupyter_domain}/hub/oauth_callback"
          hosted_domain      = ["sonmap.net"]
          login_service      = "Sonmap Google Account"
        }
      }
    }

    proxy = {
      service = {
        type = "ClusterIP"
        annotations = {
          "cloud.google.com/neg" = jsonencode({
            exposed_ports = {
              "80" = { name = local.jupyter_neg_name }
            }
          })
        }
      }
    }

    singleuser = {
      serviceAccountName = kubernetes_service_account_v1.jupyter.metadata[0].name
      cpu = {
        guarantee = 1
        limit     = 2
      }
      memory = {
        guarantee = "8G"
        limit     = "16G"
      }
      storage = {
        type     = "dynamic"
        capacity = var.jupyter_notebook_storage
        dynamic = {
          storageClass = "standard-rwo"
        }
      }
    }

    cull = {
      enabled = true
      timeout = 3600
    }
  }
}

resource "helm_release" "jupyterhub" {
  count = var.enable_jupyterhub ? 1 : 0

  name       = "jupyterhub-${var.task_name}"
  repository = "https://hub.jupyter.org/helm-chart/"
  chart      = "jupyterhub"
  version    = var.jupyterhub_chart_version
  namespace  = kubernetes_namespace_v1.task.metadata[0].name

  atomic  = true
  wait    = true
  timeout = 900

  values = [yamlencode(local.jupyterhub_values)]

  lifecycle {
    precondition {
      condition = (
        var.jupyter_domain != "" &&
        var.jupyter_oauth_client_id != "" &&
        var.jupyter_oauth_client_secret != ""
      )
      error_message = "enable_jupyterhub=true requires jupyter_domain and both Google OAuth client values."
    }
  }

  depends_on = [
    kubernetes_resource_quota_v1.task,
    kubernetes_network_policy_v1.default_deny_ingress,
    google_service_account_iam_member.workload_identity,
  ]
}
