# 02-sandbox Infrastructure Manager roots

각 하위 폴더는 독립된 Infrastructure Manager Terraform Root Module입니다.

| 폴더 | 권한 영역 | Deployment 예시 |
|---|---|---|
| `10-project` | 중앙 Project Factory | `im-sbx01-project` |
| `20-network` | Shared VPC 관리자 | `im-sbx01-network` |
| `30-project-iam` | 프로젝트 IAM 관리자 | `im-sbx01-iam` |
| `40-data` | 업무 프로젝트 관리자 | `im-sbx01-data` |
| `50-gke-jupyter` | GKE 관리자 | `im-sbx01-gke-access` |
| `60-loadbalancer` | Load Balancer 관리자 | `im-sbx01-lb` |

이 디렉터리에서 수동 `terraform apply`를 실행하지 않습니다. 승인 JSON을 받은 Cloud Run이 각 Root Module에 `terraform.auto.tfvars.json`을 결합하여 GCS ZIP Bundle을 만들고, Cloud Build가 Infrastructure Manager에 전달합니다.


## 기존 Data 자원 채택과 Terraform 1.5.7 제한

`40-data`는 기존 Sandbox의 Jupyter Service Account와 BigQuery Dataset을 채택할 수 있다.
Terraform import block의 ID는 Infrastructure Manager Terraform 1.5.7에서 Plan/Init 시점에
확정되어야 하므로, Root Module 안에서 `var.project_id` 같은 변수를 import ID로 사용하지
않는다.

승인 JSON의 `data.adopt_existing_resources=true`인 경우 Cloud Run Provisoner가 요청별 Bundle에
리터럴 ID를 가진 `imports.tf`를 생성한다. 따라서 import는 해당 요청의 Infrastructure
Manager Revision State에만 기록되고 Git Root Module은 신규/기존 양쪽에 재사용 가능하다.

현재 자동 채택 범위는 다음 두 자원이다.

- `gsa-jupyter-<task>@<project>.iam.gserviceaccount.com`
- `<project>:<bigquery_dataset>`

GCS Bucket은 실제 존재가 확인된 경우에만 별도 Git 변경으로 채택 대상으로 추가한다.
