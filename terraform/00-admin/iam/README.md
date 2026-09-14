# Top-level administrator IAM

교차 프로젝트/Folder IAM을 관리하는 관리자 전용 Terraform Root입니다.

Terraform은 실행 계정이 가지고 있지 않은 IAM 관리 권한을 스스로 만들 수 없습니다. 따라서 일반 실행 계정으로 이 Root를 실행해도 대상 프로젝트나 Folder의 IAM Policy를 읽지 않도록 전역 Bootstrap 게이트를 둡니다.

## 기본 실행 범위: IAM 변경 없음

기본값에서는 모든 IAM Resource의 수가 0입니다.

```hcl
enable_iam_changes = false
iam_scope          = "network-host-only"
allow_full_scope   = false

manage_cloud_run_shared_vpc_iam             = false
manage_project_factory_existing_project_iam = false
manage_network_admin_host_iam                = false
manage_network_admin_xpn_iam                 = false
manage_workflow_gke_iam                      = false
manage_workflow_existing_project_iam         = false
manage_workflow_shared_vpc_iam               = false
```

기존 로컬 `terraform.tfvars`에 개별 `manage_* = true`가 남아 있어도 `enable_iam_changes = false`이면 IAM Policy를 읽거나 변경하지 않습니다.

## Shared VPC Host IAM만 승인하는 경우

IAM 관리자가 `pjt-d-shared-base`의 `getIamPolicy/setIamPolicy` 권한을 가진 상태에서 다음 값만 활성화합니다.

```hcl
enable_iam_changes              = true
iam_scope                       = "network-host-only"
allow_full_scope                = false
manage_network_admin_host_iam   = true
```

이 경우 `sa-im-network-admin`에 다음 역할만 부여합니다.

- `roles/compute.networkAdmin`
- `roles/compute.securityAdmin`

`roles/compute.securityAdmin`은 GKE/Internal ALB Health Check Firewall 생성에 필요한 `compute.firewalls.create`를 제공합니다.

## Full Scope 삼중 안전 게이트

Cloud Run IAM, 기존 Sandbox IAM, Folder XPN IAM, Workflow IAM 같은 교차 프로젝트/Folder IAM은 다음 세 값을 동시에 명시해야만 활성화할 수 있습니다.

```hcl
enable_iam_changes = true
iam_scope          = "full"
allow_full_scope   = true
```

그 후 승인된 `manage_* = true` 항목만 생성합니다. 하나라도 충족하지 않으면 Full Scope Resource 수는 0입니다.

## Bootstrap 필수 권한

활성화한 각 대상에서 Terraform 실행 계정에 다음 권한이 먼저 있어야 합니다.

- `pjt-d-shared-base`: `resourcemanager.projects.getIamPolicy/setIamPolicy`
- `pjt-net-hub-base`: `resourcemanager.projects.getIamPolicy/setIamPolicy`
- `pjt-d-host01`: `resourcemanager.projects.getIamPolicy/setIamPolicy`
- Folder `154455658682`: `resourcemanager.folders.getIamPolicy/setIamPolicy`

해당 권한이 없다면 `enable_iam_changes = false`를 유지하고, 조직/프로젝트 IAM 관리자가 필요한 Binding을 별도로 적용해야 합니다.

## 현재 오류를 중단하는 로컬 설정

기존 `terraform.tfvars`를 사용하는 경우 아래 값을 추가하십시오.

```hcl
enable_iam_changes = false
```

그 다음 새 Plan 파일을 생성합니다. 이전에 저장한 Plan은 재사용하지 않습니다.

```bash
rm -f admin-iam.tfplan
terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=admin/shared-vpc-iam"

terraform plan -out=admin-iam.tfplan
terraform show -no-color admin-iam.tfplan
terraform apply admin-iam.tfplan
```

정상적인 기본 Plan 결과는 IAM Resource의 생성·변경·삭제가 없는 상태입니다.

이 Root는 프로젝트, Network, Subnet, NAT 자체를 생성하거나 삭제하지 않습니다. IAM Binding만 선택적으로 관리합니다.


## 기존 IAM State 403 자동 정리

`enable_iam_changes = false`인데도 Plan의 Refresh 단계에서 403이 발생하면, 과거 IAM Resource가 State에 남아 있는 상태입니다. 저장소의 정리 스크립트를 사용합니다.

먼저 Dry Run으로 제거 대상만 확인합니다.

```bash
bash cleanup-disabled-iam-state.sh
```

목록을 확인한 후 State 백업과 정리를 실행합니다.

```bash
bash cleanup-disabled-iam-state.sh --apply
terraform plan -out=admin-iam.tfplan
terraform show -no-color admin-iam.tfplan
```

스크립트는 실제 GCP IAM Binding을 삭제하지 않고 해당 주소를 Terraform State에서만 제거합니다. 실행 전에 현재 State를 `admin-iam-state-backup-<UTC시각>.json`으로 저장합니다.
