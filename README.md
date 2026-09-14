# Approved JSON Sandbox Provisioning

승인이 완료된 포털 JSON을 기준으로 Google Group, 신규 프로젝트, 선택적 Shared VPC 네트워크, IAM, BigQuery, GCS, GKE JupyterHub와 External HTTPS Load Balancer를 자동 생성합니다.

상세한 관리 경계, 기존 State 보호, 실행 계정과 단계별 책임은 [docs/architecture-and-operations.md](docs/architecture-and-operations.md)를 먼저 확인합니다.

실제 실행은 [1차 VM Foundation / 2차 GCS JSON Cloud Run 실행 문서](docs/runbook-two-stage.md)를 따릅니다.

## 실행 원칙

1. 승인과 값 확정은 포털에서 끝납니다.
2. 포털은 승인 JSON을 제한된 GCS 버킷에 저장합니다.
3. Cloud Run에는 JSON 전체가 아니라 GCS URI, Object Generation, SHA256을 전달합니다.
4. Cloud Run은 승인 JSON과 고정된 Git Commit의 Terraform Root Module을 결합해 단계별 ZIP Bundle을 만듭니다.
5. Cloud Build YAML이 Google Group을 먼저 동기화하고 Infrastructure Manager Deployment를 순서대로 실행합니다.
6. Cloud Run에는 Project Creator나 Shared VPC Admin 권한을 부여하지 않습니다.

## 프로젝트 역할

| 프로젝트 | 역할 |
|---|---|
| `pjt-d-shared-base` | 기존 Shared VPC, 승인된 과제 Subnet, Service Project 연결 |
| `pjt-d-host01` | 기존 GKE Autopilot, 과제 Namespace, JupyterHub, External HTTPS ALB |
| 신규 과제 프로젝트 | BigQuery Dataset, GCS Bucket, Jupyter GSA |
| `prj-b-cicd-local-236d` | Cloud Run, Cloud Build, Private Pool, Infrastructure Manager, Artifact Registry, 요청/Bundle GCS |

## 저장소 구조

```text
schemas/sandbox-request.schema.json
examples/sbx01-approved-request.json
cloudrun-provisioner/
automation-runner/
cloudbuild/sandbox-orchestrate.yaml
scripts/
terraform/00-network-host/
terraform/00-admin/iam/
terraform/01-foundation/
terraform/02-sandbox/deployments/
  10-project/
  20-network/
  30-project-iam/
  40-data/
  50-gke-jupyter/
  60-loadbalancer/
```

`02-sandbox`는 하나의 Terraform State를 공유하지 않습니다. Infrastructure Manager가 `im-sbx01-project`, `im-sbx01-network`, `im-sbx01-iam`, `im-sbx01-data`, `im-sbx01-gke-access`, `im-sbx01-lb` Deployment별 State와 Revision을 관리합니다. 따라서 이 Root Module들에는 `backend` 블록이 없습니다.

## 포털에서 Cloud Run 호출

```json
{
  "request_id": "REQ-20260912-001",
  "approved_json_uri": "gs://prj-b-cicd-local-236d-sandbox-requests/approved/REQ-20260912-001/request.json",
  "generation": "1757721000000000",
  "sha256": "APPROVED_JSON_SHA256"
}
```

Cloud Run은 다음 항목을 다시 기술 검증합니다.

- `approval.status`가 `APPROVED`인지 확인
- GCS Object Generation과 SHA256 확인
- 프로젝트, Group, Domain, 리전, Git 저장소 허용 규칙 확인
- Git Commit SHA가 40자리 고정값인지 확인
- `/24` Subnet 값의 Terraform 사전조건 확인

## 자동 실행 순서

| 순서 | 실행 | 실행 계정 |
|---:|---|---|
| 1 | Google Group 및 과제원 동기화 | `sa-sandbox-group-admin`의 Workspace 위임 자격증명 |
| 2 | Project·Folder·Billing·API | `sa-im-project-factory` |
| 3 | 선택적 Subnet·Shared VPC Join | `sa-im-network-admin` |
| 4 | 프로젝트 IAM | `sa-im-project-iam` |
| 5 | BigQuery·GCS·Jupyter GSA | `sa-im-data-admin` |
| 6 | GKE Namespace·KSA·RBAC | `sa-im-gke-admin` |
| 7 | JupyterHub Helm Release | Cloud Build Orchestrator |
| 8 | NEG 발견 후 External HTTPS ALB | `sa-im-lb-admin` |

Google Group 생성 직후 Cloud IAM 전파 시간을 기다린 후 프로젝트 IAM과 BigQuery/GCS IAM을 적용합니다.

`network.required=false`이면 Network Deployment는 자동으로 생략합니다. 중앙 GKE의 Jupyter와 BigQuery/GCS만 사용하는 과제는 보통 별도 Subnet과 Shared VPC Join이 필요하지 않습니다.

## 최초 관리자 준비

자동 실행 전에 권한 담당자가 다음 작업을 완료해야 합니다.

- GitHub 저장소와 Cloud Build 연결
- `sa-im-project-factory`에 Sandbox Folder Project Creator와 지정 Billing User 부여
- `sa-im-network-admin`에 `pjt-d-shared-base`의 승인된 Network Admin/XPN Admin 부여
- `sa-im-project-iam`에 신규 과제 프로젝트 IAM 관리 권한 부여
- `sa-im-data-admin`에 신규 과제 프로젝트 BigQuery, Storage, Service Account 권한 부여
- `sa-im-gke-admin`에 `pjt-d-host01` GKE 관리 권한 부여
- `sa-im-lb-admin`에 `pjt-d-host01` Load Balancer 관리 권한 부여
- Google Workspace에서 Group Admin SA의 Domain-wide Delegation 승인
- Jupyter Helm Chart `4.2.0`을 사내 Artifact Registry OCI 저장소에 미러링
- Secret Manager에 Workspace DWD key와 Jupyter OAuth 값을 등록

## Foundation 적용

```bash
cd terraform/01-foundation
cp terraform.tfvars.example terraform.tfvars
terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=foundation"
terraform validate
terraform plan -out=foundation.tfplan
```

Plan 검토 후에만 Apply합니다.

기존 State 주소를 보호하기 위한 `migrations.tf`가 포함되어 있습니다. 적용 전에 다음 명령으로 삭제·교체 예정 자원이 없는지 확인합니다.

```bash
terraform show -no-color foundation.tfplan | \
  grep -E '^  #|must be replaced|will be destroyed|^Plan:'
```

## 현재 자동화 범위

이 버전의 승인 JSON Schema는 `CREATE`만 허용합니다. 삭제는 BigQuery/GCS 보존, Shared VPC 분리, 프로젝트 삭제와 Google Group 삭제의 역순 통제가 필요하므로 별도의 승인 JSON 및 Retention Workflow로 구현해야 합니다.


## 2026-09 PoC 운영 현황 및 재실행 기준

> 이 절은 `sbx01` 기존 프로젝트 PoC에서 확인한 실행 경계와 오류 수정 내역이다.
> 실제 생성 여부는 Terraform Plan 및 Infrastructure Manager Revision으로 확인한다. 비용중지
> 프로파일을 적용한 뒤에는 GKE, Cloud Run, Workflow가 삭제된 상태일 수 있다.

### 확정된 대상 및 실행 계정

| 구분 | 대상 | 주 실행 계정 | 비고 |
|---|---|---|---|
| Foundation | `prj-b-cicd-local-236d`, `pjt-d-host01`, Shared VPC | `40744085720-compute@developer.gserviceaccount.com` | VM 기본 서비스 계정 |
| 관리자 IAM Bootstrap | Project/Folder IAM | `admin@sonmap.net` | 대상 IAM 정책 조회·변경 권한이 있을 때만 사용 |
| 2차 Project | `pjt-net-hub-base` | `sa-im-project-factory` | 기존 프로젝트, 삭제 금지 |
| 2차 Network | `pjt-d-shared-base` / `vpc-d-shared-base` | `sa-im-network-admin` | `subnet-sbx01-an3` 사용 |
| 2차 Data | `pjt-net-hub-base` | `sa-im-data-admin` | 기존 Dataset/GSA 채택 가능 |
| GKE | `pjt-d-host01/gke-sbx-main-an3` | `sa-im-gke-admin` | 과제 Namespace 및 JupyterHub |
| CI/CD GKE | `prj-b-cicd-local-236d/gke-dev-cicd-01-an3` | Foundation 실행 계정 | Autopilot Test Cluster |

일반 Foundation 실행 중에는 개인 ADC 로그인을 하지 않는다. VM 기본 서비스 계정을 사용하며,
관리자 IAM Bootstrap에서만 관리자의 단기 Access Token 또는 관리자 인증을 사용한다.
`GOOGLE_OAUTH_ACCESS_TOKEN`을 사용한 뒤에는 반드시 `unset GOOGLE_OAUTH_ACCESS_TOKEN` 한다.

### 적용된 핵심 수정

| 증상 | 원인 | Git 반영 해결 |
|---|---|---|
| Shared VPC IAM 403 | 일반 실행 계정에 대상 Project/Folder IAM 정책 조회 권한이 없음 | 관리자 전용 IAM 프로필과 관리영역별 Backend Prefix 분리 |
| `compute.firewalls.create` 403 | Network Admin SA에 Firewall 권한 부족 | Host IAM에 `roles/compute.securityAdmin` 추가 |
| `roles/compute.xpnAdmin` 400 | XPN Admin은 Project IAM Role이 아님 | Folder `154455658682`에만 `google_folder_iam_member`로 관리 |
| GKE Subnet/GKE 생성 403 | Foundation 실행 계정의 Shared VPC Subnet 권한 부족 | 대상 Subnet별 `roles/compute.networkUser` Bootstrap |
| 기존 GSA/Dataset 409 | 실제 자원이 존재하지만 Infrastructure Manager State에는 없음 | 승인 JSON의 `data.adopt_existing_resources=true`일 때 Cloud Run이 리터럴 ID `imports.tf` 생성 |
| `Variables not allowed` in import | Terraform 1.5.7 import ID에 `var.*` 사용 | Root Module의 변수 기반 import 제거; 요청 Bundle에서 정적 import 생성 |
| 서로 다른 IAM 프로필 적용 시 삭제 계획 | 서로 다른 관리영역이 같은 Terraform State Prefix 사용 | 프로필마다 독립 Backend Prefix 사용; Apply 전 삭제 주소 검토 |

### 기존 Data 자원 채택 규칙

`40-data` Root Module에는 import block을 직접 두지 않는다. Infrastructure Manager의
Terraform 1.5.7은 import ID에서 변수를 지원하지 않는다.

승인 JSON의 다음 값이 `true`이면 Cloud Run이 요청별 ZIP Bundle 안에 정적
`imports.tf`를 생성한다.

```json
{
  "data": {
    "adopt_existing_resources": true
  }
}
```

현재 채택 대상은 기존 Jupyter GSA와 BigQuery Dataset이다. GCS Bucket의 존재 여부가
확인되지 않은 상태에서는 Bucket import를 추가하지 않는다. 재실행에서 Bucket 409가
발생할 때만 Git 소스에 Bucket 정적 import를 추가하고 새 release를 발행한다.

### sbx01 재실행 절차

현재 예시 요청은 `REQ-20260914-004`, `release-20260914-03`을 사용한다.
실행 전에 Git 최신 상태와 Foundation 프로비저너 이미지를 먼저 반영한다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09
git pull --ff-only origin main

unset GOOGLE_OAUTH_ACCESS_TOKEN
gcloud config set account 40744085720-compute@developer.gserviceaccount.com

cd terraform/01-foundation
terraform plan -input=false -out=foundation.tfplan
terraform show -no-color foundation.tfplan
terraform apply foundation.tfplan
```

그 후 승인 JSON을 GCS에 새 Generation으로 업로드하고 Workflow를 실행한다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09
REQUEST_ID="REQ-20260914-004"
REQUEST_URI="gs://prj-b-cicd-local-236d-sandbox-requests/approved/${REQUEST_ID}/request.json"

gcloud storage cp examples/sbx01-approved-request.json "${REQUEST_URI}"
REQUEST_GENERATION=$(gcloud storage objects describe "${REQUEST_URI}" --format="value(generation)")
REQUEST_SHA256=$(gcloud storage cat "${REQUEST_URI}" | sha256sum | awk '{print $1}')

gcloud workflows run workflow-dev-sbx-01-an3-provision \
  --project=prj-b-cicd-local-236d \
  --location=asia-northeast3 \
  --data="$(jq -nc \
    --arg request_id "${REQUEST_ID}" \
    --arg approved_json_uri "${REQUEST_URI}" \
    --arg generation "${REQUEST_GENERATION}" \
    --arg sha256 "${REQUEST_SHA256}" \
    '{request_id:$request_id, approved_json_uri:$approved_json_uri, generation:($generation|tonumber), sha256:$sha256}')"
```

Workflow의 `SUCCEEDED`는 요청 접수와 Cloud Build 시작 성공을 뜻한다. 최종 상태는 다음으로
확인한다.

```bash
gcloud builds list --project=prj-b-cicd-local-236d --region=asia-northeast3 \
  --limit=5 --sort-by="~createTime" --format="table(id,status,createTime)"

gcloud infra-manager deployments list --project=prj-b-cicd-local-236d \
  --location=asia-northeast3 --filter="name:im-sbx01" \
  --format="table(name.basename(),state,latestRevision.basename())"
```

### 비용중지 및 재시작

전면 `terraform destroy`는 State Bucket, IAM, Artifact Registry까지 제거할 수 있으므로 금지한다.
비용중지는 Foundation Root의 Git 관리 프로파일을 사용한다. 이 프로파일은 GKE Main/Test,
Cloud Run, Workflow만 삭제하고 State·요청/Bundle Bucket·자동화 Service Account·IAM·기존
`pjt-net-hub-base` 자원은 보존한다.

```bash
cd terraform/01-foundation
terraform plan -input=false \
  -var-file=foundation-cost-stop.tfvars \
  -out=foundation-cost-stop.tfplan
terraform show -no-color foundation-cost-stop.tfplan
terraform apply foundation-cost-stop.tfplan
```

Private Pool까지 중지해야 할 때만 다음 Target Destroy를 별도로 실행한다. 다음 정상
Foundation Apply에서 Pool은 다시 생성된다.

```bash
terraform destroy -target=google_cloudbuild_worker_pool.terraform -auto-approve
```

`terraform/00-admin/iam`과 기존 프로젝트의 2차 Infrastructure Manager Deployment는 비용중지
목적으로 삭제하지 않는다. IAM, 기존 Dataset/GSA, Shared VPC 연결의 드리프트를 막기 위함이다.
