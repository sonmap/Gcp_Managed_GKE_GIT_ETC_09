# Terraform State GCS boundary

State Bucket `tfstate-sbx-cicd-236d-40744085720`은 이미 생성되어 Foundation State에 등록되어 있습니다. Backend가 사용하는 Bucket을 같은 실행에서 새로 만들 수 없으므로 이번 변경에서는 중복 Resource를 만들지 않습니다.

향후 별도 State로 이전할 때는 다음 순서를 사용합니다.

1. Bucket 삭제 방지와 Versioning을 확인합니다.
2. Foundation State에서 Bucket Resource를 제거하되 실제 Bucket은 보존합니다.
3. 이 관리자 영역의 별도 Backend/State로 import합니다.
4. 두 State의 Plan에서 Bucket 생성·삭제가 없음을 확인합니다.
