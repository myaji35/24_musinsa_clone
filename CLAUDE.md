# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Project JIEUN (지은)** - AI-Native Fashion Operating System

"주소는 지우고 취향은 잇다." AI 에이전트(ClaudeBot)와 공존하는 차세대 의류 운영 솔루션.

현재 저장소는 **musinsa_clone**으로, JIEUN의 MVP 구축을 위한 Rails 7.2 기반 패션 커머스 프로토타입입니다.

---

## Technology Stack

- **Framework**: Ruby on Rails 7.2
- **Database**: SQLite 3 (multi-database configuration for production)
  - Primary DB: `storage/production.sqlite3`
  - Cache DB: `storage/production_cache.sqlite3`
  - Queue DB: `storage/production_queue.sqlite3`
  - Cable DB: `storage/production_cable.sqlite3`
- **Background Jobs**: Solid Queue (SQLite-backed)
- **Caching**: Solid Cache (SQLite-backed)
- **WebSocket**: Solid Cable (SQLite-backed)
- **Frontend**: Hotwire (Turbo + Stimulus) + Tailwind CSS
- **Asset Pipeline**: Propshaft
- **Deployment**: Kamal (Docker-based)
- **Testing**: Minitest (Rails default)

---

## Essential Commands

### Development

```bash
# Setup
bin/setup                  # Initial setup (bundle install, db setup)

# Run development server
bin/dev                    # Runs both Rails server and Tailwind watcher (Procfile.dev)
bin/rails server           # Rails server only
bin/rails tailwindcss:watch # Tailwind CSS watcher only

# Database
bin/rails db:create        # Create database
bin/rails db:migrate       # Run migrations
bin/rails db:seed          # Seed sample data
bin/rails db:reset         # Drop, create, migrate, and seed
bin/rails db:schema:load   # Load schema without running migrations
```

### Testing

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/product_test.rb

# Run single test method
bin/rails test test/models/product_test.rb:10

# Run tests with verbose output
bin/rails test -v
```

### Code Quality

```bash
# Linting
bin/rubocop                # Run RuboCop linter
bin/rubocop -a             # Auto-fix violations

# Security audits
bin/brakeman               # Static security analysis
bin/bundler-audit          # Check for vulnerable dependencies

# CI checks (runs all quality checks)
bin/ci                     # Combines bundler-audit, brakeman, and rubocop
```

### Deployment

```bash
# Kamal deployment
bin/kamal setup            # Initial server setup
bin/kamal deploy           # Deploy to production
bin/kamal app exec 'bin/rails db:migrate' # Run migrations on production
```

---

## Architecture & Code Structure

### Data Models

현재 구현된 모델 (무신사 클론 프로토타입):

- **Product**: 상품 기본 정보 (name, description, price, stock, category, brand, gender, views_count, sales_count, image_url)
- **User**: 사용자 (email, name)
- **Review**: 상품 리뷰 (content, rating, height, weight, size_purchased, photo_url)
- **Snap**: 스타일 스냅 (user_id, content)
- **SnapProduct**: Snap-Product 다대다 관계

### JIEUN 목표 모델 (PRD 기반)

향후 구현 예정:

- **Variants**: SKU별 상세 옵션 (바코드, 컬러, 사이즈, 재고)
- **AnonyCustomers**: 익명 CRM (UUID, 우편번호 앞 3자리, 연락처 뒤 4자리, 취향 태그)
- **Orders**: 판매 채널, 결제 정보, 배송 상태 (익명 식별자 연결)
- **StockLogs**: 입출고 이력 (사입처 정보 포함)

### Controllers

- `HomeController`: 메인 페이지 (랭킹 상품 표시)
- `ProductsController`: 상품 상세 페이지
- `SearchController`: 상품 검색 (카테고리, 브랜드, 성별 필터)
- `SnapsController`: 스타일 스냅 CRUD

### Routes

```ruby
root "home#index"
resources :products, only: [:show] do
  resources :reviews, only: [:create]
end
resources :snaps, only: [:index, :new, :create, :show]
get "search", to: "search#index"
get "up" => "rails/health#show"  # Health check endpoint
```

---

## Development Workflow

### Migration 작성

```bash
bin/rails generate migration AddColumnToTable column:type
bin/rails db:migrate
```

### Model 생성

```bash
bin/rails generate model ModelName field:type field:type
bin/rails db:migrate
```

### Controller 생성

```bash
bin/rails generate controller ControllerName action1 action2
```

---

## JIEUN-Specific Implementation Guidelines

### 1. Privacy-First CRM

- **절대 저장 금지**: 상세 주소, 전체 연락처, 전체 이메일
- **허용 데이터**: UUID, 우편번호 앞 3자리, 연락처 뒤 4자리, 지역 정보
- AnonyCustomers 모델 생성 시 JSONB 컬럼 활용하여 취향 태그 저장

### 2. AI-Enhanced Inventory

- Product 모델에 JSONB 속성 추가 (TPO, 감성, 핏감, 소재)
- Variants 모델: 바코드 기반 SKU 관리 (현재고, 적정재고 컬럼 필수)
- StockLogs: 입출고 이력 추적 (timestamps, 사입처, 수량, 담당자)

### 3. Barcode System

- 바코드는 Variant 단위로 생성 (컬러 + 사이즈 조합)
- 모바일 카메라 스캔 → Turbo Stream으로 실시간 재고 업데이트
- Solid Queue로 백그라운드 재고 동기화 처리

### 4. ClaudeBot Integration (Phase 2)

- Claude API 연동 시 `app/services/claude_bot/` 디렉토리 구조 권장
- 운영 리포트, 마케팅 자동화, UCP 응답 생성 서비스 클래스 분리
- Background job으로 정기 분석 보고서 생성

---

## Performance & Production Considerations

### SQLite Production Setup

- Rails 7+는 SQLite를 production에서 사용 가능 (단, 단일 서버 환경)
- `config/database.yml`에 이미 멀티 DB 설정 완료 (primary, cache, queue, cable)
- WAL 모드 활성화로 동시성 개선 (Rails 7.2 default)

### Caching Strategy

- Solid Cache 사용 (SQLite 기반)
- Fragment caching: 상품 목록, 랭킹 데이터
- Russian Doll Caching: 상품 상세 페이지

### Background Jobs

- Solid Queue 활용 (cron 기반 정기 작업 지원)
- 재고 동기화, AI 분석 리포트, 마케팅 메시지 발송에 사용

---

## Testing Strategy

- **Model Tests**: 비즈니스 로직, 유효성 검증, 관계 테스트
- **Controller Tests**: HTTP 요청/응답 검증
- **System Tests**: Capybara + Selenium으로 E2E 테스트
- Coverage 목표: 80%+ (Phase 1), 90%+ (Phase 2)

---

## Security Checklist

- [ ] Brakeman 정기 실행 (CI 파이프라인 포함)
- [ ] `bundler-audit`로 취약한 gem 점검
- [ ] Strong Parameters 사용 (Mass Assignment 방지)
- [ ] CSRF 보호 활성화 (Rails default)
- [ ] Content Security Policy 설정 (`config/initializers/content_security_policy.rb`)
- [ ] 민감 정보 credentials 관리 (`rails credentials:edit`)

---

## Key Files & Directories

- `config/database.yml`: Multi-database configuration
- `config/deploy.yml`: Kamal deployment settings
- `Procfile.dev`: Development process management (web + css)
- `app/models/`: Domain models
- `app/controllers/`: Request handlers
- `app/views/`: ERB templates (Hotwire Turbo Frames/Streams)
- `app/javascript/`: Stimulus controllers
- `db/migrate/`: Database migrations
- `db/schema.rb`: Current database schema
- `test/`: Minitest test suite

---

## PM Orchestrator Integration

이 프로젝트는 `SKILL.md`에 정의된 **PM Orchestrator** 패턴을 따릅니다.

### 주요 원칙

1. **PM은 오케스트레이터** - 직접 실행하지 않고 위임과 조율에 집중
2. **속도 > 완벽** - 빠른 피드백 루프로 점진적 개선
3. **명확한 R&R** - 각 에이전트의 책임 영역 명확화
4. **상태 투명성** - 모든 진행 상황 추적 가능

### 서브 에이전트 활용

코드 작업 시 다음 에이전트 역할 분담:

- **SA (Solution Architect)**: 아키텍처 설계, 기술 선택
- **BE (Backend Engineer)**: Model, Controller, Service 구현
- **FE (Frontend Engineer)**: View, Stimulus, Turbo 구현
- **DBA (Database Architect)**: Migration, Schema 최적화
- **QA (QA Engineer)**: Test 작성 및 품질 검증
- **SEC (Security Specialist)**: 보안 검토, OWASP 체크

---

## Migration from Prototype to JIEUN

현재 저장소는 무신사 클론 기반 프로토타입입니다. JIEUN으로 전환 시:

1. **Models**: Product → 확장 (JSONB 속성 추가), Variants 생성, AnonyCustomers/Orders/StockLogs 추가
2. **Controllers**: Inventory, Stock, Dashboard 컨트롤러 신규 생성
3. **Views**: 바코드 스캔 UI, 익명 CRM 대시보드, AI 리포트 페이지 추가
4. **Services**: Claude API 연동 서비스 클래스 (`app/services/claude_bot/`)
5. **Background Jobs**: 재고 동기화, AI 분석 정기 실행 Job 추가

---

## Claude Code Custom Commands

이 프로젝트는 `.claude/commands/` 디렉토리에 커스텀 슬래시 커맨드를 제공합니다.

### 사용 가능한 커맨드

#### `/test-all` - 전체 테스트 실행
모든 테스트 스위트를 실행하고 커버리지를 측정합니다.
- Model Tests
- System Tests (Capybara)
- Smoke Tests (curl-based)
- Coverage 측정 (SimpleCov)

```bash
# Claude Code에서 사용
/test-all
```

#### `/deploy-check` - 배포 전 체크리스트
배포 전 모든 품질 검사를 자동 실행합니다.
- RuboCop 코드 품질
- Bundler Audit 보안 검사
- Brakeman 보안 검사
- 전체 테스트 실행
- 데이터베이스 마이그레이션 확인

```bash
# Claude Code에서 사용
/deploy-check
```

#### `/fix-errors` - 에러 감지 및 수정 가이드
현재 프로젝트의 에러를 자동 감지하고 수정 방안을 제시합니다.
- 서버 에러 확인 (PID 파일, 로그)
- 데이터베이스 에러 확인 (마이그레이션, N+1)
- 테스트 에러 확인
- Chain-of-Thought 에러 분석

```bash
# Claude Code에서 사용
/fix-errors
```

#### `/upgrade-plan` - 시스템 고도화 계획
JIEUN 프로젝트 고도화 작업 현황 및 다음 단계를 확인합니다.
- Phase 1 안정화 현황
- Phase 3 성능 최적화 현황
- 성능 개선 지표
- 다음 단계 가이드

```bash
# Claude Code에서 사용
/upgrade-plan
```

### 커맨드 작성 가이드

`.claude/commands/` 디렉토리에 Markdown 파일을 추가하면 자동으로 슬래시 커맨드로 등록됩니다.

```markdown
# /my-command - 커맨드 설명

**상세 설명**

## 실행 순서

1. 단계 1
2. 단계 2

## 명령어

\```bash
bin/rails my:task
\```
```

---

## Error Handling & Chain-of-Thought Analysis

### 에러 발생 시 체크리스트

1. **에러 메시지 정확히 읽기**
   - 에러 타입 확인 (NoMethodError, TypeError, etc.)
   - 스택 트레이스에서 파일명과 라인 번호 추출

2. **데이터 타입 검증**
   - 예상한 데이터 타입과 실제 타입 비교
   - `nil`, 빈 문자열, malformed JSON 등 Edge Case 확인

3. **테스트 커버리지 검토**
   - 해당 케이스를 테스트했는가?
   - Edge Case 테스트가 누락되지 않았는가?

4. **Chain-of-Thought 분석**
   - 왜 이 에러가 발생했는가?
   - 어떤 가정이 잘못되었는가?
   - 어떻게 방지할 수 있었는가?

### 일반적인 에러 패턴

#### NoMethodError: undefined method for String
```ruby
# ❌ 잘못된 코드
ai_attributes.dig("mood")  # ai_attributes가 String이면 에러

# ✅ 올바른 코드
def parsed_ai_attributes
  return {} if ai_attributes.blank?
  ai_attributes.is_a?(String) ? JSON.parse(ai_attributes) : ai_attributes
rescue JSON::ParserError
  {}
end

def mood
  parsed_ai_attributes["mood"]
end
```

#### N+1 Query Problem
```ruby
# ❌ N+1 발생
@products = Product.all
@products.each { |p| p.variants.count }  # 각 product마다 쿼리 실행

# ✅ Eager Loading
@products = Product.includes(:variants).all
@products.each { |p| p.variants.count }  # 쿼리 1회만 실행
```

#### Stale PID File
```bash
# 자동 정리
bin/rails server:clean_pids

# 또는 Puma 재시작 시 자동 정리 (config/puma.rb에 설정됨)
```

### 테스트 누락 방지 전략

`docs/TESTING_STRATEGY.md` 참조:
1. TDD 워크플로우 적용
2. Edge Case 체크리스트 사용
3. CI/CD 파이프라인 구축
4. 커버리지 80% 이상 유지

---

## Additional Resources

- **PRD**: 프로젝트 루트의 `../prd.md` 참조
- **PM Orchestrator Guide**: `SKILL.md` 참조
- **Testing Strategy**: `docs/TESTING_STRATEGY.md`
- **Smoke Test Guide**: `docs/SMOKE_TEST_GUIDE.md`
- **Upgrade Summary**: `docs/UPGRADE_SUMMARY.md`
- **Rails 7.2 Guides**: https://guides.rubyonrails.org/
- **Solid Queue Docs**: https://github.com/basecamp/solid_queue
- **Kamal Deployment**: https://kamal-deploy.org/
