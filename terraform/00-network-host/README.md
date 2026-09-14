# Existing Shared VPC compatibility root

이 Root Module은 기존 `network-host` Terraform State를 안전하게 유지하기 위한 호환 영역입니다.
이미 관리 중인 Subnet, PSA, 방화벽을 새 디렉터리로 단순 이동하면 Terraform이 삭제/재생성으로 판단할 수 있으므로 파일과 Resource Address를 유지합니다.

- 기존 State를 연결한 상태에서 `terraform plan` 결과가 `No changes`인지 먼저 확인합니다.
- 신규 과제 Subnet과 Shared VPC Service Project 연결은 `02-sandbox/deployments/20-network`가 담당합니다.
- `subnet-sbx01-an3`을 이 State에서 분리하려면 운영 중에 파일을 삭제하지 말고 `terraform state rm`과 Infrastructure Manager import를 별도 변경 작업으로 수행합니다.
- 이 Root Module은 Cloud Run 자동화에서 호출하지 않습니다.


## Health Check Firewall 안전 게이트

일반 실행 계정에는 `compute.firewalls.create`가 없으므로 기본값에서는 방화벽을 생성하지 않습니다.

```hcl
enable_firewall_changes      = false
create_health_check_firewall = false
```

기존 로컬 `terraform.tfvars`에 `create_health_check_firewall = true`가 남아 있어도 전역 게이트가 `false`이면 방화벽 Resource 수는 0입니다.

네트워크/보안 관리자가 직접 생성할 때만 다음 두 값을 모두 활성화합니다.

```hcl
enable_firewall_changes      = true
create_health_check_firewall = true
```

소스 변경 후에는 기존 `network.tfplan`을 폐기하고 반드시 새 Plan을 생성해야 합니다.
