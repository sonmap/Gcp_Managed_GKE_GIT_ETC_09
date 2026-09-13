# Network host boundary

기존 Shared VPC 자원은 현재 `terraform/00-network-host`의 기존 GCS State가 소유합니다. 이 디렉터리는 책임 경계를 표시하며 중복 Terraform Resource를 선언하지 않습니다.

State 분리 시에는 기존 Plan이 `No changes`인지 확인하고, 새 Backend Prefix를 만든 뒤 Resource별 `terraform state mv` 또는 import를 수행합니다.
