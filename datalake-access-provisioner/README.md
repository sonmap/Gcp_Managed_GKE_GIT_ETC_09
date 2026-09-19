# Data Lake BigQuery Access Provisioner

`pjt-c-admin`의 BigQuery Data Lake Dataset에 Sandbox 과제의 **GSA / User / Group 조회 권한**을 별도 자동화로 부여하거나 회수합니다.

기존 Sandbox Terraform/Cloud Run과 독립적으로 동작하며, **Cloud Scheduler가 5분마다 private Cloud Run을 호출**하여 GCS `pending/` 요청을 처리합니다.

## 구성

```text
사내 포털 / 관리자
        |
        | 승인 JSON 업로드
        v
GCS: gs://prj-b-cicd-local-236d-datalake-access-requests/pending/
        |
        | 5분마다 Poll
        v
Cloud Scheduler
  datalake-access-provisioner-5m
        |
        | OIDC
        v
Cloud Run (private)
  datalake-access-provisioner
        |
        | Dataset ACL GRANT / REVOKE
        v
pjt-c-admin / BigQuery Dataset
        |
        +-- GSA   -> READER
        +-- User  -> READER
        +-- Group -> READER

결과:
GCS .../results/*.result.json
```

## 중요 원칙

- Data Lake 대상 프로젝트는 `pjt-c-admin`으로 고정합니다.
- 입력 Role은 `roles/bigquery.dataViewer`만 허용합니다.
- BigQuery Dataset ACL에서는 위 Role을 `READER`로 반영합니다.
- 기존 Dataset ACL은 유지하고 요청한 Principal만 추가/회수합니다.
- `roles/bigquery.jobUser`는 이 서비스에서 부여하지 않습니다. Query Job 실행 권한은 기존 Sandbox Job Project에서 별도 통제합니다.
- Cloud Run은 공개하지 않으며 Scheduler SA만 `roles/run.invoker`를 가집니다.
- 처리 결과는 GCS `results/`에 요청 Object Generation별로 기록되므로 5분마다 다시 호출되어도 동일 Generation은 재처리하지 않습니다.
- 실패 요청을 수정해서 다시 처리하려면 같은 `pending/*.json`을 새 Generation으로 업로드하면 됩니다.

## 파일

```text
datalake-access-provisioner/
├─ main.py
├─ requirements.txt
├─ Dockerfile
├─ deploy-gcloud.sh
└─ examples/
   └─ request-sbx01.json
```

## 요청 JSON

예시:

```json
{
  "request_id": "DLK-REQ-20260919-001",
  "action": "GRANT",
  "task": "sbx01",
  "data_project": "pjt-c-admin",
  "datasets": [
    "dlk_customer",
    "dlk_sales"
  ],
  "principals": {
    "serviceAccounts": [
      "gsa-jupyter-sbx01@pjt-net-hub-base.iam.gserviceaccount.com"
    ],
    "users": [
      "user01@sonmap.net",
      "user02@sonmap.net"
    ],
    "groups": [
      "pgrp-gcp-dev-sbx01@sonmap.net"
    ]
  },
  "role": "roles/bigquery.dataViewer",
  "approved": true
}
```

회수할 때는 `action`만 `REVOKE`로 변경하고 **새 request_id** 또는 새 Object Generation으로 업로드합니다.

## 1. 최초 배포

`instance-son`에서 Git 최신화 후 실행합니다.

```bash
cd ~/Gcp_Managed_GKE_GIT_ETC_09
git pull --ff-only origin main

cd datalake-access-provisioner
./deploy-gcloud.sh
```

기본 생성값:

| 항목 | 값 |
|---|---|
| Cloud Run | `datalake-access-provisioner` |
| Runtime SA | `sa-datalake-access-admin@prj-b-cicd-local-236d.iam.gserviceaccount.com` |
| Scheduler SA | `sa-datalake-scheduler@prj-b-cicd-local-236d.iam.gserviceaccount.com` |
| Scheduler | `datalake-access-provisioner-5m` |
| 주기 | `*/5 * * * *` = 5분마다 |
| Timezone | `Asia/Seoul` |
| Request Bucket | `gs://prj-b-cicd-local-236d-datalake-access-requests` |
| Data Project | `pjt-c-admin` |

Cloud Run Runtime SA에는 `pjt-c-admin`에서 다음 두 Permission만 가진 Custom Role을 생성해 부여합니다.

```text
bigquery.datasets.get
bigquery.datasets.update
```

GCS에는 Runtime SA에 `roles/storage.objectViewer` + `roles/storage.objectCreator`만 부여합니다.

> `deploy-gcloud.sh` 실행 계정은 Service Account 생성/IAM 변경/Cloud Run/Cloud Scheduler/Cloud Build/Artifact Registry 작업 권한과 Scheduler OIDC SA에 대한 `iam.serviceAccounts.actAs` 권한이 있어야 합니다.

## 2. 요청 업로드

Dataset 이름을 실제 Data Lake Dataset으로 수정한 후 업로드합니다.

```bash
REQUEST_BUCKET=prj-b-cicd-local-236d-datalake-access-requests

gcloud storage cp examples/request-sbx01.json \
  "gs://${REQUEST_BUCKET}/pending/request-sbx01.json"
```

다음 5분 Scheduler 실행에서 처리됩니다.

## 3. 즉시 테스트

5분을 기다리지 않고 Scheduler를 즉시 실행하려면:

```bash
gcloud scheduler jobs run datalake-access-provisioner-5m \
  --project=prj-b-cicd-local-236d \
  --location=asia-northeast3
```

결과 확인:

```bash
gcloud storage ls \
  gs://prj-b-cicd-local-236d-datalake-access-requests/results/

gcloud storage cat \
  'gs://prj-b-cicd-local-236d-datalake-access-requests/results/*.result.json'
```

Cloud Run 로그:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" resource.labels.service_name="datalake-access-provisioner"' \
  --project=prj-b-cicd-local-236d \
  --limit=50 \
  --format='value(timestamp,severity,textPayload,jsonPayload.message)'
```

## 4. Scheduler 확인

```bash
gcloud scheduler jobs describe datalake-access-provisioner-5m \
  --project=prj-b-cicd-local-236d \
  --location=asia-northeast3 \
  --format='yaml(name,schedule,timeZone,state,httpTarget.uri)'
```

정상 기준:

```text
schedule: */5 * * * *
timeZone: Asia/Seoul
state: ENABLED
```

## 5. BigQuery Dataset 권한 확인

```bash
bq show --format=prettyjson pjt-c-admin:dlk_customer | jq '.access'
```

GSA/User는 `userByEmail`, Group은 `groupByEmail`, 조회 권한은 `READER`로 보이면 정상입니다.
