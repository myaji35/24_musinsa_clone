# /test-all - 전체 테스트 실행 및 결과 분석

**전체 테스트 스위트를 실행하고 결과를 분석합니다.**

## 실행 순서

1. **Model Tests** 실행
2. **System Tests** 실행
3. **Smoke Tests** 실행
4. **커버리지 측정** (SimpleCov)
5. **결과 요약** 생성

## 명령어

```bash
# Model Tests
bin/rails test

# System Tests
bin/rails test:system

# Smoke Tests
bin/rails test:smoke

# 커버리지 측정
COVERAGE=1 bin/rails test
```

## 성공 기준

- ✅ Model Tests: 100% 통과
- ✅ System Tests: 100% 통과
- ✅ Smoke Tests: 100% 통과
- ✅ Coverage: 80% 이상

## 실패 시

- 실패한 테스트 파일 확인
- 에러 메시지 분석
- Edge Case 누락 확인
- `docs/TESTING_STRATEGY.md` 참조
