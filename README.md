# GCP Managed GKE Sandbox

GitHub, Cloud Build, Cloud Run과 Terraform으로 운영하는 2단계 Sandbox 플랫폼입니다.

## 프로젝트 배치

| 프로젝트 | 역할 |
|---|---|
| `pjt-d-shared-base` | Shared VPC Host, 공통 Subnet과 방화벽 관리 |
| `pjt-d-host01` | GKE Autopilot, JupyterHub, 과제 Namespace, External HTTPS ALB |
| `pjt-c-admin` | `sbx01` BigQuery, GCS, GCE, GSA |
| `prj-b-cicd-local-236d` | Cloud Build, Cloud Run Provisioner, Artifact Registry, Terraform State |

> External HTTPS Load Balancer는 GKE NEG와 같은 서비스 프로젝트인 `pjt-d-host01`에 생성하고, 네트워크는 `pjt-d-shared-base`의 Shared VPC를 사용합니다. Shared VPC Host에 프런트엔드를 강제로 분리하려면 Cross-project service referencing을 별도 설계해야 합니다.

## 실행 구분

| 실행 위치 | Terraform 범위 | 실행 ID |
|---|---|---|
| `pjt-d-shared-base` Cloud Shell | Shared VPC 관련 gcloud 작업 | 로그인한 네트워크 관리자 |
| `pjt-c-admin/asia-northeast3-b/instance-son` | `01-foundation`, `02-sandbox` | `40744085720-compute@developer.gserviceaccount.com` |

Host 프로젝트의 Subnet, PSA, 방화벽은 `instance-son`에서 변경하지 않습니다. Cloud Shell에서 먼저 생성하고 출력된 Self Link와 Subnet 이름을 1차·2차 변수로 전달합니다.

### 1차: 공통 기반

`instance-son`에서 실행합니다.

```bash
cd terraform/01-foundation
cp terraform.tfvars.example terraform.tfvars
terraform init -reconfigure \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="prefix=foundation"
terraform fmt -recursive
terraform validate
terraform plan -out=foundation.tfplan
terraform apply foundation.tfplan
```

### 2차: sbx01 과제

운영에서는 Cloud Run이 Cloud Build를 호출합니다. 수동 검증은 다음과 같습니다.

```bash
cd terraform/02-sandbox
cp terraform.tfvars.example terraform.tfvars
terraform init -reconfigure \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="prefix=sandbox/sbx01"
terraform fmt -recursive
terraform validate
terraform plan -out=sbx01.tfplan
terraform apply sbx01.tfplan
```

## JupyterHub와 외부 HTTPS 접속

### 1. Google OAuth 준비

Google Auth Platform에서 Web application OAuth Client를 만들고 다음 Redirect URI를 등록합니다.

```text
https://jupyter-sbx01.sonmap.net/hub/oauth_callback
```

`terraform/02-sandbox/terraform.tfvars`에 값을 설정합니다.

```hcl
enable_jupyterhub           = true
jupyter_domain              = "jupyter-sbx01.sonmap.net"
jupyter_oauth_client_id     = "REPLACE_OAUTH_CLIENT_ID"
jupyter_oauth_client_secret = "REPLACE_OAUTH_CLIENT_SECRET"
```

OAuth Secret은 Git에 커밋하지 않습니다. 설정 후 `02-sandbox`를 plan/apply하면 JupyterHub와 `neg-jupyter-sbx01` Standalone NEG가 생성됩니다.

### 2. NEG 확인

```bash
gcloud compute network-endpoint-groups list \
  --project=pjt-d-host01 \
  --filter="name=neg-jupyter-sbx01" \
  --format="table(name,zone.basename(),networkEndpointType)"
```

각 Zone의 NEG Self Link를 `terraform/01-foundation/terraform.tfvars`의 `jupyter_neg_self_links`에 입력합니다.

```hcl
external_lb_domain = "jupyter-sbx01.sonmap.net"
jupyter_neg_self_links = [
  "projects/pjt-d-host01/zones/asia-northeast3-a/networkEndpointGroups/neg-jupyter-sbx01",
  "projects/pjt-d-host01/zones/asia-northeast3-b/networkEndpointGroups/neg-jupyter-sbx01",
  "projects/pjt-d-host01/zones/asia-northeast3-c/networkEndpointGroups/neg-jupyter-sbx01",
]
```

실제로 조회된 Zone의 NEG만 입력합니다. 이후 `01-foundation`을 다시 plan/apply하여 External HTTPS ALB를 생성합니다.

### 3. DNS 연결

```bash
cd terraform/01-foundation
terraform output jupyter_external_ip
```

출력된 IP로 다음 Public DNS A 레코드를 등록합니다.

```text
jupyter-sbx01.sonmap.net -> JUPYTER_EXTERNAL_IP
```

Google 관리 인증서가 `ACTIVE` 상태가 된 후 `user01@sonmap.net`으로 접속합니다.

## 주의사항

- 예제 CIDR은 실제 Shared VPC의 기존 Subnet, PSA Range와 중복 여부를 확인한 후 변경합니다.
- `instance-son`에는 외부 IP가 없어도 되지만 Google API 접근 경로와 `cloud-platform` access scope가 필요합니다.
- 기본 Compute 서비스 계정에는 대상 세 프로젝트의 최소 IAM과 GKE API 접근 권한이 필요합니다.
- `pgrp-gcp-dev-sbx01@sonmap.net`과 사용자 3명은 기존 자원으로 조회합니다.
- OAuth Client Secret, `terraform.tfvars`, State, 인증서 개인키와 서비스 계정 키는 Git에 저장하지 않습니다.
- External ALB의 Backend는 GKE Standalone NEG이며 인터넷에서 Pod IP로 직접 접근하지 않습니다.
- Cloud Run이 호출하는 Build Trigger의 설정 파일은 `cloudbuild/sandbox-dispatch.yaml`입니다.
