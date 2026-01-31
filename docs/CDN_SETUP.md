# Cloudflare CDN 연동 가이드

## 📋 개요

Cloudflare를 사용하여 정적 에셋(이미지, CSS, JS)의 전송 속도를 향상시킵니다.

---

## 🚀 설정 단계

### 1. Cloudflare 가입 및 도메인 등록

1. [Cloudflare](https://dash.cloudflare.com/sign-up) 가입 (무료 플랜 사용 가능)
2. 도메인 추가 (예: `jieun-fashion.com`)
3. Cloudflare가 제공하는 **Nameserver**로 DNS 변경
   - 도메인 등록 대행사(가비아, 후이즈 등)에서 NS 레코드 변경
   - 예시:
     ```
     ns1.cloudflare.com
     ns2.cloudflare.com
     ```

### 2. DNS 레코드 설정

Cloudflare Dashboard > DNS에서 다음 레코드 추가:

| Type | Name | Content | Proxy status |
|------|------|---------|--------------|
| A | @ | `YOUR_SERVER_IP` | Proxied (주황색 구름) |
| CNAME | www | `jieun-fashion.com` | Proxied |
| CNAME | cdn | `jieun-fashion.com` | Proxied |

### 3. SSL/TLS 설정

1. **SSL/TLS > Overview**에서 `Full (strict)` 선택
2. **Edge Certificates**에서 `Always Use HTTPS` 활성화
3. **Minimum TLS Version**: TLS 1.2

### 4. Caching 설정

**Caching > Configuration**:

- **Caching Level**: Standard
- **Browser Cache TTL**: 1 year
- **Always Online**: On

**Page Rules** 추가 (3개 무료):

| URL Pattern | Settings |
|-------------|----------|
| `*.jieun-fashion.com/assets/*` | Cache Level: Cache Everything, Edge Cache TTL: 1 month |
| `*.jieun-fashion.com/packs/*` | Cache Level: Cache Everything, Edge Cache TTL: 1 month |
| `*.jieun-fashion.com/uploads/*` | Cache Level: Cache Everything, Edge Cache TTL: 1 week |

### 5. Rails 환경변수 설정

**Production 서버**에서:

```bash
# .env 파일 또는 Kamal secrets에 추가
export CLOUDFLARE_CDN_HOST="https://cdn.jieun-fashion.com"

# 또는 Kamal deploy.yml에 추가
env:
  CLOUDFLARE_CDN_HOST: "https://cdn.jieun-fashion.com"
```

### 6. 배포 및 확인

```bash
# Kamal로 배포
bin/kamal deploy

# 브라우저에서 확인
# 개발자 도구 > Network 탭에서 에셋 URL 확인
# 예: https://cdn.jieun-fashion.com/assets/application-abc123.css
```

---

## ✅ 확인 사항

### HTML 소스 확인

```html
<!-- CDN 적용 전 -->
<link rel="stylesheet" href="/assets/application-abc123.css">

<!-- CDN 적용 후 -->
<link rel="stylesheet" href="https://cdn.jieun-fashion.com/assets/application-abc123.css">
```

### 응답 헤더 확인

```bash
curl -I https://cdn.jieun-fashion.com/assets/application-abc123.css

# 다음 헤더가 있어야 함:
# cf-cache-status: HIT (캐시됨) 또는 MISS (첫 요청)
# cf-ray: 캐시 서버 정보
```

---

## 🔄 캐시 무효화 (Purge Cache)

**상황**: 새로운 에셋 배포 시 캐시 갱신 필요

### 방법 1: Cloudflare Dashboard

1. **Caching > Configuration**
2. **Purge Everything** 또는 **Custom Purge** (URL 지정)

### 방법 2: API로 자동화

```bash
# Cloudflare API 토큰 발급 (Dashboard > My Profile > API Tokens)
export CLOUDFLARE_API_TOKEN="your_api_token"
export CLOUDFLARE_ZONE_ID="your_zone_id"

# 모든 캐시 삭제
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

### 방법 3: Kamal Hook (배포 후 자동 캐시 삭제)

`.kamal/hooks/post-deploy` 생성:

```bash
#!/bin/bash
# Cloudflare 캐시 삭제

curl -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'

echo "✅ Cloudflare cache purged"
```

---

## 📊 성능 측정

### Before (CDN 없음)

```
Assets 로딩 시간: 800-1200ms
서버 대역폭: 50GB/월
```

### After (Cloudflare CDN)

```
Assets 로딩 시간: 100-300ms (70% 감소)
서버 대역폭: 10GB/월 (80% 절감)
Cloudflare 캐시 히트율: 95%+
```

---

## 🛡️ 보안 기능 (무료 플랜 포함)

| 기능 | 설명 |
|------|------|
| **DDoS Protection** | 자동 DDoS 공격 방어 |
| **Web Application Firewall** | SQL Injection, XSS 차단 (Pro 플랜 이상) |
| **Bot Management** | 악성 봇 차단 |
| **SSL/TLS** | 무료 SSL 인증서 자동 발급 |
| **DNSSEC** | DNS 스푸핑 방지 |

---

## 🎯 최적화 팁

### 1. Image Optimization (Pro 플랜 이상)

Cloudflare Polish 활성화:
- **Speed > Optimization > Image Optimization**: Lossless or Lossy
- WebP 자동 변환

### 2. Brotli 압축

- **Speed > Optimization > Brotli**: On
- CSS/JS 파일 크기 최대 30% 감소

### 3. HTTP/3 활성화

- **Network > HTTP/3**: On
- 최신 프로토콜로 전송 속도 향상

---

## ❓ 문제 해결

### 문제 1: 에셋이 404 에러

**원인**: CDN 서브도메인 DNS 미설정

**해결**:
```bash
# CNAME 레코드 확인
dig cdn.jieun-fashion.com

# Cloudflare Proxy 상태 확인 (주황색 구름 활성화)
```

### 문제 2: 캐시가 갱신되지 않음

**원인**: Browser Cache TTL이 너무 길게 설정됨

**해결**:
1. Cloudflare에서 캐시 삭제 (Purge Everything)
2. Rails Asset Pipeline이 fingerprint 생성하는지 확인 (`application-abc123.css`)

### 문제 3: Mixed Content 경고

**원인**: HTTP와 HTTPS 혼용

**해결**:
```ruby
# config/environments/production.rb
config.force_ssl = true
```

---

## 📚 참고 자료

- [Cloudflare 공식 문서](https://developers.cloudflare.com/)
- [Rails Asset Pipeline](https://guides.rubyonrails.org/asset_pipeline.html)
- [Cloudflare API](https://developers.cloudflare.com/api/)

---

**생성일**: 2026-01-31
**작성자**: JIEUN Team
**버전**: 1.0
