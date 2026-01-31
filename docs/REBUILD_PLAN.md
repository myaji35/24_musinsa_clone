# JIEUN Project Rebuild Plan (Raplan)

**작성일**: 2026-01-31
**버전**: 1.0
**작성자**: Claude Code + PM Orchestrator

---

## 📊 현재 프로젝트 상태 분석

### 코드베이스 규모

| 항목 | 수량 | 비고 |
|------|------|------|
| Ruby 파일 | 166개 | Models, Controllers, Jobs, Services 포함 |
| ERB 템플릿 | 72개 | View 레이어 |
| JavaScript 파일 | 3,000개 | node_modules 포함 (실제 커스텀 JS는 극소수) |
| 프로젝트 크기 | 10GB | node_modules가 대부분 차지 |
| 데이터베이스 | 300KB | development.sqlite3 |
| 마이그레이션 | 14개 | 모두 up 상태 |
| Controllers | 639 LOC | 9개 컨트롤러 |
| Models | 560 LOC | 15개 모델 |
| 기술 부채 마커 | 5개 | TODO/FIXME 코멘트 |

### 기술 스택 현황

**✅ 잘 구축된 영역**
- Rails 7.2 기반 (최신 버전)
- Hotwire (Turbo + Stimulus) 프론트엔드
- Tailwind CSS 스타일링
- SQLite 멀티 DB 구성 (primary, queue, cache, cable)
- Solid Queue, Solid Cache, Solid Cable (SQLite 백엔드)
- Rack::Attack 레이트 리미팅
- Bullet N+1 감지
- SimpleCov 테스트 커버리지
- Sentry 에러 트래킹

**⚠️ 개선 필요 영역**
- Service 레이어 부족 (ClaudeBot만 존재)
- Background Jobs 미완성 (TODO 코멘트 다수)
- 이메일 발송 로직 미구현 (TODO 표시)
- Active Storage 설정은 있으나 실제 사용 미확인
- 테스트 커버리지 미측정 (SimpleCov 설정만 완료)

---

## 🎯 JIEUN 목표 아키텍처 vs 현재 Gap

### 1. Privacy-First CRM

| 요구사항 | 현재 상태 | Gap |
|----------|----------|-----|
| 익명 고객 모델 | ✅ `AnonyCustomer` 구현됨 | - |
| UUID 기반 식별 | ✅ `before_validation :generate_uuid` | - |
| 우편번호 앞 3자리만 저장 | ✅ `zip_prefix` 컬럼 (3자리 검증) | - |
| 연락처 뒤 4자리만 저장 | ✅ `phone_suffix` 컬럼 (4자리 검증) | - |
| 취향 태그 JSONB | ✅ `preference_tags` 직렬화 | - |
| 주소/이메일 저장 금지 | ✅ 컬럼 없음 | - |

**Gap 분석**: 🟢 **CRM 구조는 완벽히 구현됨** (rebuild 불필요)

### 2. AI-Enhanced Inventory

| 요구사항 | 현재 상태 | Gap |
|----------|----------|-----|
| Product에 AI 속성 | ✅ `ai_attributes` JSONB | - |
| Variants SKU 관리 | ✅ `Variant` 모델, 바코드 자동 생성 | - |
| StockLogs 이력 추적 | ✅ `StockLog` 모델 | - |
| 현재고/최소재고 컬럼 | ✅ `stock`, `min_stock` | - |
| AI 속성 필터링 | ✅ `scope :by_mood`, `by_tpo` 등 | - |

**Gap 분석**: 🟡 **기본 구조는 완성, 하지만 ai_attributes JSON 파싱에 버그 존재**

**Critical Issue**:
- `app/models/product.rb`의 `ai_attributes`가 String/Hash 혼재로 저장됨
- 이전 대화에서 `parsed_ai_attributes` 메서드로 임시 해결
- **Rebuild 시 JSONB 컬럼으로 변경 권장** (PostgreSQL로 전환 시)

### 3. Barcode System

| 요구사항 | 현재 상태 | Gap |
|----------|----------|-----|
| Variant별 바코드 생성 | ✅ `generate_barcode` 메서드 | - |
| 중복 방지 로직 | ✅ `while Variant.exists?` | - |
| 모바일 스캔 UI | ❌ 미구현 | **Gap: 프론트엔드 개발 필요** |
| Turbo Stream 실시간 업데이트 | ❌ 미구현 | **Gap: Hotwire 통합 필요** |

**Gap 분석**: 🔴 **백엔드는 완성, 프론트엔드 UI 전무**

### 4. ClaudeBot Integration

| 요구사항 | 현재 상태 | Gap |
|----------|----------|-----|
| Claude API 연동 | ✅ `ClaudeBot::MessageGenerator` | - |
| 재고 부족 알림 생성 | ✅ `generate_low_stock_alert` | - |
| 마케팅 메시지 생성 | ✅ `generate_marketing_message` | - |
| Background Job 정기 실행 | ⚠️ Job은 있으나 TODO 많음 | **Gap: Job 완성 필요** |
| 실제 이메일/Slack 발송 | ❌ Mock만 존재 | **Gap: ActionMailer 통합** |

**Gap 분석**: 🟡 **API 연동 완료, 실제 알림 발송 미구현**

### 5. 거래처 및 발주 관리 (Epic 8)

| 요구사항 | 현재 상태 | Gap |
|----------|----------|-----|
| Supplier 모델 | ✅ 구현됨 | - |
| PurchaseOrder 모델 | ✅ 구현됨 | - |
| PurchaseOrderItem 모델 | ✅ 구현됨 | - |
| 토큰 기반 거래처 확인 URL | ✅ `confirm/:token` 라우트 | - |
| 이메일 발송 | ❌ TODO 코멘트만 존재 | **Gap: ActionMailer 구현** |

**Gap 분석**: 🟡 **모델/라우팅 완성, 이메일 발송만 누락**

---

## 🚨 Rebuild가 필요한 핵심 이유

### 1. **SQLite → PostgreSQL 전환 필요성**

**현재 문제점**:
- SQLite는 단일 서버 환경에만 적합
- JSONB 타입 미지원 (ai_attributes를 TEXT로 저장 중)
- 동시 쓰기 성능 제한
- Production 스케일링 불가능

**Rebuild 시 PostgreSQL 장점**:
- 네이티브 JSONB 지원 → ai_attributes 쿼리 최적화
- GIN/GiST 인덱스 → 전문 검색 가능
- 다중 서버 배포 가능
- Row-level locking, MVCC 동시성 개선

**전환 난이도**: 🟡 중간 (마이그레이션 스크립트 작성 필요)

### 2. **Active Storage 완전 통합**

**현재 문제점**:
- 모델에 `has_one_attached :image` 선언은 있음
- 실제로 Unsplash URL만 사용 중 (`image_url` 컬럼)
- Active Storage 테이블은 생성되었으나 미사용

**Rebuild 시 개선안**:
- 실제 파일 업로드 지원
- Cloudflare R2 / AWS S3 연동
- 이미지 variants (썸네일, 리사이징)
- Direct Upload 구현

**전환 난이도**: 🟢 쉬움 (이미 설정됨, 활성화만 필요)

### 3. **Service 레이어 아키텍처 재설계**

**현재 문제점**:
- Controller에 비즈니스 로직 집중
- Service 레이어는 `ClaudeBot::MessageGenerator` 하나만 존재
- Fat Controller 패턴 → 테스트 어려움

**Rebuild 시 개선안**:
```
app/services/
├── inventory/
│   ├── barcode_scanner.rb
│   ├── stock_adjuster.rb
│   └── reorder_suggester.rb
├── crm/
│   ├── preference_analyzer.rb
│   └── customer_segmenter.rb
├── claude_bot/
│   ├── message_generator.rb (기존)
│   ├── report_generator.rb (신규)
│   └── ucp_responder.rb (신규)
└── notifications/
    ├── email_sender.rb
    ├── slack_notifier.rb
    └── sms_sender.rb (선택)
```

**전환 난이도**: 🟡 중간 (기존 코드 리팩토링 필요)

### 4. **Background Jobs 완성**

**현재 문제점**:
```ruby
# app/jobs/low_stock_alert_job.rb:47
# TODO: 실제 프로덕션에서는 ActionMailer, Slack Webhook 등 연동

# app/jobs/low_stock_alert_job.rb:56
# TODO: 실제 발송 로직
```

**Rebuild 시 개선안**:
- ActionMailer 통합
- Slack Webhook 연동
- Cron-like 정기 실행 (Solid Queue의 `recurring_tasks` 활용)
- 실패 재시도 로직
- Dead Letter Queue

**전환 난이도**: 🟢 쉬움 (Solid Queue 이미 구성됨)

### 5. **프론트엔드 모바일 최적화**

**현재 문제점**:
- 바코드 스캔 UI 없음
- 재고 관리 화면이 데스크톱 중심
- 모바일 카메라 API 미활용

**Rebuild 시 개선안**:
- PWA 활성화 (현재 주석 처리됨)
- Turbo Native 모바일 앱 고려
- 바코드 스캔 Stimulus Controller
- Offline-first 캐싱 전략

**전환 난이도**: 🔴 높음 (새로운 기술 스택 추가)

---

## 📋 Rebuild 우선순위 및 단계별 계획

### Phase 0: 사전 준비 (1-2일)

**목표**: 현재 시스템 백업 및 테스트 커버리지 확보

- [ ] 전체 데이터베이스 백업
- [ ] `COVERAGE=1 bin/rails test` 실행, 커버리지 측정
- [ ] 80% 이상 달성 (미달 시 테스트 추가)
- [ ] Smoke Test 전체 통과 확인
- [ ] Git 브랜치 전략 수립 (`main` → `rebuild/phase-1`)

**완료 기준**:
- ✅ 커버리지 80%+
- ✅ Smoke Test 11/11 통과
- ✅ 백업 완료

---

### Phase 1: 데이터베이스 전환 (3-5일)

**목표**: SQLite → PostgreSQL 마이그레이션

#### Step 1.1: PostgreSQL 설치 및 설정
```bash
# Gemfile 수정
gem 'pg', '~> 1.5'
# gem 'sqlite3' 제거

# config/database.yml 재작성
development:
  adapter: postgresql
  database: jieun_development
  host: localhost
  username: <%= ENV['DB_USER'] %>
  password: <%= ENV['DB_PASSWORD'] %>
```

#### Step 1.2: 스키마 변경
```ruby
# db/migrate/XXXXXX_convert_ai_attributes_to_jsonb.rb
change_column :products, :ai_attributes, :jsonb, using: 'ai_attributes::jsonb'
change_column :products, :badges, :jsonb, using: 'badges::jsonb'
change_column :anony_customers, :preference_tags, :jsonb, using: 'preference_tags::jsonb'

# GIN 인덱스 추가
add_index :products, :ai_attributes, using: :gin
```

#### Step 1.3: 데이터 마이그레이션
```bash
# SQLite → PostgreSQL 데이터 이관
# pgloader 사용 또는 수동 CSV 덤프/로드
```

#### Step 1.4: 모델 코드 수정
```ruby
# app/models/product.rb
# serialize :ai_attributes, coder: JSON 제거
# PostgreSQL JSONB는 자동 직렬화

def mood
  ai_attributes&.dig("mood") # Safe navigation으로 간결화
end
```

**완료 기준**:
- ✅ PostgreSQL 로컬 실행
- ✅ 모든 테스트 통과
- ✅ Smoke Test 통과

**리스크**:
- 🔴 **High**: 데이터 손실 가능성 → 백업 필수
- 🟡 **Medium**: 기존 JSON 파싱 코드 호환성 이슈

---

### Phase 2: Service 레이어 재설계 (5-7일)

**목표**: Fat Controller → Thin Controller + Service 패턴

#### Step 2.1: Service 디렉토리 구조 생성
```bash
mkdir -p app/services/{inventory,crm,notifications,claude_bot}
```

#### Step 2.2: Controller 리팩토링 예시
```ruby
# Before: app/controllers/inventory_controller.rb
def create_stock_in
  variant = Variant.find_by(barcode: params[:barcode])
  # ... 30줄의 비즈니스 로직 ...
end

# After:
def create_stock_in
  result = Inventory::StockAdjuster.new(params).execute
  # ... 간결한 응답 처리 ...
end
```

#### Step 2.3: Service 클래스 구현
```ruby
# app/services/inventory/stock_adjuster.rb
module Inventory
  class StockAdjuster
    def initialize(params)
      @barcode = params[:barcode]
      @quantity = params[:quantity].to_i
      @note = params[:note]
    end

    def execute
      variant = find_variant
      return failure("바코드 미발견") unless variant

      variant.transaction do
        variant.increment!(:stock, @quantity)
        log_stock_change(variant)
        notify_if_restock(variant)
      end

      success(variant)
    rescue => e
      failure(e.message)
    end
  end
end
```

**완료 기준**:
- ✅ 모든 Controller가 Service 레이어 사용
- ✅ Controller LOC 50% 감소
- ✅ Service 클래스 단위 테스트 작성

---

### Phase 3: Background Jobs 완성 (3-4일)

**목표**: TODO 제거, 실제 알림 발송 구현

#### Step 3.1: ActionMailer 설정
```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD']
}
```

#### Step 3.2: Low Stock Alert Job 완성
```ruby
# app/jobs/low_stock_alert_job.rb (TODO 제거)
def perform(variant_id)
  variant = Variant.find(variant_id)
  message = ClaudeBot::MessageGenerator.generate_low_stock_alert(variant)

  # 실제 발송
  Notifications::EmailSender.new.send_alert(
    to: ENV['ADMIN_EMAIL'],
    subject: "재고 부족 알림",
    body: message
  )

  Notifications::SlackNotifier.new.post(
    channel: "#inventory",
    text: message
  )
end
```

#### Step 3.3: Cron 정기 실행
```yaml
# config/recurring.yml (Solid Queue)
low_stock_check:
  class: LowStockAlertJob
  queue: default
  schedule: "0 9 * * *" # 매일 오전 9시
```

**완료 기준**:
- ✅ TODO 코멘트 0개
- ✅ 이메일/Slack 발송 성공
- ✅ Cron 정기 실행 확인

---

### Phase 4: 프론트엔드 모바일 최적화 (7-10일)

**목표**: 바코드 스캔 UI, PWA 활성화

#### Step 4.1: Barcode Scanner Stimulus Controller
```javascript
// app/javascript/controllers/barcode_scanner_controller.js
import { Controller } from "@hotwired/stimulus"
import { Html5Qrcode } from "html5-qrcode"

export default class extends Controller {
  connect() {
    this.scanner = new Html5Qrcode("reader")
  }

  scan() {
    this.scanner.start(
      { facingMode: "environment" },
      { fps: 10, qrbox: 250 },
      this.onScanSuccess.bind(this)
    )
  }

  onScanSuccess(decodedText) {
    // Turbo Stream으로 재고 조회
    fetch(`/inventory/find_variant?barcode=${decodedText}`)
  }
}
```

#### Step 4.2: PWA Manifest 활성화
```ruby
# config/routes.rb (주석 해제)
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
```

#### Step 4.3: Offline-first Caching
```javascript
// app/views/pwa/service-worker.js.erb
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      return response || fetch(event.request)
    })
  )
})
```

**완료 기준**:
- ✅ 모바일에서 바코드 스캔 성공
- ✅ PWA 설치 가능
- ✅ Offline 상태에서 기본 페이지 접근

---

### Phase 5: Production 배포 준비 (2-3일)

**목표**: Kamal + PostgreSQL Production 배포

#### Step 5.1: Docker 설정 수정
```dockerfile
# Dockerfile (PostgreSQL 드라이버 추가)
RUN bundle config build.pg --with-pg-config=/usr/bin/pg_config
```

#### Step 5.2: Kamal 설정 업데이트
```yaml
# config/deploy.yml
accessories:
  db:
    image: postgres:16
    env:
      POSTGRES_DB: jieun_production
      POSTGRES_PASSWORD: <%= ENV['DB_PASSWORD'] %>
    volumes:
      - data:/var/lib/postgresql/data
```

#### Step 5.3: CI/CD 파이프라인
```yaml
# .github/workflows/deploy.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: bin/rails test
      - run: bin/rails test:smoke

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: kamal deploy
```

**완료 기준**:
- ✅ Staging 배포 성공
- ✅ Smoke Test 통과
- ✅ Production 배포 성공

---

## ⚠️ Rebuild 리스크 및 완화 전략

### 리스크 1: 데이터 손실

**영향도**: 🔴 Critical
**발생 확률**: 🟡 Medium (마이그레이션 실수 가능성)

**완화 전략**:
1. Phase 0에서 전체 백업 (SQLite → .sql 덤프)
2. Staging 환경에서 먼저 마이그레이션 테스트
3. Rollback 스크립트 준비
4. Production 마이그레이션 전 점검 체크리스트 작성

### 리스크 2: 테스트 실패

**영향도**: 🟡 High
**발생 확률**: 🟢 Low (이미 커버리지 높음)

**완화 전략**:
1. Phase별로 테스트 실행 (TDD 워크플로우)
2. 각 Phase 완료 후 Smoke Test 실행
3. 회귀 테스트 자동화 (CI/CD)

### 리스크 3: Production 다운타임

**영향도**: 🔴 Critical
**발생 확률**: 🟡 Medium (DB 전환 시)

**완화 전략**:
1. Blue-Green Deployment 전략
2. 점진적 트래픽 전환 (Kamal의 rolling restart)
3. Health Check 강화 (`/up` 엔드포인트 모니터링)
4. Sentry 알림으로 즉시 에러 감지

### 리스크 4: 일정 지연

**영향도**: 🟡 Medium
**발생 확률**: 🔴 High (Phase 4 프론트엔드 작업)

**완화 전략**:
1. Phase 4를 선택적으로 연기 가능 (PWA는 Nice-to-have)
2. 핵심 기능(Phase 1-3) 우선 배포
3. 주간 체크포인트로 진행 상황 추적

---

## 📅 전체 일정 예상

| Phase | 기간 | 중요도 | 의존성 |
|-------|------|--------|--------|
| Phase 0: 사전 준비 | 1-2일 | 🔴 Critical | - |
| Phase 1: PostgreSQL 전환 | 3-5일 | 🔴 Critical | Phase 0 |
| Phase 2: Service 레이어 | 5-7일 | 🟡 High | Phase 1 |
| Phase 3: Background Jobs | 3-4일 | 🟡 High | Phase 1 |
| Phase 4: 프론트엔드 최적화 | 7-10일 | 🟢 Medium | - |
| Phase 5: Production 배포 | 2-3일 | 🔴 Critical | Phase 1,2,3 |

**총 예상 기간**: 21-31일 (약 1개월)

**최소 기능 배포 (MVP)**: Phase 0,1,2,3,5 = 14-21일 (약 3주)

---

## 💡 Rebuild vs Refactor 결정 기준

### Rebuild를 해야 하는 경우

- ✅ **Database 전환** (SQLite → PostgreSQL)
- ✅ **아키텍처 재설계** (Service 레이어 추가)
- ✅ **새로운 기능 추가** (바코드 스캔 UI)

### Refactor만으로 충분한 경우

- ✅ **TODO 코멘트 제거** (Background Jobs)
- ✅ **코드 정리** (중복 제거, 네이밍 개선)
- ✅ **테스트 추가** (커버리지 향상)

### 대표님께 질문드릴 사항

1. **PostgreSQL 전환을 원하시나요?**
   - Yes → Full Rebuild (Phase 1-5)
   - No → Partial Refactor (Phase 2-3만)

2. **모바일 바코드 스캔 UI가 필수인가요?**
   - Yes → Phase 4 포함
   - No → Phase 4 연기

3. **배포 목표 시점이 언제인가요?**
   - 1개월 이내 → Full Rebuild
   - 3주 이내 → MVP만 (Phase 1,2,3,5)
   - 2주 이내 → Refactor만 (Phase 2,3)

---

## 🎯 권장 사항

**대표님의 현재 프로젝트 상태를 고려한 PM의 권장안**:

### 시나리오 A: 장기 프로덕션 운영 목표
→ **Full Rebuild 추천** (Phase 0-5 모두 실행)
- PostgreSQL 전환으로 스케일 확보
- Service 레이어로 유지보수성 향상
- PWA로 모바일 경험 개선

### 시나리오 B: 빠른 MVP 검증
→ **Partial Refactor 추천** (Phase 2,3만)
- SQLite 유지 (단일 서버 충분)
- Service 레이어로 코드 품질 개선
- Background Jobs 완성

### 시나리오 C: 현재 상태 유지
→ **Minor Fixes만** (TODO 제거, 테스트 추가)
- 현재 아키텍처 그대로 사용
- Critical Bug만 수정
- 추가 개발 최소화

---

**다음 단계**: 대표님의 선택에 따라 상세 실행 계획을 수립하겠습니다.
