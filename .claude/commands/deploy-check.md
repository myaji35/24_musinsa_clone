# /deploy-check - 배포 전 체크리스트 실행

**배포 전 모든 품질 검사를 실행합니다.**

## 체크리스트

### 1. 코드 품질
```bash
bin/rubocop -a
```

### 2. 보안 검사
```bash
bin/bundler-audit
bin/brakeman
```

### 3. 테스트 실행
```bash
bin/rails test
bin/rails test:smoke
```

### 4. 데이터베이스 마이그레이션 확인
```bash
bin/rails db:migrate:status
```

### 5. Assets 빌드
```bash
bin/rails assets:precompile
```

## 배포 승인 기준

- ✅ RuboCop: 0 offenses
- ✅ Bundler Audit: 0 vulnerabilities
- ✅ Brakeman: 0 security warnings
- ✅ Tests: 100% 통과
- ✅ Migrations: 모두 up 상태
- ✅ Assets: 빌드 성공

## 배포 명령어

```bash
# Staging
SMOKE_TEST_URL=https://staging.jieun-fashion.com bin/rails test:smoke

# Production
bin/kamal deploy
```
