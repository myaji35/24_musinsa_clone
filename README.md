# JIEUN (지은) - AI-Native Fashion OS

[![CI](https://github.com/myaji35/24_musinsa_clone/workflows/CI/badge.svg)](https://github.com/myaji35/24_musinsa_clone/actions)
[![CodeQL](https://github.com/myaji35/24_musinsa_clone/workflows/CodeQL/badge.svg)](https://github.com/myaji35/24_musinsa_clone/security/code-scanning)

**비전**: "주소는 지우고 취향은 잇다."

AI 에이전트(ClaudeBot)와 공존하는 차세대 의류 운영 솔루션.

## 🎯 프로젝트 개요

JIEUN은 다음과 같은 핵심 가치를 추구합니다:

- **Privacy-First**: 상세 주소 없는 익명 CRM
- **AI-Native**: UCP 및 GEO 최적화 상품 관리
- **Efficiency**: 바코드 기반의 자동화된 워크플로우

## 🚀 기술 스택

| 구분 | 기술 |
|------|------|
| **Framework** | Ruby on Rails 7.2 |
| **Database** | SQLite 3 (Production-ready) |
| **Background Jobs** | Solid Queue |
| **Caching** | Solid Cache |
| **Frontend** | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| **Deployment** | Kamal (Docker-based) |
| **CI/CD** | GitHub Actions |

## 📋 주요 기능 (Phase 1 - Epic 1 완료)

### Epic 1: 지능형 상품 관리 ✅

- [x] **Story 1.1**: 상품 기본 정보 등록 (CRUD)
  - 상품명, 가격, 브랜드, 카테고리 필수 입력
  - 이미지 URL 또는 Active Storage 파일 업로드
  - 상품 설명 최대 500자 입력
  - 유효성 검증 (가격 양수, 필수 필드 확인)

- [x] **Story 1.2**: AI 속성 필드 관리
  - AI 검색용 속성 태깅 (TPO, 감성, 핏감, 소재)
  - 다중 선택 태그 UI (mood, tpo, fit_style, material_feel)
  - AI 속성 필터링 Scope 추가

- [x] **Story 1.3**: 상품 SKU 관리 (Variants)
  - Variant 모델: color, size, stock, min_stock
  - 바코드 자동 생성 (형식: `PRODUCT_ID-COLOR-SIZE`)
  - 재고 부족 경고 표시 (stock <= min_stock)
  - Nested Form으로 동적 Variant 추가/삭제

## 🛠️ 설치 및 실행

### 필수 요구사항

- Ruby 3.3+
- Node.js 20+
- SQLite 3

### 로컬 개발 환경 설정

```bash
# 저장소 클론
git clone https://github.com/myaji35/24_musinsa_clone.git
cd 24_musinsa_clone

# 의존성 설치
bin/setup

# 개발 서버 실행 (Rails + Tailwind watcher)
bin/dev
```

서버가 시작되면 http://localhost:3000 에서 애플리케이션에 접근할 수 있습니다.

## 🧪 테스트

```bash
# 전체 테스트 실행
bin/rails test

# 특정 테스트 파일 실행
bin/rails test test/models/product_test.rb

# Linting (RuboCop)
bin/rubocop

# 보안 검사
bin/ci  # Combines bundler-audit, brakeman, and rubocop
```

## 📦 배포

Kamal을 사용한 Docker 기반 배포:

```bash
# 초기 서버 설정
bin/kamal setup

# 배포
bin/kamal deploy

# Production migration 실행
bin/kamal app exec 'bin/rails db:migrate'
```

## 🏗️ 프로젝트 구조

```
musinsa_clone/
├── app/
│   ├── models/
│   │   ├── product.rb          # 상품 모델 (AI 속성, Variants 관계)
│   │   └── variant.rb          # SKU 모델 (바코드 자동 생성)
│   ├── controllers/
│   │   └── products_controller.rb  # 상품 CRUD
│   ├── views/
│   │   └── products/
│   │       ├── _form.html.erb  # 상품 등록/수정 폼 (AI 속성 포함)
│   │       ├── index.html.erb  # 상품 목록
│   │       └── show.html.erb   # 상품 상세
│   └── javascript/
│       └── controllers/
│           └── wishlist_controller.js
├── db/
│   ├── migrate/
│   │   ├── 20260131102844_add_ai_attributes_to_products.rb
│   │   └── 20260131105819_create_variants.rb
│   └── schema.rb
└── .github/
    └── workflows/
        ├── ci.yml          # CI/CD 파이프라인
        └── codeql.yml      # 코드 보안 분석
```

## 📖 Epic Roadmap

### Phase 1: 입출고/재고 MVP ✅ (Epic 1 완료)
- [x] Epic 1: 지능형 상품 관리
- [ ] Epic 2: 바코드 기반 재고 시스템
- [ ] Epic 3: 기본 UI/UX 구축

### Phase 2: AI 운영 비서
- [ ] Epic 4: 익명 CRM 구축
- [ ] Epic 5: ClaudeBot 운영 리포트
- [ ] Epic 6: 지역 트렌드 대시보드

### Phase 3: 외부 연동
- [ ] Epic 7: UCP 프로토콜 대응
- [ ] Epic 8: 외부 채널 통합 (무신사 API)
- [ ] Epic 9: 마케팅 자동화

상세한 Epic & User Story는 [EPIC_STORY.md](../EPIC_STORY.md)를 참고하세요.

## 🤝 기여 가이드

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 코드 품질 기준

- RuboCop 통과 (`.rubocop.yml` 설정 준수)
- Brakeman 보안 검사 통과
- Test coverage 80% 이상
- GitHub Actions CI 통과

## 📄 라이선스

This project is private and proprietary.

## 👤 Author

**JIEUN Team**
- GitHub: [@myaji35](https://github.com/myaji35)

---

**Generated with** [Claude Code](https://claude.com/claude-code) 🤖
