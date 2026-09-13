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
