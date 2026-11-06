# 운영 배포 절차 — 판매재고·거래처 원장·일정·카톡 관리 (2026-11-07)

대상: main `88e7cef` 이후 (ISS-168·169·170·171·172·173, ISS-156 흡수)
운영: https://jieum.158.247.235.31.nip.io (Kamal, 서버 158.247.235.31, 로컬 레지스트리 localhost:5556)

## 0. 이번 배포에 들어가는 것

| 구분 | 내용 |
|---|---|
| 마이그레이션 8개 | 000173 계정 · 000174/175/179 카톡 수집 · 000176 원장(**suppliers 에 account_id·kind 추가, 이름 유니크 변경**) · 000177 일정 · 000178/180 카톡 추출 |
| 동작 변화 | 주문하면 재고가 줄어든다. **재고 0인 옵션은 주문이 거절된다.** |
| 새 화면 | /sales(판매현황), /admin_orders(입금 확인), /workspace/ledger·schedule·kakao·kakao/inbox |
| 새 환경변수 | `ANTHROPIC_API_KEY`(배포 셸 ENV 에서 전달). 없으면 카톡 AI 추출만 꺼지고 나머지는 동작 |
| 꺼진 채로 두는 것 | `SAAS_SIGNUP_ENABLED`(가입 화면 404 유지) |

## 1. 배포 전 점검 (기본 권한 모드 필요 — ssh)

1. **운영 DB 백업** (마이그레이션이 suppliers 를 바꾸므로 되돌리기의 유일한 수단)
   ```bash
   ssh root@158.247.235.31 'C=$(docker ps --format "{{.Names}}" | grep musinsa_clone-web | head -1); \
     docker exec $C sh -c "cd /rails/storage && for f in production*.sqlite3; do sqlite3 \$f \".backup /rails/storage/backup-20261107-\$f\"; done && ls -la /rails/storage | grep backup-20261107"'
   ```
2. **재고 0인 공개 옵션 확인** — 많으면 배포 즉시 그 상품 주문이 막힌다.
   ```bash
   ssh root@158.247.235.31 'C=$(docker ps --format "{{.Names}}" | grep musinsa_clone-web | head -1); \
     docker exec $C bin/rails runner "p=Product.published; v=Variant.where(product: p); puts [v.count, v.where(\"COALESCE(stock,0)=0\").count].inspect"'
   ```
   결과 `[전체, 0재고]` 에서 0재고가 많으면 배포 전에 재고를 입력하거나 대표님 판단을 받는다.
3. 서버 가용 메모리 확인(공용 서버): `ssh root@158.247.235.31 free -m`

## 2. 배포

```bash
colima start                       # 로컬 레지스트리(kamal-docker-registry, 5556) 컨테이너가 떠 있어야 함
cd musinsa_clone
export ANTHROPIC_API_KEY=...       # 값은 대표님 보관처에서. 파일에 쓰지 않는다
bin/kamal deploy
```

## 3. 배포 후 확인

- `curl -s -o /dev/null -w "%{http_code}" https://jieum.158.247.235.31.nip.io/up` → 200
- 관리자 로그인 → /sales, /admin_orders, /workspace/ledger, /workspace/schedule, /workspace/kakao 200
- 손님 주문 1건(테스트 상품) → 재고 1 감소 확인 후 /admin_orders 에서 취소 처리 → 재고 복원 확인
- `bin/kamal app exec 'bin/rails runner "puts ENV[\"ANTHROPIC_API_KEY\"].present?"'` → true

## 4. 되돌리기

1. `bin/kamal rollback <이전 버전>` (이전 이미지로 컨테이너 교체)
2. 마이그레이션은 이전 이미지가 되돌리지 않는다 → **1-1 백업으로 DB 복원** 후 컨테이너 재시작
   (suppliers 이름 유니크·account_id 변경이 이전 코드와 맞지 않을 수 있음)

## 5. 남은 확인

- 카톡 AI 추출 실측: 운영 키로 거래처 방 1개, 실제 대화로 날짜 변환·누락률 확인
- 맥 에이전트(kakao-bridge) 연결: /workspace/kakao 에서 기기 토큰 발급 → 에어에 설치(`agent/install.sh`), 2026-11-07 03시 실측 결과 반영
