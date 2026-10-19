# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Project JIEUN (지은)** — AI-Native Fashion Operating System. "주소는 지우고 취향은 잇다."

Rails 8.1.x 앱. 저장소 이름은 `musinsa_clone`(무신사 클론 프로토타입에서 출발)이지만, **현재 코드베이스는 이미 JIEUN 도메인으로 전환되어 있다.** 커머스 프론트(상품·리뷰·스냅·검색) 위에 재고/발주/익명 CRM 백오피스가 얹힌 구조다.

프로젝트 루트는 이 디렉터리(`musinsa_clone/`)이며, 상위 디렉터리에 `legacy_docs/prd.md`, `legacy_docs/EPIC_STORY.md`가 있다.

---

## ⚠️ 현재 저장소의 알려진 결함 (작업 전 반드시 인지)

기존 3건은 모두 해소되었다.

| 결함 | 해소 커밋·이슈 |
|---|---|
| minitest 6 비호환 | `fff053a` · ISS-001 — `gem "minitest", "~> 5.25"`로 핀 |
| `anony_customers` fixture의 `MyString` UUID 중복 | `fff053a` · ISS-002 — 실제 UUID로 교체 |
| StockAdjuster의 `stock_type`/`user_name` 컬럼 불일치·재고 이중 반영 | ISS-006 — `StockLog.create!`에 `log_type:` 사용, 재고 변경은 콜백으로 일원화 |

CRM Zeitwerk 부팅 오류도 `config/initializers/inflections.rb`의 `inflect.acronym "CRM"`으로 해소되었다(ISS-052, `ba5474f`). `bin/rails test`는 전체 실행 가능하며, ISS-066 실측 결과는 181 runs / 0 failures다.

남은 알려진 제약:

- **Kamal 배포 미완(ISS-024)**: 이 맥에는 Docker·`config/master.key`·레지스트리 쓰기 토큰이 없어 배포가 대기 중이다.
- **CI 성공 ≠ 배포**: `.github/workflows/ci.yml`의 "Deploy to Production" 잡은 실제 Kamal 배포가 주석 처리되어 있고, 배포 단계는 `echo` 플레이스홀더다.

---

## Technology Stack

- **Framework**: Rails 8.1.x (`Gemfile`: `~> 8.1.0`, lock: 8.1.4) / Ruby 3.3.10 (`.ruby-version`, rbenv)
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

bin/rails test                                  # 전체
bin/rails test test/models/product_test.rb      # 파일 단위
bin/rails test test/models/product_test.rb:10   # 단일 테스트 (line filtering)
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
`config/deploy.yml`은 서버 `158.247.235.31`, proxy host `musinsa.158.247.235.31.nip.io`, `ssl: false`로 설정되어 있다. 이 맥에는 Docker·`config/master.key`·레지스트리 쓰기 토큰이 없어 Kamal 배포는 미완이며 ISS-024에서 대기 중이다. CI의 "Deploy to Production" 잡도 `echo` 플레이스홀더이므로 CI 성공이 실제 배포를 뜻하지 않는다.

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

재고 변경은 **`StockLog`의 콜백 하나로 일원화되었다(ISS-006).** `Inventory::StockAdjuster`는 재고 조정 과정에서 검증·로그 생성만 수행하고, 직접 재고를 증감하지 않는다.

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
