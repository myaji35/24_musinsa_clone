# 역할별 접근 표 (2026-11-17, 1단계 산출물)

- 기준: `feat/auth-roles` 브랜치(main `5661763`에서 분기)
- 역할 정의: 대표님이 2026-11-17에 3역할을 승인했다.
  - 관리자 `admin`
  - 운영자 `operator`
  - 사용자 `member`
  - 비로그인 손님
- 기호: ○ 허용 · ✕ 막힘
- 막힘 처리는 두 가지다.
  - 비로그인 손님은 로그인 화면으로 보낸다(302 → `/login`).
  - 로그인한 사람은 허용된 첫 화면으로 보내고 경고를 띄운다(302). 사용자는 홈으로, 운영자는 재고관리로 보낸다.

## 1. 먼저 알아야 할 현재 구조와 위험

1. **현재 관리자 판정:** `mall_admin?`은 `account_id`가 없거나 primary account이면 관리자로 본다. 역할 칸은 없다.
2. **위험 (2단계에서 반드시 고친다):** 쇼핑 회원을 `account_id` 없이 만들면 지금 판정대로라면 **관리자가 된다**. 역할 칸을 추가한 뒤에는 관리자 판정을 `role == admin` 하나로 바꾼다. `mall_admin?`은 `admin?`에 위임해 호환만 유지한다.
3. **데이터 이전 규칙:** 지금 `mall_admin?`이 참인 사용자는 `admin`으로 바꾼다. 다른 업체 계정(입점 업체) 사용자는 `member`로 두되, 워크스페이스 접근은 지금처럼 계정 소속으로 판정하므로 영향이 없다.
4. **바꾸지 않는 인증 3가지 (이번 범위 밖, 회귀 확인만 한다):**
   - 입점 업체 워크스페이스 `/workspace*`: `require_account_member`. 계정 소속이면 역할과 무관하게 허용한다.
   - 거래처 포털 `partner/*`: 별도 `SupplierAccount` 세션으로 동작한다.
   - API·웹훅: 토큰·키·장치 인증. `api/v1/ucp`, `api/v1/feedback_exports`, `api/content_uploads`, `api/kakao_bridge`, `webhooks/shopify`가 해당한다.
5. **보류 브랜치:** `hold/ISS-098`은 main과 차이가 0이다. 이미 반영되었으므로 충돌하지 않는다.

## 2. 공개 화면 (모든 역할 ○, 지금처럼 `skip_before_action :require_admin`)

| 컨트롤러#액션 | 손님 | 사용자 | 운영자 | 관리자 |
|---|---|---|---|---|
| home#index, search#index, products#index·show | ○ | ○ | ○ | ○ |
| snaps#index·show, magazine#index·show, characters#show | ○ | ○ | ○ | ○ |
| carts, cart_items, checkouts | ○ | ○ | ○ | ○ |
| customer_orders#lookup·verify·show (비회원 주문조회) | ○ | ○ | ○ | ○ |
| policies (약관·개인정보·반품) | ○ | ○ | ○ | ○ |
| feedbacks#new·create | ○ | ○ | ○ | ○ |
| purchase_orders#confirm (거래처 확인용 토큰 주소) | ○ | ○ | ○ | ○ |
| sessions#new·create·destroy | ○ | ○ | ○ | ○ |

※ 상품 공개 여부는 그대로 둔다. 공개되지 않은 상품은 관리자와 운영자에게만 보인다(지금은 `mall_admin?`만 볼 수 있다). 3단계부터는 `staff?`(관리자 또는 운영자)로 판정한다.

## 3. 새로 만드는 화면

| 화면 | 손님 | 사용자 | 운영자 | 관리자 |
|---|---|---|---|---|
| 회원가입 `GET/POST /join` (쇼핑 회원, role=member 고정) | ○ | ✕(이미 로그인 상태) | ✕ | ✕ |
| 내 정보 `GET /my` · 내 주문 `GET /my/orders` | ✕ | ○ | ○ | ○ |
| 사용자·역할 관리 `/admin/users` (목록·역할 변경) | ✕ | ✕ | ✕ | ○ |

- 기존 `/signup`(입점 업체 계정 가입, `SAAS_SIGNUP_ENABLED`가 켜져 있을 때만 동작)은 그대로 둔다. 쇼핑 회원 가입은 경로를 분리해 `/join`으로 만든다.
- 회원 주문은 지금 `Order`에 사용자 연결이 없다. 4단계에서는 내 주문 화면을 안내 문구(빈 상태)로 만들고, 주문 연결은 별도 이슈로 분리한다. 개인정보 원칙상 `AnonyCustomer`는 건드리지 않는다.

## 4. 운영 화면 (관리자·운영자)

| 컨트롤러 | 액션 | 손님 | 사용자 | 운영자 | 관리자 |
|---|---|---|---|---|---|
| inventory | scan·stock_in·create_stock_in·stock_out·create_stock_out·history | ✕ | ✕ | ○ | ○ |
| admin_orders | index·confirm_payment | ✕ | ✕ | ○ | ○ |
| dashboard | index·regional_trends·preference_analysis 등 | ✕ | ✕ | ○ | ○ |
| purchase_orders | index·show·new·create·edit·update·submit·receive | ✕ | ✕ | ○ | ○ |
| purchase_orders | destroy | ✕ | ✕ | ✕ | ○ |
| supplier_claims | index·new·create·show·resolve | ✕ | ✕ | ○ | ○ |
| supplier_imports | index·new·create·show·retry | ✕ | ✕ | ○ | ○ |
| suppliers | index·show | ✕ | ✕ | ○ | ○ |
| suppliers | new·create·edit·update·destroy | ✕ | ✕ | ✕ | ○ |
| products | new·create·edit·update·publish·unpublish | ✕ | ✕ | ○ | ○ |
| products | destroy | ✕ | ✕ | ✕ | ○ |
| product_specs, product_info_notices, product_cutouts, model_picks | 전체 | ✕ | ✕ | ○ | ○ |

## 5. 관리자 전용

| 컨트롤러 | 이유 |
|---|---|
| kpi, sales | 매출·KPI는 경영 정보다. |
| trends, product_analyses | AI 분석을 실행한다(유료 API를 호출할 수 있다). |
| supplier_accounts#create·toggle | 거래처 포털 계정을 발급하고 정지한다(권한 발급에 해당). |
| reviews#create | 지금도 관리자 전용인 시드용 입력이다. 그대로 둔다. |
| admin/users (신규) | 역할을 바꾸는 화면이다. |

※ 운영자 범위에서 "상품 편집은 허용, 상품 삭제는 막음"은 내가 판단해 정했다(T0). 대표님 승인 표에서 상품 편집은 재고·주문 담당 업무에 속하고, 삭제는 되돌릴 수 없기 때문이다.

## 6. 메뉴 노출 (5단계에서 적용, 데스크톱 73~79줄·모바일 124~130줄)

| 메뉴 | 손님 | 사용자 | 운영자 | 관리자 |
|---|---|---|---|---|
| 로그인 · 회원가입 | ○ | | | |
| 내 정보 · 로그아웃 | | ○ | ○ | ○ |
| 재고관리 · 대시보드 · 주문 관리 · 발주 · 클레임 · 상품 입고(엑셀) | | | ○ | ○ |
| 거래처 (운영자는 조회만) | | | ○ | ○ |
| 사용자 관리 · KPI · 매출 | | | | ○ |
| 내 워크스페이스 (입점 업체 계정 소속일 때) | 지금과 같음 | | | |

## 7. 검증 방법 (3단계 요청 테스트, 6단계 브라우저)

- 이 표의 ○·✕ 칸마다 요청 테스트를 1개씩 만든다. 응답 코드와 이동한 주소를 함께 확인한다.
- 역할 올리기 공격도 테스트한다.
  - `POST /join`에 `role=admin`을 섞어 보낸다 → 가입은 되지만 role은 member여야 한다.
  - 운영자가 `PATCH /admin/users/:id`를 보낸다 → 막혀야 한다.
- 다음 회귀를 확인한다.
  - 기존 관리자 fixture(`users(:one)`, primary account `jieum`)는 admin으로 이전되어 지금과 같이 동작해야 한다.
  - 다른 계정 사용자(`users(:other)`)는 워크스페이스만 쓸 수 있어야 한다.
