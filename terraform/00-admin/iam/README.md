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


## Foundation 완료를 위한 관리자 Bootstrap

Foundation 실행 계정의 GKE 및 Shared VPC 권한은 Git에서 관리하는 `foundation-bootstrap.admin.tfvars`로 적용합니다. 로컬 변수 파일을 수정하지 않습니다.

이 단계는 `pjt-d-shared-base`, `pjt-d-host01`, `prj-b-cicd-local-236d`의 IAM 및 대상 Subnet IAM을 변경할 수 있는 관리자 계정으로만 수행합니다.

```bash
terraform plan -input=false \
  -var-file=foundation-bootstrap.admin.tfvars \
  -out=foundation-bootstrap.tfplan

terraform show -no-color foundation-bootstrap.tfplan
terraform apply foundation-bootstrap.tfplan
```

적용 범위는 Foundation 실행 계정의 GKE 관리 권한, 두 GKE Subnet의 Network User, Cloud Run 서비스 에이전트의 Cloud Run Subnet Network User입니다. Host Project 단위 Network Viewer는 사용하지 않습니다. Folder XPN, Project Factory, Workflow 교차 프로젝트 권한은 이 프로필에서 비활성화됩니다.


## 관리영역별 독립 State

한 실행 계정이 세 프로젝트의 IAM을 모두 관리하지 못하므로 Bootstrap을 다음처럼 분리합니다.

| 관리영역 | Git 변수 파일 | Backend Prefix |
|---|---|---|
| CI/CD 프로젝트 | `foundation-bootstrap.admin.tfvars` | `admin/shared-vpc-iam` (기존 성공 State 유지) |
| GKE 프로젝트 | `foundation-gke-project.admin.tfvars` | `admin/foundation-gke-project-iam` |
| Shared VPC | `foundation-shared-vpc.admin.tfvars` | `admin/foundation-shared-vpc-iam` |

각 영역은 해당 프로젝트 IAM 관리자가 별도로 실행합니다. 서로 다른 관리영역을 하나의 State에 다시 합치지 않습니다.


## 관리자 프로필 사전검사

Terraform Plan/Apply 전에 대상 프로젝트 IAM Policy 조회 가능 여부를 검사합니다.

```bash
bash preflight-admin-profile.sh cicd
bash preflight-admin-profile.sh gke
bash preflight-admin-profile.sh shared-vpc
```

`BLOCKED`가 표시되면 해당 로그인 계정으로 Terraform을 실행하지 않습니다. 조회 검사가 성공하더라도 실제 적용 전 `resourcemanager.projects.setIamPolicy` 보유 여부를 관리자에게 확인해야 합니다.


## Subnet 최소 권한 원칙

Shared VPC Host Project의 프로젝트 IAM 변경 권한이 없는 운영 경계를 반영하여 다음 두 프로젝트 단위 Binding은 생성하지 않습니다.

- Foundation 실행 계정의 `roles/compute.networkViewer`
- Cloud Run 서비스 에이전트의 `roles/compute.networkViewer`

대신 각 대상 Subnet의 `roles/compute.networkUser`만 관리합니다. 이 역할은 Cloud Run Direct VPC와 GKE Shared VPC의 Subnet 사용에 필요한 조회·사용 권한을 제공합니다.


## 확인된 IAM 제약과 적용 규칙

- `roles/compute.xpnAdmin`은 Project IAM에 지원되지 않는다. 반드시 Shared VPC 관리
  Folder `154455658682`의 `google_folder_iam_member`로만 적용한다.
- `roles/compute.securityAdmin`은 Host Project Firewall 생성 권한
  (`compute.firewalls.create`)을 포함하므로 `sa-im-network-admin`의 Host 역할에 포함한다.
- Foundation VM 실행 계정에는 Host Project 전체 `roles/compute.networkViewer` 대신 실제
  GKE/Cloud Run 대상 Subnet의 `roles/compute.networkUser`만 부여한다.
- `pjt-net-hub-base`에서 기존 프로젝트를 다루는 `sa-im-project-factory`에는
  `roles/browser`, `roles/resourcemanager.projectIamAdmin`,
  `roles/serviceusage.serviceUsageAdmin`을 부여한다.
- IAM 프로필을 바꿀 때는 반드시 해당 프로필의 독립 Backend Prefix로
  `terraform init -reconfigure`를 수행한다. 다른 프로필 State에서 Plan을 만들면
  `count = 0`인 기존 Binding이 삭제될 수 있다.

관리자 작업이 끝나면 일반 Foundation/Cloud Build 작업 전 다음을 실행해 관리자 토큰을
제거한다.

```bash
unset GOOGLE_OAUTH_ACCESS_TOKEN
gcloud config set account 40744085720-compute@developer.gserviceaccount.com
```
