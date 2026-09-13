# Shared VPC IAM

Shared VPC 관리자가 Cloud Shell에서 별도 State Prefix로 실행합니다. Cloud Run 서비스 에이전트가 기존 Direct VPC Egress Subnet을 사용할 최소 IAM만 관리합니다.

```bash
terraform init -reconfigure \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=admin/shared-vpc-iam"
terraform plan -out=shared-vpc-iam.tfplan
terraform apply shared-vpc-iam.tfplan
```

이 Root는 Network, Subnet 또는 NAT 자체를 생성·삭제하지 않습니다.
