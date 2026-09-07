# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Project JIEUN (지은)** — AI-Native Fashion Operating System. "주소는 지우고 취향은 잇다."

Rails 7.2 앱. 저장소 이름은 `musinsa_clone`(무신사 클론 프로토타입에서 출발)이지만, **현재 코드베이스는 이미 JIEUN 도메인으로 전환되어 있다.** 커머스 프론트(상품·리뷰·스냅·검색) 위에 재고/발주/익명 CRM 백오피스가 얹힌 구조다.

프로젝트 루트는 이 디렉터리(`musinsa_clone/`)이며, 상위 디렉터리에 `legacy_docs/prd.md`, `legacy_docs/EPIC_STORY.md`가 있다.

---

## ⚠️ 현재 저장소의 알려진 결함 (작업 전 반드시 인지)

아래 3건은 실측으로 확인된 상태다. 관련 영역을 건드리기 전에 먼저 읽을 것.

### 1. 테스트 스위트가 통째로 실행 불가 — minitest 6 비호환
`Gemfile`에 minitest 버전 제약이 없어 **minitest 6.0.1**이 설치되어 있고, Rails 7.2.3의 `line_filtering.rb`와 시그니처가 맞지 않는다. `bin/rails test`가 테스트 실행 전에 크래시한다:

```
line_filtering.rb:7:in `run': wrong number of arguments (given 3, expected 1..2) (ArgumentError)
```

→ `gem "minitest", "~> 5.25"`를 Gemfile에 추가하면 해소된다(실측 확인). **`bin/ci`도 이 단계에서 실패하므로 CI 전체가 막혀 있다.**

### 2. minitest를 고쳐도 전 테스트가 fixture에서 에러 (16/16)
`test/fixtures/anony_customers.yml`이 **Rails 제너레이터 스캐폴딩 그대로**다. `one`/`two` 두 레코드 모두 `uuid: MyString`이라 `anony_customers.uuid` unique 인덱스를 위반한다:

```
ActiveRecord::RecordNotUnique: SQLite3::ConstraintException: UNIQUE constraint failed: anony_customers.uuid
```

`test_helper.rb`가 `fixtures :all`이라 이 파일 하나가 **모든 테스트를 죽인다.** 다른 fixture들도 `MyString` 스캐폴딩이 남아 있는지 함께 확인할 것.

### 3. 입출고 전 경로가 런타임에서 깨짐 — `StockLog` 컬럼 불일치
`Inventory::StockAdjuster`가 `StockLog.create!`에 **존재하지 않는 컬럼**을 넘긴다:

| StockAdjuster가 넘기는 것 | 실제 `stock_logs` 스키마 |
|---|---|
| `stock_type:` | `log_type` (컬럼명 다름) |
| `user_name:` | **컬럼 없음** |

`app/services/inventory/stock_adjuster.rb:59` 부근. `InventoryController#create_stock_in` / `#create_stock_out`이 둘 다 이 서비스를 `stock_type:`으로 호출하므로 **입고·출고 기능 전체가 동작하지 않는다.** 컨트롤러의 `StockLog.new(log_type: "in")`과 `StockLog` 모델의 validation(`log_type`)은 올바른 이름을 쓰고 있어, 서비스 레이어만 어긋난 상태다. 테스트(`test/services/inventory/stock_adjuster_test.rb`)도 `stock_type`을 단언하고 있어 **테스트가 이 버그를 잡지 못한다** — 위 1·2번 때문에 애초에 실행된 적이 없기 때문.

수정 시 서비스·테스트·(필요하면)스키마 중 어디를 정본으로 삼을지 먼저 정할 것. 스키마와 모델과 컨트롤러가 `log_type`으로 일치하므로 **서비스와 테스트를 고치는 쪽이 변경 범위가 작다.**

---

## Technology Stack

- **Framework**: Rails 7.2.3 / Ruby 3.3.0 (rbenv)
- **Database**: SQLite 3 — 멀티 DB (primary / cache / queue / cable), production 포함
- **Solid 스택**: Solid Queue(잡) · Solid Cache(캐시) · Solid Cable(웹소켓) 전부 SQLite 백엔드
- **Frontend**: Hotwire (Turbo + Stimulus) + Tailwind CSS, Importmap
- **Asset Pipeline**: Propshaft
- **Storage**: Active Storage (Product 이미지)
- **Deployment**: Kamal (Docker)
- **Testing**: Minitest + Capybara/Selenium(system) + SimpleCov

---

## Essential Commands

```bash
bin/setup                   # 초기 셋업
bin/dev                     # 개발 서버 (Rails + Tailwind watcher, Procfile.dev)

bin/rails test                                  # 전체 (현재 위 결함 1로 크래시)
bin/rails test test/models/product_test.rb      # 파일 단위
bin/rails test test/models/product_test.rb:10   # 단일 테스트 (line filtering — 결함 1의 크래시 지점)
bin/rails test:system                           # 시스템 테스트 (Capybara)
COVERAGE=1 bin/rails test                       # SimpleCov 커버리지 (최소 80%, 파일별 70% 강제)

bin/rubocop                 # 린트 (rails-omakase 기반)
bin/rubocop -a              # 자동 수정
bin/brakeman                # 정적 보안 분석
bin/bundler-audit           # 취약 gem 점검
bin/ci                      # 전체 CI 파이프라인 (config/ci.rb 정의)
```

### `bin/ci`의 실제 단계 (`config/ci.rb`)
Setup → RuboCop → bundler-audit → importmap audit → Brakeman(`--exit-on-warn`) → `bin/rails test` → `db:seed:replant`.
Brakeman이 **경고에도 실패**하도록 설정되어 있고, seed replant까지 CI에 포함된다는 점에 유의.

### 배포
`config/deploy.yml`의 서버 IP가 아직 **플레이스홀더(`192.168.0.1`)**이고 proxy/SSL 블록도 주석 상태다. Kamal 배포는 미구성이므로 `bin/kamal deploy`를 그대로 실행하면 안 된다.

---

## Architecture

### 도메인 구조 — 두 레이어가 한 앱에 공존

**(A) 커머스 프론트** — 소비자용
`Product` ← `Review`, `Snap`(스타일 피드) ↔ `SnapProduct` 다대다.
컨트롤러: `Home`(랭킹), `Products`, `Search`(카테고리·브랜드·성별 필터), `Snaps`.

**(B) 백오피스 / 운영** — JIEUN 본체
`Product` → `Variant`(SKU) → `StockLog`(입출고 원장) / `Notification`.
`Supplier` → `PurchaseOrder` → `PurchaseOrderItem` (발주, 토큰 기반 거래처 확인 URL).
`AnonyCustomer` → `Order`. `Campaign`(마케팅).
컨트롤러: `Inventory`, `Dashboard`, `Suppliers`, `PurchaseOrders`, `Api::V1::Ucp`.

### 재고의 정본은 `StockLog`이고, `Variant.stock`은 파생값이다
`StockLog`에 `after_create :update_variant_stock` 콜백이 있어 **로그가 생성되면 `Variant.stock`을 자동으로 증감**시킨다(`increment!`/`decrement!`).

⚠️ 그런데 `Inventory::StockAdjuster`는 `adjust_stock`으로 **직접 stock을 조정한 뒤 다시 `StockLog.create!`**를 호출한다. 콜백까지 함께 돌면 **재고가 이중 반영**되는 구조다(현재는 결함 3 때문에 create! 자체가 터져서 표면화되지 않음). 이 영역을 수정할 때는 **조정 주체를 콜백 하나로 일원화**할 것.

### 서비스 레이어 규약 — `ApplicationService`
모든 서비스는 `ApplicationService`를 상속하고 `Result` 객체를 반환한다. 컨트롤러는 절대 예외를 기대하지 않고 `result.success?`로 분기한다.

```ruby
result = Inventory::StockAdjuster.call(barcode:, quantity:, ...)
if result.success?
  redirect_to ..., notice: result.data[:message]
else
  flash.now[:alert] = result.error
  render :stock_in, status: :unprocessable_entity
end
```

- `self.call(*args, **kwargs)` → `new(...).call` 원라이너
- 내부에서 `success(data)` / `failure(error)` (protected) 사용
- 서비스는 `StandardError`를 rescue해 `Rails.logger.error` 후 `failure`로 변환한다 — **새 서비스도 이 패턴을 따를 것**

디렉터리: `app/services/{inventory,crm,claude_bot,notifications}/`

### JSON 컬럼은 `serialize`로 다룬다 (JSONB 아님 — SQLite다)
`Product#ai_attributes`, `Product#badges`, `AnonyCustomer#preference_tags`가 `serialize ..., coder: JSON`이다.

이 때문에 **AI 속성 필터링 scope가 `LIKE` 문자열 매칭**으로 구현되어 있다:
```ruby
scope :by_mood, ->(mood) { where("ai_attributes LIKE ?", "%\"mood\":%\"#{mood}\"%") }
```
인덱스를 타지 않고 SQL 인젝션 표면이 있으므로, 이 scope를 확장할 때는 주의할 것. `Product#parsed_ai_attributes`는 String/Hash 양쪽을 방어적으로 파싱한다(JSON::ParserError → `{}`).

### 바코드 자동 생성
`Variant`의 `before_validation :generate_barcode` (on: create)가 `{PRODUCT_ID}-{COLOR}-{SIZE}` 형식으로 생성하고, 충돌 시 `-1`, `-2` 접미사를 붙인다. `sku_code`도 같은 값으로 채워진다. **바코드를 수동 지정하면 생성 로직은 건너뛴다.**

---

## Privacy-First CRM — 이 프로젝트의 핵심 제약

`AnonyCustomer`는 **개인을 식별할 수 없는 데이터만** 저장한다. 스키마가 이를 강제한다:

| 저장 O | 저장 X (절대 금지) |
|---|---|
| `uuid` (자동 생성) | 상세 주소 |
| `zip_prefix` — 우편번호 **앞 3자리** (`limit: 3`) | 전체 연락처 |
| `phone_suffix` — 연락처 **뒤 4자리** (`limit: 4`) | 전체 이메일 |
| `birth_year`, `preference_tags` | 이름 |

동일인 판별은 `find_or_create_by_identifier(phone_suffix, birth_year)` — 이 조합에 복합 인덱스가 있다.
**CRM 영역에 컬럼을 추가할 때 이 원칙을 깨지 않을 것.** LLM API로 고객 데이터를 보내는 코드를 작성할 때도 동일하게 적용된다.

---

## 커밋 / 코드 스타일

- **Conventional Commits + 한국어 본문.** 기존 이력: `feat: Epic 1 지능형 상품 관리 시스템 구현`, `fix: Production 환경 설정 및 RuboCop 오류 수정`
- 주석·검증 메시지·flash 메시지는 **한국어**로 작성한다 (기존 코드 전반의 관례)
- 모델의 validation/scope에 해당 Story 번호를 주석으로 남기는 관례가 있다 (`# Story 1.3 Acceptance Criteria`)
- RuboCop은 `rails-omakase` 기반 (`.rubocop.yml`)

---

## 참고 문서

- `docs/TESTING_STRATEGY.md`, `docs/SMOKE_TEST_GUIDE.md`, `docs/REBUILD_PLAN.md`, `docs/UPGRADE_SUMMARY.md`, `docs/stories/`
- `SKILL.md` — PM Orchestrator 패턴 (PM은 오케스트레이터, 직접 실행보다 위임·조율)
- `.claude/commands/` — `/test-all`, `/deploy-check`, `/fix-errors`, `/upgrade-plan`
- `../legacy_docs/prd.md`, `../legacy_docs/EPIC_STORY.md`
