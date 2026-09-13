# Top-level administrator changes

이 폴더는 Cloud Run 자동화가 실행하지 않는 최상위 관리자 변경 영역입니다.

| 폴더 | 목적 | 현재 상태 |
|---|---|---|
| `network-host/` | Shared VPC, Subnet, PSA, NAT 변경 경계 | 기존 `../00-network-host` State를 계속 사용 |
| `iam/` | Shared VPC에서 서비스 프로젝트 런타임에 필요한 IAM | 별도 State로 적용 가능 |
| `state-gcs/` | Terraform State GCS bootstrap 경계 | 기존 Foundation State 소유권 유지 |

기존 자원을 새 State로 옮기는 작업은 파일 이동이 아니라 별도 Change Request로 수행합니다. 이전 전에는 같은 자원을 두 Root에서 동시에 관리하지 않습니다.
