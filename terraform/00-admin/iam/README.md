# Top-level administrator IAM

교차 프로젝트/Folder IAM을 관리하는 관리자용 Terraform Root입니다.

기존에는 모든 IAM 영역을 한 번에 읽고 변경했기 때문에, 실행 계정이 한 프로젝트나 Folder의 IAM 권한만 없어도 전체 Plan이 403으로 중단되었습니다. 현재는 영역별 `manage_*` 스위치와 이중 안전 게이트로 승인된 범위만 실행합니다.

## 현재 기본 실행 범위

기본값은 Shared VPC Host의 네트워크 실행 계정 IAM만 활성화합니다.

```hcl
iam_scope        = "network-host-only"
allow_full_scope = false

manage_cloud_run_shared_vpc_iam             = false
manage_project_factory_existing_project_iam = false
manage_network_admin_host_iam                = true
manage_network_admin_xpn_iam                 = false
manage_workflow_gke_iam                      = false
manage_workflow_existing_project_iam         = false
manage_workflow_shared_vpc_iam               = false
```

`manage_network_admin_host_iam = true`이면 다음 역할을 `sa-im-network-admin`에 부여합니다.

- `pjt-d-shared-base`: `roles/compute.networkAdmin`
- `pjt-d-shared-base`: `roles/compute.securityAdmin`

`roles/compute.securityAdmin`은 GKE/Internal ALB Health Check Firewall 생성에 필요한 `compute.firewalls.create`를 제공합니다.

## Full Scope 이중 안전 게이트

Cloud Run IAM, 기존 Sandbox IAM, Folder XPN IAM, Workflow IAM 같은 교차 프로젝트/Folder IAM은 다음 두 값을 동시에 명시해야만 활성화될 수 있습니다.

```hcl
iam_scope        = "full"
allow_full_scope = true
```

둘 중 하나라도 충족하지 않으면 해당 `manage_* = true`가 로컬 `terraform.tfvars`에 남아 있어도 Resource 수는 0입니다. 기본 운영 모드에서는 `allow_full_scope = false`를 유지합니다.

## 중요한 Bootstrap 조건

Terraform은 실행 계정이 가지고 있지 않은 IAM 관리 권한을 스스로 만들 수 없습니다.

- `pjt-d-shared-base` IAM을 관리하려면 실행 계정에 해당 프로젝트의 `resourcemanager.projects.getIamPolicy` 및 `resourcemanager.projects.setIamPolicy`가 필요합니다.
- `pjt-net-hub-base` IAM을 관리하려면 해당 프로젝트 IAM 권한이 필요합니다.
- Folder XPN IAM을 관리하려면 `resourcemanager.folders.getIamPolicy/setIamPolicy`가 필요합니다.

따라서 처음 Bootstrap은 해당 범위의 IAM 관리자 계정으로 실행합니다.

## 실행

```bash
terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=admin/shared-vpc-iam"

terraform plan -out=admin-iam.tfplan
terraform show -no-color admin-iam.tfplan
terraform apply admin-iam.tfplan
```

이 Root는 프로젝트, Network, Subnet, NAT 자체를 생성하거나 삭제하지 않습니다. IAM Binding만 관리합니다.
