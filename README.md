# GCP Managed GKE Sandbox

GitHub, Cloud Run, Cloud Build와 Terraform으로 운영하는 2단계 Sandbox 플랫폼입니다.

## 확정 프로젝트 역할

| 프로젝트 | 역할 |
|---|---|
| `pjt-d-shared-base` | Shared VPC Host, 공통 Subnet, NAT, PSA 관리 |
| `pjt-d-host01` | GKE Autopilot, 과제 Namespace, JupyterHub, External HTTPS ALB |
| `pjt-c-admin` | 과제별 BigQuery Dataset, GCS Bucket, Jupyter GSA만 생성 |
| `prj-b-cicd-local-236d` | Cloud Run Provisioner, Cloud Build Trigger/Private Pool, Artifact Registry, Secret Manager, Terraform State |

`02-sandbox`는 `pjt-c-admin`에 VM을 만들지 않습니다. Notebook은 `pjt-d-host01`의 GKE Autopilot Pod로 실행합니다.

## 실행 구조

| 단계 | 실행 위치 | 생성 범위 |
|---|---|---|
| 1차 `01-foundation` | `pjt-c-admin`의 `instance-son`에서 Terraform 실행 | GKE, Artifact Registry, Private Pool, Cloud Build Trigger, Cloud Run Provisioner, 실행 SA, OAuth Secret 컨테이너 |
| 2차 `02-sandbox` | Cloud Run → Cloud Build Private Pool → Terraform | Namespace, JupyterHub/NEG, GSA/KSA, BigQuery, GCS |
| Shared VPC 작업 | `pjt-d-shared-base` Cloud Shell에서 gcloud 실행 | Subnet, NAT, PSA, Shared VPC IAM |

## 1차 실행 전 준비

### GitHub 연결

Cloud Build GitHub App에서 다음 저장소를 `prj-b-cicd-local-236d` 프로젝트에 연결합니다.

```text
sonmap/Gcp_Managed_GKE_GIT_ETC_09
```

Terraform은 연결된 저장소를 사용해 `trigger-sandbox-dispatch`를 생성합니다. GitHub App 승인은 Terraform으로 대신할 수 없는 최초 1회 작업입니다.

### Terraform State 버킷

```text
tfstate-sbx-cicd-236d-40744085720
```

State 버킷은 `01-foundation`보다 먼저 생성되어 있어야 합니다.

## 1차: Foundation

`instance-son`에서 실행합니다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09/terraform/01-foundation
cp terraform.tfvars.example terraform.tfvars

terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=foundation"

terraform fmt -recursive
terraform validate
terraform plan -out=foundation.tfplan
terraform apply foundation.tfplan
terraform output
```

Terraform은 다음 순서로 작업합니다.

1. Artifact Registry `ar-sandbox-platform` 생성
2. Cloud Build로 `cloudrun-provisioner` 이미지 빌드 및 Push
3. Cloud Build Private Pool `pool-sandbox-terraform` 생성
4. Cloud Build Trigger `trigger-sandbox-dispatch` 생성
5. Cloud Run `run-sandbox-provisioner` 생성

Provisioner 이미지 주소:

```text
asia-northeast3-docker.pkg.dev/prj-b-cicd-local-236d/ar-sandbox-platform/run-sandbox-provisioner:latest
```

## OAuth Secret 값 등록

Terraform은 Secret 컨테이너만 생성합니다. 실제 OAuth 값은 State에 넣지 않고 별도로 등록합니다.

```bash
read -s -p "OAuth Client ID: " OAUTH_CLIENT_ID
echo
printf '%s' "$OAUTH_CLIENT_ID" | gcloud secrets versions add jupyter-oauth-client-id \
  --project=prj-b-cicd-local-236d \
  --data-file=-

read -s -p "OAuth Client Secret: " OAUTH_CLIENT_SECRET
echo
printf '%s' "$OAUTH_CLIENT_SECRET" | gcloud secrets versions add jupyter-oauth-client-secret \
  --project=prj-b-cicd-local-236d \
  --data-file=-

unset OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET
```

OAuth Redirect URI:

```text
https://jupyter-sbx01.sonmap.net/hub/oauth_callback
```

## 2차: Cloud Run으로 sbx01 생성

Cloud Run URL을 확인합니다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09/terraform/01-foundation
RUN_URL=$(terraform output -raw provisioner_uri)
ID_TOKEN=$(gcloud auth print-identity-token --audiences="$RUN_URL")
```

먼저 Plan 요청:

```bash
curl -X POST "$RUN_URL/provision" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "plan",
    "task_name": "sbx01",
    "group_email": "pgrp-gcp-dev-sbx01@sonmap.net"
  }'
```

Plan 확인 후 Apply 요청:

```bash
curl -X POST "$RUN_URL/provision" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "apply",
    "task_name": "sbx01",
    "group_email": "pgrp-gcp-dev-sbx01@sonmap.net"
  }'
```

호출 흐름:

```text
사용자
  → run-sandbox-provisioner
  → trigger-sandbox-dispatch
  → pool-sandbox-terraform
  → terraform/02-sandbox
  ├─ pjt-d-host01: Namespace, JupyterHub, NEG, KSA
  └─ pjt-c-admin: BigQuery, GCS, GSA
```

## 02-sandbox 생성 자원

| 프로젝트 | 자원 |
|---|---|
| `pjt-d-host01` | Namespace `sbx01`, JupyterHub `jupyterhub-sbx01`, NEG `neg-jupyter-sbx01`, KSA `ksa-jupyter-sbx01` |
| `pjt-c-admin` | BigQuery `sbx01_main`, GCS `pjt-c-admin-sbx01-data`, GSA `gsa-jupyter-sbx01` |
| 생성하지 않음 | `vm-sbx01-01`, `sa-vm-sbx01` |

## External HTTPS ALB

JupyterHub 적용 후 NEG를 확인합니다.

```bash
gcloud compute network-endpoint-groups list \
  --project=pjt-d-host01 \
  --filter="name=neg-jupyter-sbx01" \
  --format="table(name,zone.basename(),networkEndpointType)"
```

조회된 NEG Self Link를 `01-foundation/terraform.tfvars`의 `jupyter_neg_self_links`에 넣고 `external_lb_domain`을 설정한 후 Foundation을 다시 적용합니다.

```hcl
external_lb_domain = "jupyter-sbx01.sonmap.net"
jupyter_neg_self_links = [
  "projects/pjt-d-host01/zones/asia-northeast3-a/networkEndpointGroups/neg-jupyter-sbx01",
]
```

실제로 생성된 Zone의 NEG만 입력합니다. ALB IP가 만들어진 뒤 Public DNS A 레코드를 등록합니다.

## 보안 주의사항

- OAuth Client Secret, `terraform.tfvars`, Terraform State를 Git에 커밋하지 않습니다.
- Cloud Run은 IAM 인증이 필요하며 `pgrp-gcp-dev-sbx01@sonmap.net` 그룹만 호출할 수 있습니다.
- Cloud Build 실행 SA는 02단계 생성에 필요한 프로젝트 권한만 사용합니다.
- Cloud Run의 Google API 호출은 Direct VPC Egress가 아니라 Google API 경로를 사용합니다.
- Direct VPC Egress Subnet은 사설 VPC 목적지 통신에 사용합니다.
- `subnet-sbx01-an3`은 Sandbox VM을 만들지 않으므로 현재 02단계에서는 사용하지 않습니다.
