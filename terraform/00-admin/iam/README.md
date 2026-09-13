# Top-level administrator IAM

최상위 관리자가 실행하는 Terraform Root입니다. 다음 두 영역을 관리합니다.

- Shared VPC의 Cloud Run Direct VPC Egress 권한
- 기존 Sandbox 프로젝트의 Project Factory Bootstrap 권한

`01-foundation` VM 서비스 계정은 다른 업무 프로젝트 IAM을 변경할 수 없으므로,
기존 프로젝트 IAM은 이 Root에서 분리하여 관리합니다.

## 실행

프로젝트 IAM과 Shared VPC IAM을 모두 변경할 수 있는 관리자 계정으로 실행합니다.

```bash
terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=admin/shared-vpc-iam"

terraform plan -out=admin-iam.tfplan
terraform apply "admin-iam.tfplan"
```

이 Root는 프로젝트, Network, Subnet 또는 NAT 자체를 생성하거나 삭제하지 않습니다.
