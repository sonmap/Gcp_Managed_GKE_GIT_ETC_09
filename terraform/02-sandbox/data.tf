data "google_project" "resource" { project_id = var.resource_project_id }

# 기존 Group과 사용자 계정은 생성하지 않습니다. 이메일을 IAM/RBAC principal로 사용합니다.
