# /fix-errors - 에러 자동 감지 및 수정 가이드

**현재 프로젝트의 에러를 자동으로 감지하고 수정 방안을 제시합니다.**

## 실행 순서

### 1. 서버 에러 확인
```bash
# 로그 확인
tail -f log/development.log

# PID 파일 정리
bin/rails server:clean_pids
```

### 2. 데이터베이스 에러 확인
```bash
# 마이그레이션 상태
bin/rails db:migrate:status

# N+1 쿼리 확인 (Bullet)
# - development.log에서 [Bullet] 검색
```

### 3. 테스트 에러 확인
```bash
# 실패한 테스트만 재실행
bin/rails test --fail-fast
```

### 4. 코드 품질 에러
```bash
# RuboCop 자동 수정
bin/rubocop -a

# 보안 이슈
bin/brakeman --no-pager
```

## 일반적인 에러 패턴

### NoMethodError: undefined method 'dig' for String
**원인**: JSON 파싱 없이 String에 Hash 메서드 사용
**해결**: `parsed_ai_attributes` 같은 safe parser 메서드 추가

### 500 Error on /products
**확인**:
1. `ai_attributes` 컬럼 데이터 타입
2. View에서 `.dig()` 사용 여부
3. Model에 safe accessor 메서드 존재 여부

### Stale PID file
**해결**: `bin/rails server:clean_pids`

### Bullet N+1 warnings
**해결**: Controller에 `.includes()` 추가

## Chain-of-Thought 에러 분석

1. **에러 메시지 읽기** - 정확한 에러 타입 파악
2. **스택 트레이스 추적** - 어느 파일 몇 번째 줄?
3. **데이터 타입 확인** - 예상한 타입과 실제 타입 비교
4. **Edge Case 검토** - nil, empty, malformed 데이터 처리?
5. **Test Coverage 확인** - 해당 케이스를 테스트했는가?
