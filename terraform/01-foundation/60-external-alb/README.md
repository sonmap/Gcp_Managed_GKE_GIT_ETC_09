# Shared Classic External ALB

현재 PoC는 조직 정책상 `EXTERNAL_MANAGED` 대신 Classic External Application Load Balancer (`EXTERNAL`)를 사용합니다.

현재 구성:

- Global IP: `ip-alb-jupyter-shared` (`8.233.187.128`)
- HTTP proxy: `http-proxy-alb-jupyter-shared`
- HTTP forwarding rule: `fr-alb-jupyter-shared-http` (`80`)
- HTTPS proxy: `https-proxy-alb-jupyter-shared`
- HTTPS forwarding rule: `fr-alb-jupyter-shared-https` (`443`)
- URL map: `urlmap-alb-jupyter-shared`
- Self-managed certificate: `cert-jupyter-sbx01-self`
- Host route: `jupyter-sbx01.sonmap.net -> bes-jupyter-sbx01`

## 인증서 관리 원칙

DNS 상위 위임을 사용할 수 없는 PoC이므로 클라이언트 `hosts` 파일로 이름을 해석하고 self-managed 인증서를 사용합니다. 인증서 PEM과 private key는 Git에 저장하지 않습니다. Terraform은 이미 생성된 Compute SSL certificate resource를 이름으로만 조회합니다.

## 수동 생성된 HTTPS 자원 State 편입

HTTPS proxy와 443 forwarding rule을 `gcloud`로 먼저 생성한 환경에서는 Terraform apply 전에 기존 리소스를 state에 import해야 합니다.

```bash
cd terraform/01-foundation/60-external-alb

terraform init \
  -backend-config="bucket=tfstate-sbx-cicd-236d-40744085720" \
  -backend-config="prefix=foundation/external-alb"

terraform import \
  google_compute_target_https_proxy.jupyter \
  projects/pjt-d-host01/global/targetHttpsProxies/https-proxy-alb-jupyter-shared

terraform import \
  google_compute_global_forwarding_rule.https \
  projects/pjt-d-host01/global/forwardingRules/fr-alb-jupyter-shared-https

terraform plan
```

`terraform plan`에서 기존 HTTPS 자원의 재생성이 아니라 관리 편입 상태인지 확인한 뒤 apply 합니다.
