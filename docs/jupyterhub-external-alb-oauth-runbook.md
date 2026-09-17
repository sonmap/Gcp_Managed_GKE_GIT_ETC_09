# JupyterHub External ALB + Google OAuth PoC Runbook

이 문서는 `sbx01`에서 실제 접속 성공까지 확인한 설정을 Git 기준으로 정리합니다.

## 최종 접속 경로

```text
Windows hosts
  jupyter-sbx01.sonmap.net -> 8.233.187.128
        |
        v
Classic External ALB HTTPS :443
        |
        v
urlmap-alb-jupyter-shared
        |
        v
bes-jupyter-sbx01
        |
        v
GKE standalone NEG
        |
        v
proxy-public / configurable-http-proxy :8000
        |
        v
JupyterHub
        |
        v
user Notebook Pod
```

DNS 상위 `sonmap.net` NS 위임을 사용할 수 없으므로 PoC 클라이언트는 Windows `hosts` 파일을 사용합니다.

```text
8.233.187.128 jupyter-sbx01.sonmap.net
```

## HTTPS

Public DNS 검증을 사용할 수 없으므로 Google-managed certificate 대신 self-managed certificate를 사용합니다.

Compute SSL certificate resource:

```text
cert-jupyter-sbx01-self
```

인증서 PEM/private key는 Git에 저장하지 않습니다. 클라이언트 Windows에는 테스트 인증서를 Trusted Root에 설치해야 합니다.

```powershell
Import-Certificate `
  -FilePath "C:\Temp\jupyter-sbx01.crt" `
  -CertStoreLocation "Cert:\LocalMachine\Root"
```

HTTPS frontend:

```text
https-proxy-alb-jupyter-shared
fr-alb-jupyter-shared-https :443
```

## Google OAuth

Google Auth Platform Web application에 다음 값을 등록합니다.

Authorized JavaScript origin:

```text
https://jupyter-sbx01.sonmap.net
```

Authorized redirect URI:

```text
https://jupyter-sbx01.sonmap.net/hub/oauth_callback
```

OAuth Client ID/Client Secret 값은 Git에 저장하지 않고 Secret Manager의 latest version을 JupyterHub 배포 시 읽습니다.

```text
jupyter-oauth-client-id
jupyter-oauth-client-secret
```

Secret 입력은 다음 스크립트를 사용합니다.

```bash
scripts/set-jupyter-oauth-secrets.sh
```

Secret rotation 시에는 새 secret을 먼저 활성화하고 JupyterHub에 반영한 뒤 기존 secret을 disable/delete 합니다.

## 사용자 이름과 allowed_users

Google Workspace 계정은 전체 email 주소를 JupyterHub username으로 유지합니다.

```yaml
GoogleOAuthenticator:
  hosted_domain:
    - sonmap.net
  strip_domain: false
```

이 설정이 없으면 `user01@sonmap.net`이 내부적으로 `user01`로 변환되어 다음과 같은 403이 발생할 수 있습니다.

```text
Sorry, you are not currently authorized to use this hub.
```

허용 사용자는 request의 `identity.members`를 사용합니다.

```text
user01@sonmap.net
user02@sonmap.net
```

## GKE Autopilot Notebook Pod

JupyterHub chart의 기본 `block-cloud-metadata` init container는 privileged + `NET_ADMIN`을 요구하므로 Autopilot Warden에서 거부됩니다.

따라서 다음 값을 사용합니다.

```yaml
singleuser:
  cloudMetadata:
    blockWithIptables: false
  networkPolicy:
    enabled: true
    egressAllowRules:
      cloudMetadataServer: true
```

사용자 Notebook Pod는 지정 KSA로 실행하며 GKE Metadata Server를 통해 Workload Identity/ADC를 사용합니다.

```text
Notebook Pod
  -> KSA ksa-jupyter-sbx01
  -> GKE Metadata Server
  -> Workload Identity
  -> GSA
  -> BigQuery / GCS
```

## NEG 생성 순서

Standalone NEG를 Helm `--wait` 중에 먼저 연결하면 NEG readiness gate와 아직 생성되지 않은 Backend Service 사이에 순환 대기가 생길 수 있습니다.

현재 순서는 다음과 같습니다.

1. JupyterHub Helm install/upgrade 완료
2. `proxy-public` Service에 auto-generated NEG annotation 추가
3. `ServiceNetworkEndpointGroup`의 `Synced=True` 대기
4. `cloud.google.com/neg-status`에서 현재 cluster의 NEG 이름/zone 확인
5. `neg_self_links`를 load balancer bundle에 반영
6. sandbox Backend Service 적용

NEG 이름은 고정하지 않습니다.

```json
{"exposed_ports":{"80":{}}}
```

따라서 cluster 재생성 후 과거 `neg-jupyter-sbx01` 같은 stale NEG 이름과 충돌하지 않습니다.

## Health Check

Backend health check는 JupyterHub Hub endpoint가 아니라 configurable-http-proxy의 native health endpoint를 사용합니다.

```text
/_chp_healthz
```

Health checker source ranges:

```text
35.191.0.0/16
130.211.0.0/22
```

Backend endpoint port:

```text
TCP/8000
```

Shared VPC host의 관리 대상 firewall 이름:

```text
fw-allow-jupyter-alb-hc
```

Autopilot node tag는 cluster 재생성 시 바뀔 수 있으므로 Git의 Terraform 정의는 node tag가 아니라 main Pod CIDR을 destination range로 사용합니다.

## 검증 명령

Pod 상태:

```bash
kubectl -n sbx01 get pods -o wide
```

사용자 Pod KSA:

```bash
POD="$(kubectl -n sbx01 get pod -o name | grep user01 | head -1)"
kubectl -n sbx01 get "$POD" -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

OAuth 오류 확인:

```bash
kubectl -n sbx01 logs deploy/hub --since=10m | \
  egrep -i 'oauth|error|401|403|400|callback|state'
```

Backend health:

```bash
gcloud compute backend-services get-health bes-jupyter-sbx01 \
  --project=pjt-d-host01 \
  --global
```

HTTPS 확인:

```powershell
curl.exe -I https://jupyter-sbx01.sonmap.net
```

`curl -I`는 HEAD 요청이므로 JupyterHub가 `405 Method Not Allowed`를 반환해도 ALB/JupyterHub까지 도달했다는 의미일 수 있습니다. 실제 브라우저/GET 접속으로 최종 확인합니다.

## Secret 보안

OAuth client secret, 인증서 private key, Secret Manager 실제 payload는 Git commit 대상이 아닙니다. 노출된 OAuth client secret은 Google Auth Platform에서 rotate 후 disable/delete 합니다.
