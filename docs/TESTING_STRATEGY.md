# JIEUN 테스트 전략 및 자동화 프로세스

**목적**: 테스트 누락을 방지하고 배포 전 자동 검증

---

## 🎯 테스트 누락 원인 분석 (연쇄적 사고)

### **문제 발생 케이스: /products 페이지 500 에러**

```
발생 원인:
1. ai_attributes가 String으로 저장됨
2. Product#mood 메서드가 String.dig() 호출
3. NoMethodError 발생

테스트 누락 이유:
→ Product 모델 Unit Test 부재
→ /products 페이지 Integration Test 부재
→ 수동 테스트만 진행 (홈페이지만 확인)
→ CI/CD 파이프라인 미실행
```

---

## 🔍 **연쇄적 사고 프레임워크**

### **단계 1: 코드 작성 시**
```
질문:
- 이 코드가 예외를 발생시킬 수 있는가?
- nil, String, Hash가 혼용되는가?
- 다른 페이지/API에 영향을 주는가?

액션:
→ Unit Test 작성 (필수)
→ Edge Case 테스트 (nil, empty, invalid)
```

### **단계 2: 기능 완료 시**
```
질문:
- 모든 URL 경로를 테스트했는가?
- 다른 기능과 통합 시 문제없는가?
- 에러 로그에 경고가 없는가?

액션:
→ Integration Test 실행
→ 모든 주요 경로 수동 확인 체크리스트
```

### **단계 3: 배포 전**
```
질문:
- CI가 모든 테스트를 통과했는가?
- Staging 환경에서 검증했는가?
- Rollback 계획이 있는가?

액션:
→ CI/CD 파이프라인 필수 통과
→ Staging 배포 후 QA
```

---

## ✅ **테스트 자동화 프로세스**

### **Level 1: Pre-commit Hook (로컬)**

```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "🧪 Running tests before commit..."

# RuboCop (Linter)
bundle exec rubocop --fail-level=error

# Unit Tests (빠른 테스트만)
RAILS_ENV=test bundle exec rails test:models

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Commit aborted."
  exit 1
fi

echo "✅ Tests passed!"
```

### **Level 2: CI Pipeline (GitHub Actions)**

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
          bundler-cache: true

      - name: Setup Database
        run: |
          bin/rails db:create db:schema:load

      - name: Run Tests
        run: |
          bin/rails test

      - name: Run Security Checks
        run: |
          bundle exec brakeman -q
          bundle exec bundler-audit
```

### **Level 3: 배포 전 체크리스트**

| 항목 | 필수 확인 |
|------|----------|
| ✅ CI 통과 | GitHub Actions 녹색 |
| ✅ 주요 경로 테스트 | `/`, `/products`, `/api/v1/ucp/products` |
| ✅ 에러 로그 확인 | `log/development.log` 경고 없음 |
| ✅ Bullet 경고 확인 | N+1 쿼리 없음 |
| ✅ Coverage | 80%+ |

---

## 📝 **테스트 작성 가이드**

### **1. Model Test (필수)**

```ruby
# test/models/product_test.rb
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "should parse ai_attributes from String" do
    product = Product.new(ai_attributes: '{"mood":"minimal"}')
    assert_equal "minimal", product.mood
  end

  test "should handle nil ai_attributes" do
    product = Product.new(ai_attributes: nil)
    assert_nil product.mood
  end

  test "should handle empty ai_attributes" do
    product = Product.new(ai_attributes: "")
    assert_nil product.mood
  end

  test "should handle malformed JSON" do
    product = Product.new(ai_attributes: "invalid{json")
    assert_nil product.mood
  end
end
```

### **2. Controller Test**

```ruby
# test/controllers/products_controller_test.rb
require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get products_url
    assert_response :success
  end

  test "should show product" do
    product = products(:one)
    get product_url(product)
    assert_response :success
  end
end
```

### **3. Integration Test (주요 경로)**

```ruby
# test/integration/homepage_test.rb
require "test_helper"

class HomepageTest < ActionDispatch::IntegrationTest
  test "homepage loads successfully" do
    get root_url
    assert_response :success
    assert_select "h2", /랭킹/
  end

  test "products page loads successfully" do
    get products_url
    assert_response :success
  end

  test "UCP API returns JSON" do
    get "/api/v1/ucp/products?limit=1"
    assert_response :success
    assert_equal "application/json", @response.media_type
  end
end
```

---

## 🚀 **자동화 실행 명령어**

### **로컬 개발**

```bash
# 전체 테스트 (Coverage 포함)
COVERAGE=1 bin/rails test

# Model 테스트만
bin/rails test:models

# Controller 테스트만
bin/rails test:controllers

# Integration 테스트만
bin/rails test:integration

# Coverage 리포트
open coverage/index.html
```

### **CI/CD**

```bash
# CI 스크립트 (GitHub Actions)
bin/ci  # = bundler-audit + brakeman + rubocop + test
```

---

## 🔄 **테스트 주도 개발 (TDD) 흐름**

```
1. ❌ Red: 실패하는 테스트 작성
   → test/models/product_test.rb

2. ✅ Green: 최소한의 코드로 통과
   → app/models/product.rb

3. 🔄 Refactor: 리팩토링
   → 중복 제거, 성능 개선

4. ✅ CI 통과 확인
   → GitHub Actions 녹색

5. 🚀 배포
   → Staging → Production
```

---

## 📊 **테스트 커버리지 목표**

| 구분 | 목표 | 현재 |
|------|------|------|
| **Models** | 90%+ | 측정 필요 |
| **Controllers** | 80%+ | 측정 필요 |
| **Integration** | 70%+ | 측정 필요 |
| **전체** | 80%+ | 측정 필요 |

---

## 🛡️ **방어적 프로그래밍 패턴**

### **1. Safe Navigation (&.)**

```ruby
# Bad
product.ai_attributes.dig("mood")

# Good
product.ai_attributes&.dig("mood")
```

### **2. Nil Check + Fallback**

```ruby
# Bad
JSON.parse(ai_attributes)

# Good
JSON.parse(ai_attributes) rescue {}
```

### **3. Type Guard**

```ruby
def parsed_ai_attributes
  return {} if ai_attributes.blank?

  if ai_attributes.is_a?(String)
    JSON.parse(ai_attributes) rescue {}
  else
    ai_attributes || {}
  end
end
```

---

## 📋 **수동 테스트 체크리스트**

배포 전 **반드시** 확인:

- [ ] **홈페이지** (/) - 200 OK, 큐레이션 섹션 표시
- [ ] **상품 목록** (/products) - 200 OK, 이미지 로드
- [ ] **상품 상세** (/products/:id) - 200 OK, Variants 표시
- [ ] **검색** (/products?q=coat) - 200 OK, 결과 표시
- [ ] **UCP API** (/api/v1/ucp/products) - 200 OK, JSON 응답
- [ ] **재고관리** (/inventory/scan) - 200 OK, 바코드 스캔
- [ ] **대시보드** (/dashboard/index) - 200 OK
- [ ] **거래처** (/suppliers) - 200 OK
- [ ] **발주** (/purchase_orders) - 200 OK

---

## 🔧 **테스트 누락 방지 도구**

### **1. Guard (파일 변경 시 자동 테스트)**

```ruby
# Gemfile
gem "guard-minitest", group: :development

# Guardfile
guard :minitest do
  watch(%r{^app/models/(.+)\.rb$}) { |m| "test/models/#{m[1]}_test.rb" }
  watch(%r{^app/controllers/(.+)\.rb$}) { |m| "test/controllers/#{m[1]}_test.rb" }
end
```

### **2. Overcommit (Git Hook 관리)**

```bash
gem install overcommit
overcommit --install
```

### **3. CodeClimate (코드 품질 분석)**

- Test Coverage 자동 추적
- 복잡도 경고
- 중복 코드 감지

---

## 🎯 **Next Actions**

1. **즉시**: Product 모델 테스트 작성
2. **1주일 이내**: 전체 테스트 커버리지 80% 달성
3. **2주일 이내**: CI/CD 파이프라인 완성
4. **1개월 이내**: TDD 프로세스 정착

---

**작성일**: 2026-01-31
**버전**: 1.0
**작성자**: JIEUN Team

🧪 **테스트는 선택이 아닌 필수!**
