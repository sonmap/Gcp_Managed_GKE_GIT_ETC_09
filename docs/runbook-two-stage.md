# 2단계 실행 방법

이 플랫폼은 사람의 Terraform 실행을 1차에만 사용합니다.

| 단계 | 실행 위치 | 사람이 하는 일 | 자동화가 하는 일 |
|---|---|---|---|
| 1차: 기본 인프라 | `pjt-c-admin`의 `instance-son` VM | Foundation Terraform Plan 검토 후 Apply | Artifact Registry, Private Pool, Cloud Build Trigger, Cloud Run, 요청 GCS, 실행 Service Account 생성 |
| 2차: Sandbox 과제 | 포털 또는 승인 JSON 업로드 주체 | 승인 완료 JSON을 요청 GCS에 1회 업로드하고 Cloud Run 호출 | Group, 신규 프로젝트, 선택적 /24 Subnet/Shared VPC Join, IAM, BigQuery, GCS, GKE JupyterHub, ALB 생성 |

## 1차: instance-son VM에서만 Terraform 실행

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09
git checkout main
git pull --ff-only

cd terraform/01-foundation
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars

terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=foundation"

terraform validate
terraform plan -input=false -out=foundation.tfplan
terraform show -no-color foundation.tfplan
```

Foundation의 확정 네트워크 값은 `variables.tf`에도 안전한 기본값으로 선언되어 있으므로 Plan이 대화형 변수 입력을 요구하지 않아야 합니다. 입력 프롬프트가 나오면 값을 임의로 입력하지 말고 중단합니다.

기본 실행 계정의 확정 네트워크 값과 안전 게이트는 Git에서 관리하는 `zz-foundation-safe.auto.tfvars`가 자동 적용합니다. 사용자가 로컬 `terraform.tfvars`를 수정할 필요가 없습니다. 이 파일은 기존 로컬 변수 파일보다 나중에 로드되어 오래된 서브넷명이나 권한 스위치가 다시 적용되는 것을 막습니다.

기존 Infrastructure Manager 서비스 계정 4개는 `migrations.tf`의 선언형 `import` 블록으로 관리합니다. 별도 로컬 Import 명령 없이 `terraform plan/apply` 과정에서 State에 연결됩니다. Import 도우미 스크립트는 진단용으로만 유지합니다.

Plan에 기존 GKE, Shared VPC, State Bucket의 삭제 또는 교체가 없을 때만 실행합니다.

```bash
terraform apply foundation.tfplan
```

Shared VPC의 Cloud Run Subnet IAM은 Shared VPC 관리자가 별도로 수행합니다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09/terraform/00-admin/iam

terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=admin/shared-vpc-iam"

terraform plan -out=shared-vpc-iam.tfplan
terraform apply shared-vpc-iam.tfplan
```

## 2차: 승인 JSON을 GCS에 올리고 Cloud Run 호출

`terraform/02-sandbox`에서 사람이 `terraform init`, `plan`, `apply`를 실행하면 안 됩니다.

1. 포털이 승인 JSON을 만듭니다.
2. 포털은 다음 경로에 JSON을 한 번만 업로드합니다.

```text
gs://<REQUEST_BUCKET>/approved/<REQUEST_ID>/request.json
```

3. 업로드 원문 SHA256과 GCS Object Generation을 얻습니다.
4. 포털은 Cloud Run `/provision`에 네 값만 전달합니다.

```json
{
  "request_id": "REQ-20260912-001",
  "approved_json_uri": "gs://<REQUEST_BUCKET>/approved/REQ-20260912-001/request.json",
  "generation": "GCS_OBJECT_GENERATION",
  "sha256": "UPLOADED_FILE_SHA256"
}
```

Cloud Run이 승인 JSON과 고정 Git Commit SHA를 검증한 후 Bundle GCS를 만들고, Cloud Build Private Pool을 시작합니다. Cloud Build가 Infrastructure Manager Deployment를 순서대로 실행합니다.

## 2차의 자동 생성 순서

1. Google Group 생성 및 `user01@sonmap.net` 등 승인 과제원 동기화
2. 신규 Sandbox 프로젝트 생성, Billing 연결, API 활성화
3. 필요할 때만 `/24` Subnet 생성 및 Shared VPC Service Project Join
4. Group 프로젝트 IAM 적용
5. BigQuery Dataset, GCS Bucket, Jupyter Workload Identity GSA 생성
6. GKE Autopilot Namespace, KSA, RBAC 생성
7. JupyterHub 배포 및 NEG 확인
8. External HTTPS Load Balancer 생성

## 현재 정책

- `pjt-c-admin`에는 Sandbox VM을 만들지 않습니다.
- Jupyter Notebook은 `pjt-d-host01`의 GKE Autopilot Pod에서 실행합니다.
- 2차는 `CREATE` 전용입니다. 삭제는 별도 보존/승인 Workflow가 필요합니다.


## pjt-d-host01 권한 대기 중 단계 실행

Main GKE 권한이 아직 승인되지 않은 동안 다음 구성만 활성화합니다.

- CI/CD Test GKE: 활성화
- Cloud Run Provisioner: 활성화
- Workflow: 활성화
- Main JupyterHub GKE: 비활성화

Git 관리 파일 `zz-foundation-safe.auto.tfvars`가 이 상태를 자동 적용합니다. 먼저 Shared VPC IAM Root를 재실행하여 CI/CD 프로젝트의 GKE 관련 서비스 계정 3개에 Test Subnet Network User를 부여한 후 Foundation을 재실행합니다.


## Test GKE 부분 생성 복구

Test GKE 생성 후 Instance Group Manager 조회에서 권한 오류가 발생한 경우 CI/CD IAM 프로필을 다시 적용하여 Foundation 실행 계정에 `roles/compute.viewer`와 `roles/workflows.admin`을 추가합니다. `migrations.tf`의 선언형 Import가 이미 생성된 `gke-dev-cicd-01-an3`을 Foundation State에 연결합니다.


## GKE 삭제·교체 보호

Main/Test GKE 모두 GKE `deletion_protection = true`와 Terraform `lifecycle.prevent_destroy = true`를 적용합니다. 이후 Plan에 클러스터 교체가 필요하더라도 Apply 단계에서 차단되며, Git 검토 없이 삭제 보호를 해제하지 않습니다.
