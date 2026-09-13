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
