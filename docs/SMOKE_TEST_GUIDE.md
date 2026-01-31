# Smoke Test 가이드

**Playwright 없이 운영 테스트하기**

---

## 🎯 개요

Smoke Test(연기 테스트)는 **배포 후 기본 동작**을 빠르게 검증하는 테스트입니다.

- ✅ **빠름**: 30초 이내
- ✅ **간단**: curl + Ruby만 사용
- ✅ **안정적**: 외부 의존성 최소화

---

## 🚀 실행 방법

### 로컬 환경
```bash
bin/rails test:smoke
```

### Staging 환경
```bash
SMOKE_TEST_URL=https://staging.jieun.com bin/rails test:smoke
```

### Production 환경
```bash
SMOKE_TEST_URL=https://jieun.com bin/rails test:smoke
```

---

## 📋 테스트 시나리오

### Scenario 1: Core Pages
- ✅ Homepage (/)
- ✅ Products List (/products)
- ✅ Health Check (/up)

### Scenario 2: API Endpoints
- ✅ UCP API (/api/v1/ucp/products)
- JSON 응답 검증

### Scenario 3: Search & Filter
- ✅ Search (/products?q=coat)
- ✅ Category Filter (/?category=아우터)

### Scenario 4: Inventory Management
- ✅ Inventory Scan (/inventory/scan)
- ✅ Dashboard (/dashboard/index)

### Scenario 5: Supplier & Purchase Orders
- ✅ Suppliers (/suppliers)
- ✅ Purchase Orders (/purchase_orders)

### Scenario 6: Asset Loading
- ✅ Unsplash Images (외부 CDN)

---

## 🔧 커스터마이징

### 새로운 테스트 추가

```ruby
# lib/tasks/smoke_test.rake

puts "\n📋 Scenario 7: Custom Test"
puts "-" * 50
tests_passed += 1 if test_url("My Page", "/my-page", contains: "expected text")
```

### 환경 변수

```bash
# 타임아웃 설정
SMOKE_TEST_TIMEOUT=10 bin/rails test:smoke

# Verbose 모드
SMOKE_TEST_VERBOSE=true bin/rails test:smoke
```

---

## 🎬 System Test (Capybara)

### 실행
```bash
# 전체 System Test
bin/rails test:system

# 특정 파일만
bin/rails test test/system/homepage_test.rb
```

### 스크린샷 확인
```bash
ls tmp/screenshots/
```

---

## 📊 결과 해석

### 성공 예시
```
✅ Passed: 11
❌ Failed: 0
📈 Success Rate: 100.0%
🎉 All smoke tests passed! Ready for deployment.
```

### 실패 예시
```
❌ Homepage: Expected 200, got 500
⚠️  Some tests failed. Check logs above.
```

→ 배포 중단, 에러 수정 후 재시도

---

## 🔄 CI/CD 통합

### GitHub Actions
```yaml
# .github/workflows/deploy.yml
jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Smoke Tests
        run: |
          SMOKE_TEST_URL=${{ secrets.PRODUCTION_URL }} \
          bin/rails test:smoke
```

### Kamal Hook
```bash
# .kamal/hooks/post-deploy
#!/bin/bash
SMOKE_TEST_URL=https://jieun.com bin/rails test:smoke
```

---

## 🎯 Best Practices

1. **배포 전**: 로컬에서 `bin/rails test:smoke`
2. **배포 후**: Production에서 `SMOKE_TEST_URL=... bin/rails test:smoke`
3. **정기 실행**: Cron으로 매시간 실행
4. **알림**: 실패 시 Slack/Email 알림

---

## 📚 참고 자료

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [TESTING_STRATEGY.md](./TESTING_STRATEGY.md)

---

**작성일**: 2026-01-31
**버전**: 1.0
