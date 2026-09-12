# GCP Managed GKE Sandbox

GitHub, Cloud Build, Cloud Run과 Terraform으로 운영하는 2단계 Sandbox 플랫폼입니다.

## 프로젝트 배치

| 프로젝트 | 역할 |
|---|---|
| `pjt-d-shared-base` | Shared VPC Host, 공통 Subnet과 방화벽 관리 |
| `pjt-d-host01` | GKE Autopilot, JupyterHub, 과제 Namespace |
| `pjt-c-admin` | `sbx01` BigQuery, GCS, GCE, GSA |
| `prj-b-cicd-local-236d` | Cloud Build, Cloud Run Provisioner, Artifact Registry, Terraform State |

> External HTTPS Load Balancer는 GKE NEG와 같은 서비스 프로젝트인 `pjt-d-host01`에 생성하고, 네트워크는 `pjt-d-shared-base`의 Shared VPC를 사용합니다. Shared VPC Host에 프런트엔드를 강제로 분리하려면 Cross-project service referencing을 별도 설계해야 합니다.

## 실행 구분

### 1차: 공통 기반

```bash
cd terraform/01-foundation
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=YOUR_STATE_BUCKET" -backend-config="prefix=foundation"
terraform plan -out=foundation.tfplan
terraform apply foundation.tfplan
```

### 2차: sbx01 과제

운영에서는 Cloud Run이 Cloud Build를 호출합니다. 수동 검증은 다음과 같습니다.

```bash
cd terraform/02-sandbox
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=YOUR_STATE_BUCKET" -backend-config="prefix=sandbox/sbx01"
terraform plan -out=sbx01.tfplan
terraform apply sbx01.tfplan
```

## 주의사항

- 예제 CIDR은 실제 Shared VPC의 기존 Subnet, PSA Range와 중복 여부를 확인한 후 변경합니다.
- `pgrp-gcp-dev-sbx01@sonmap.net`과 사용자 3명은 기존 자원으로 조회합니다.
- External ALB 공개 전 IAP, Cloud Armor, DNS, 인증서 값을 확정해야 합니다.
- Cloud Run이 호출하는 Build Trigger의 설정 파일은 `cloudbuild/sandbox-dispatch.yaml`입니다.
- `terraform.tfvars`, State, 인증서 개인키와 서비스 계정 키는 Git에 저장하지 않습니다.
