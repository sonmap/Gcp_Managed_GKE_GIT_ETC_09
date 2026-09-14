# Git 파일별 용도 카탈로그

이 문서는 `main` 브랜치의 추적 파일을 파일 단위로 설명한다. Terraform State,
`*.tfplan`, `.terraform/`, 로컬 `terraform.tfvars`, 인증서·키·ADC는 Git 추적 대상이
아니며 이 목록에 포함하지 않는다.

## 최상위·자동화 컨테이너

| 파일 | 용도 |
|---|---|
| `.gitignore` | Terraform State/Plan, 로컬 변수 파일, Python 캐시, 비밀정보가 Git에 들어가지 않도록 제외한다. |
| `README.md` | 전체 아키텍처, 실행 책임, 오류 수정 이력, 재실행·비용중지 Runbook의 시작 문서다. |
| `automation-runner/Dockerfile` | GKE/Jupyter 작업용 Cloud Build 실행 이미지의 컨테이너 정의다. |
| `automation-runner/apply_gke_workload.py` | GKE 인증, Namespace·KSA·RBAC·JupyterHub 관련 Kubernetes 작업을 수행한다. |
| `automation-runner/requirements.txt` | 자동화 컨테이너 Python 의존성 목록이다. |
| `cloudbuild/sandbox-orchestrate.yaml` | 승인된 Sandbox 요청을 처리하는 Cloud Build Trigger용 선언형 Build 구성이다. |
| `cloudrun-provisioner/Dockerfile` | 승인 요청을 받아 Bundle을 만드는 Cloud Run 서비스 컨테이너 정의다. |
| `cloudrun-provisioner/main.py` | 승인 JSON 검증, source ZIP 검증·추출, 단계별 Bundle 생성, Infrastructure Manager/Cloud Build 호출의 핵심 프로그램이다. 기존 Data 자원 채택 시 리터럴 `imports.tf`도 생성한다. |
| `cloudrun-provisioner/requirements.txt` | Cloud Run 프로비저너 Python 의존성 목록이다. |
| `cloudrun-provisioner/sandbox-request.schema.json` | Cloud Run이 실제 런타임에 사용하는 승인 요청 JSON Schema다. |
| `examples/sbx01-approved-request.json` | `sbx01` PoC의 승인 요청 예시다. 현재 existing project와 release 정보, 기존 Data 자원 채택 플래그를 포함한다. |
| `schemas/sandbox-request.schema.json` | 포털·개발자 참고용 승인 요청 Schema 사본이다. 런타임 기준은 `cloudrun-provisioner/` 아래 Schema다. |

## 문서

| 파일 | 용도 |
|---|---|
| `docs/architecture-and-operations.md` | 구성요소 책임 경계, 권한 분리, State 보존 등 운영 아키텍처를 설명한다. |
| `docs/runbook-two-stage.md` | 1차 Foundation과 2차 승인 JSON 기반 배포의 실행 절차를 설명한다. |
| `docs/file-catalog.md` | 이 파일이다. 저장소의 추적 파일별 역할을 정리한다. |

## 보조 스크립트

| 파일 | 용도 |
|---|---|
| `scripts/group_upsert.py` | 승인 JSON의 Group과 구성원을 Google Workspace Directory API로 생성·동기화한다. |
| `scripts/preflight-instance-son.sh` | `instance-son` VM의 gcloud, Terraform, 로그인·프로젝트 기본 상태를 사전 점검한다. |
| `scripts/prepare_lb_bundle.py` | GKE에서 확인한 NEG 등 정보를 Load Balancer 단계 Bundle 변수로 준비한다. |
| `scripts/publish-sandbox-source.sh` | `terraform/02-sandbox/deployments`를 버전 ZIP으로 만들어 Bundle GCS의 `platform-releases/`에 게시하고 generation/SHA256을 출력한다. |
| `scripts/render_jupyter_values.py` | 승인 요청 값을 JupyterHub Helm values 파일로 렌더링한다. |
| `scripts/run_infra_manager.sh` | 단계별 ZIP과 Service Account를 받아 Infrastructure Manager Deployment 적용을 보조한다. |
| `scripts/write_kubeconfig.py` | GKE 작업 컨테이너가 사용할 제한된 kubeconfig를 생성한다. |

## 00-admin: 관리자 전용 영역

| 파일 | 용도 |
|---|---|
| `terraform/00-admin/README.md` | 관리자 Terraform 영역의 목적과 하위 Root 설명이다. |
| `terraform/00-admin/network-host/README.md` | Network Host 관리자 Root의 안내 자리 문서다. |
| `terraform/00-admin/state-gcs/README.md` | 원격 Terraform State GCS 관리 원칙을 설명한다. |
| `terraform/00-admin/iam/README.md` | 교차 프로젝트·Folder IAM Bootstrap, 실행 계정, 독립 State Prefix, 사전점검 절차를 설명한다. |
| `terraform/00-admin/iam/main.tf` | Cloud Run, Workflow, Project Factory, Network Admin, Foundation 실행 계정에 필요한 Project/Folder/Subnet IAM Binding을 조건부로 관리한다. |
| `terraform/00-admin/iam/variables.tf` | IAM 대상 Project·Folder, 서비스 계정, 안전 게이트 및 역할 목록 입력값을 정의한다. |
| `terraform/00-admin/iam/outputs.tf` | 실제 활성 IAM 범위와 서비스 계정 식별자를 출력한다. |
| `terraform/00-admin/iam/providers.tf` | Google Provider 선언이다. |
| `terraform/00-admin/iam/versions.tf` | Terraform 및 Google Provider 버전을 고정한다. |
| `terraform/00-admin/iam/terraform.tfvars.example` | IAM Root의 기본 안전값 예시다. 실제 적용 파일로 복사하지 않고 Git 프로필을 우선 사용한다. |
| `terraform/00-admin/iam/cleanup-disabled-iam-state.sh` | 비활성화된 IAM Resource 주소를 실제 IAM 삭제 없이 Terraform State에서만 정리하고 백업한다. |
| `terraform/00-admin/iam/preflight-admin-profile.sh` | 선택한 IAM 프로필의 대상 Project/Folder IAM Policy 조회 가능 여부를 검사한다. |
| `terraform/00-admin/iam/foundation-bootstrap.admin.tfvars` | CI/CD 영역과 Foundation 실행 계정의 초기 GKE/Subnet 권한용 관리자 프로필이다. |
| `terraform/00-admin/iam/foundation-gke-project.admin.tfvars` | `pjt-d-host01` GKE Project의 관리자 IAM 적용 프로필이다. |
| `terraform/00-admin/iam/foundation-shared-vpc.admin.tfvars` | Shared VPC Host 및 Folder XPN Admin 권한 적용 프로필이다. |
| `terraform/00-admin/iam/sandbox-existing-project.admin.tfvars` | 기존 `pjt-net-hub-base`에서 Project Factory 권한을 주는 프로필이다. |
| `terraform/00-admin/iam/sandbox-network-host.admin.tfvars` | Host Project에서 Network Admin/Firewall 권한을 주는 프로필이다. |
| `terraform/00-admin/iam/sandbox-network-xpn.admin.tfvars` | Folder 범위의 `roles/compute.xpnAdmin`을 주는 프로필이다. |

## 00-network-host: Shared VPC Host 네트워크

| 파일 | 용도 |
|---|---|
| `terraform/00-network-host/README.md` | Shared VPC Host 네트워크 Root의 적용 범위와 실행 안내다. |
| `terraform/00-network-host/main.tf` | Shared VPC, Subnet, secondary range, 방화벽, Cloud Run·Private Pool 관련 네트워크 자원을 정의한다. |
| `terraform/00-network-host/variables.tf` | Network 이름, CIDR, Subnet/secondary range, 생성 게이트 입력값을 정의한다. |
| `terraform/00-network-host/outputs.tf` | 생성된 Network, Subnet, self link, range 이름을 출력한다. |
| `terraform/00-network-host/providers.tf` | Google Provider 선언이다. |
| `terraform/00-network-host/versions.tf` | Terraform·Provider 버전 제약이다. |
| `terraform/00-network-host/terraform.tfvars.example` | 네트워크 입력값 예시다. |
| `terraform/00-network-host/zz-network-safe.auto.tfvars` | 기본 실행에서 위험한 변경을 막는 Network 안전 게이트다. |

## 01-foundation: 공통 실행 기반

| 파일 | 용도 |
|---|---|
| `terraform/01-foundation/apis.tf` | 필요한 Google API를 활성화하고 API 의존 순서를 관리한다. |
| `terraform/01-foundation/artifact_registry.tf` | Cloud Run·자동화 이미지를 저장할 Artifact Registry와 필요한 Writer IAM을 만든다. |
| `terraform/01-foundation/backend.tf` | GCS Remote Backend 선언이다. 실제 bucket/prefix는 `terraform init`에서 지정한다. |
| `terraform/01-foundation/cloudbuild.tf` | Automation/Provisioner 이미지 Build, Private Worker Pool, Cloud Build Trigger를 관리한다. |
| `terraform/01-foundation/cloudrun.tf` | 승인 요청을 수신하는 Cloud Run Provisioner와 Direct VPC·IAM 설정을 관리한다. |
| `terraform/01-foundation/foundation-cost-stop.tfvars` | GKE·Cloud Run·Workflow만 비용중지 대상으로 만드는 Git 관리 프로필이다. |
| `terraform/01-foundation/gke.tf` | Main Jupyter GKE와 CI/CD Test GKE Autopilot Cluster를 조건부로 관리한다. |
| `terraform/01-foundation/import-existing-service-accounts.sh` | 이미 존재하는 자동화 Service Account를 Terraform State에 import한다. 실제 SA를 생성·삭제하지 않는다. |
| `terraform/01-foundation/migrations.tf` | 이전 Terraform 주소에서 현재 주소로 State를 이동해 불필요한 재생성·삭제를 막는다. |
| `terraform/01-foundation/outputs.tf` | Cluster, Cloud Run, Workflow, Bucket, Pool, 자동화 SA 등 핵심 결과를 출력한다. |
| `terraform/01-foundation/providers.tf` | Google 및 Google Beta Provider 설정이다. |
| `terraform/01-foundation/request_buckets.tf` | 승인 요청 JSON과 생성된 Bundle을 저장하는 GCS Bucket 및 접근 권한을 관리한다. |
| `terraform/01-foundation/secrets.tf` | Cloud Run/Jupyter 자동화가 참조할 Secret Manager Secret의 컨테이너·IAM을 관리한다. 비밀값 자체는 저장하지 않는다. |
| `terraform/01-foundation/service_accounts.tf` | Project Factory, Network, Data, GKE, LB, Workflow 등 단계별 자동화 Service Account와 IAM을 정의한다. |
| `terraform/01-foundation/state_bucket.tf` | Foundation Terraform Remote State용 GCS Bucket과 보호 설정을 관리한다. |
| `terraform/01-foundation/terraform.tfvars.example` | Foundation 입력값과 생성 게이트의 예시다. |
| `terraform/01-foundation/variables.tf` | Project/Network/GKE 이름, CIDR, Feature Gate, Bucket, GitHub, Chart 등 Foundation 입력 변수다. |
| `terraform/01-foundation/versions.tf` | Terraform 및 Provider 버전을 고정한다. |
| `terraform/01-foundation/workflow.tf` | GCS 승인 요청을 Cloud Run Provisioner로 전달하는 Workflows 리소스와 실행 IAM을 관리한다. |
| `terraform/01-foundation/zz-foundation-safe.auto.tfvars` | 기본 실행에서 GKE·Cloud Run 변경을 명시적으로 제어하는 안전 기본값이다. |

## 02-sandbox: Infrastructure Manager 단계별 Root

| 파일 | 용도 |
|---|---|
| `terraform/02-sandbox/README.md` | 각 단계가 독립 Infrastructure Manager State라는 점과 기존 Data 자원 채택 방식을 설명한다. |
| `terraform/02-sandbox/deployments/10-project/main.tf` | 승인 값에 따라 신규 프로젝트 생성 또는 기존 프로젝트 조회, Billing/Folder/API 준비를 수행한다. |
| `terraform/02-sandbox/deployments/10-project/variables.tf` | Project 생성 여부, Project ID/이름, Folder, Billing, Region 입력값이다. |
| `terraform/02-sandbox/deployments/10-project/versions.tf` | 10-project Root의 Terraform·Provider 버전 제약이다. |
| `terraform/02-sandbox/deployments/20-network/main.tf` | 승인된 Subnet 생성 또는 기존 Subnet 조회와 Shared VPC Service Project 연결을 수행한다. |
| `terraform/02-sandbox/deployments/20-network/variables.tf` | Host/Service Project, Network, Region, Subnet, CIDR, Join 여부 입력값이다. |
| `terraform/02-sandbox/deployments/20-network/versions.tf` | 20-network Root의 Terraform·Provider 버전 제약이다. |
| `terraform/02-sandbox/deployments/30-project-iam/main.tf` | 승인 Group에 Sandbox Project 접근 IAM을 부여한다. |
| `terraform/02-sandbox/deployments/30-project-iam/variables.tf` | Project ID와 Group 이메일 입력값이다. |
| `terraform/02-sandbox/deployments/30-project-iam/versions.tf` | 30-project-iam Root의 Terraform·Provider 버전 제약이다. |
| `terraform/02-sandbox/deployments/40-data/main.tf` | Jupyter GSA, BigQuery Dataset 및 IAM, GCS Bucket 및 IAM, Workload Identity Binding을 정의한다. |
| `terraform/02-sandbox/deployments/40-data/variables.tf` | Data Project/Region/과제/Group/Dataset/Bucket/GKE Namespace·KSA 입력값이다. |
| `terraform/02-sandbox/deployments/40-data/versions.tf` | 40-data Root의 Terraform·Provider 버전 제약이다. |
| `terraform/02-sandbox/deployments/50-gke-jupyter/main.tf` | GKE Namespace, KSA, Role/RoleBinding, ResourceQuota, NetworkPolicy 등 Jupyter 실행 경계를 정의한다. |
| `terraform/02-sandbox/deployments/50-gke-jupyter/variables.tf` | GKE Project/Cluster/Location, Namespace, 과제·Group, Jupyter KSA/GSA 입력값이다. |
| `terraform/02-sandbox/deployments/50-gke-jupyter/versions.tf` | Kubernetes·Google Provider를 포함한 50-gke-jupyter Root의 버전 제약이다. |
| `terraform/02-sandbox/deployments/60-loadbalancer/main.tf` | Jupyter 서비스의 NEG를 Backend로 사용해 HTTPS Load Balancer, URL Map, 인증서·Frontend 구성을 만든다. |
| `terraform/02-sandbox/deployments/60-loadbalancer/variables.tf` | GKE Project, 과제명, Jupyter 도메인, NEG self link 입력값이다. |
| `terraform/02-sandbox/deployments/60-loadbalancer/versions.tf` | 60-loadbalancer Root의 Terraform·Provider 버전 제약이다. |

## 파일 사용 시 주의

1. `*.tfvars.example`은 참고용이며, 운영값을 로컬 파일에 덮어쓰지 않는다.
2. `*.admin.tfvars`와 `foundation-cost-stop.tfvars`는 Git에서 관리되는 목적별 프로필이다.
3. `02-sandbox/deployments` 하위 Root를 VM에서 직접 `terraform apply`하지 않는다.
   Cloud Run이 요청별 ZIP으로 만들어 Infrastructure Manager가 각자 State를 관리한다.
4. `terraform apply` 전에는 항상 새 Plan을 만들고 `terraform show -no-color`로 삭제 대상부터 확인한다.
