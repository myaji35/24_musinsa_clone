# JIEUM 럭셔리 리디자인 구현 계획 (2026-11-10)

> 기준 문서: `DESIGN.md`(저장소 루트). 이 계획은 Codex 에 단계별로 그대로 넘기는 작업 지시서다. 토큰·치수·색값은 DESIGN.md 의 YAML 과 "JIEUM 결정값" 표를 단일 진실로 삼고, 여기서는 **어느 파일의 무엇을 어떻게 바꾸는지**만 적는다.
>
> 대표님 지시: "design.md 기준으로 css, font 등을 상세히 분석해서 적용". 컨셉 레퍼런스는 발렌시아가(뼈대)·메종 마르지엘라(글자 결·색). 두 브랜드의 로고·SVG·사진·문구·노이즈 이미지는 가져오지 않는다.

## 0. 전체 원칙

- **손님 화면만** 바꾼다: 홈(`/`), 목록(`/products`), 상세(`/products/:id`), 장바구니(`/cart`), 주문서(`/checkout/new`), 주문조회(`/orders/lookup`), 로그인(`/login`), 정책(`/privacy`, `/returns`), 매거진, 캐릭터 페이지. `/workspace`·`admin_*`·`sales`·`inventory`·`suppliers`·`purchase_orders`·`dashboard`·`kpi`·`trends`·`product_analyses`·`product_specs`·`partner` 레이아웃은 **손대지 않는다**.
- 공통 레이아웃 `app/views/layouts/application.html.erb` 에는 `mall_admin?` 조건의 관리자 메뉴 줄이 2곳(데스크톱·모바일) 있다. **링크·경로·조건문을 그대로 두고** 클래스만 바꾼다. 관리자 링크의 색상 클래스(`text-blue-600` 등)는 건드리지 않는다.
- 단계(Phase)마다 **브랜치 하나·커밋 하나**(`design/luxury-p1` …). 각 단계는 단독 배포·단독 되돌리기가 가능해야 한다.
- 단계마다 아래 "검증"을 통과한 뒤 다음 단계로 간다. 검증은 Codex 보고가 아니라 **직접 캡처·테스트 실행**으로 판정한다.
- Tailwind v4(`tailwindcss-rails`, `app/assets/tailwind/application.css`). 빌드 산출물은 gitignore 라 캡처 전 `bin/rails tailwindcss:build` 가 필요하다.
- 캐시: 상품 카드는 `cache(["product-card-v3", ...])`, 홈 랭킹 그리드는 `cache(["ranked-products-grid", ...])` 조각 캐시(10분)를 쓴다. 마크업을 바꾸는 단계는 **반드시 캐시 키 버전을 올린다**(v3→v4). 올리지 않으면 10분 동안 옛 카드가 섞여 보인다.
- 시스템 테스트가 보는 문구·선택자: `test/system/homepage_test.rb`(`assert_text "JIEUM 랭킹"`, `.grid`, 인트로 선택자), `test/system/products_test.rb`(`.grid`, `.font-bold` minimum 1, `assert_text "#{price}원"`). 바꾸는 단계에서 테스트도 같이 고친다.

### 공통 검증 절차

```bash
cd "/Volumes/GH_APFS/0053_JIEUN(MUSINSA)/musinsa_clone"
bin/rails tailwindcss:build
bin/rails s -p 3053 -P tmp/pids/server3053.pid -d          # 3000 번 운영 서버는 건드리지 않는다
# 캡처 (playwright 는 /tmp/ujt/pw1110 에 설치돼 있음. 깨져 있으면 rm -rf node_modules && npm i playwright@1.64.1)
npx --prefix /tmp/ujt/pw1110 playwright screenshot --viewport-size=1440,900 --full-page http://localhost:3053/ docs/user-test/2026-11-10-luxury/p1-home-1440.png
npx --prefix /tmp/ujt/pw1110 playwright screenshot --viewport-size=375,812  --full-page http://localhost:3053/ docs/user-test/2026-11-10-luxury/p1-home-375.png
bin/rails test test/system                                   # 단계별 표에 적힌 테스트
bin/rubocop
kill $(cat tmp/pids/server3053.pid)
```

캡처는 `docs/user-test/2026-11-10-luxury/<phase>-<page>-<width>.png` 로 저장하고, 각 단계의 체크리스트를 눈으로 확인한다. 캡처 결과를 브라우저(HTML 뷰어)로 띄워 대표님께 보여 준다.

### 공통 되돌리기

- `git revert <단계 커밋>` 한 번. 폰트 링크·토큰·뷰가 한 커밋에 있으므로 부분 되돌림이 필요하면 아래 각 단계의 "되돌리기" 항목을 따른다.
- 조각 캐시는 키 버전을 되돌리면 옛 마크업으로 즉시 복귀한다(10분 기다릴 필요 없음). 급할 때는 `bin/rails runner 'Rails.cache.clear'`.

---

## Phase 1 — 토큰·폰트·헤더·푸터·상품 카드·목록 그리드 (효과 큼, 위험 낮음)

### 1-1. 테마 토큰 — `app/assets/tailwind/application.css`

파일 전체를 아래로 교체한다(기존 `--font-sans`·`--font-oswald`·`@layer base` 의 keep-all 은 유지된다).

```css
@import "tailwindcss";

/* JIEUM 디자인 시스템 — DESIGN.md 의 YAML 토큰과 1:1. 값은 DESIGN.md 가 정본 */
@theme {
  /* 폰트 */
  --font-sans: "Pretendard Variable", Pretendard, -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif;
  --font-display: "Oswald", sans-serif;
  --font-oswald: "Oswald", sans-serif;            /* intro.css·기존 뷰 호환용 별칭. Phase 5 에서 제거 */
  --font-mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, monospace;

  /* 색 — Tailwind 기본 팔레트는 남겨 둔다(관리자 화면이 쓴다). 손님 화면은 아래 토큰만 쓴다 */
  --color-paper: #FCFCFC;
  --color-paper-2: #F7F7F2;
  --color-placeholder: #EAEAE6;
  --color-ink: #000000;
  --color-ink-2: #404040;
  --color-ink-3: #767676;
  --color-inverse: #FFFFFF;
  --color-line: #000000;
  --color-hairline: #E5E5E5;
  --color-sale: #BF1D1D;
  --color-notice: #2D7652;
  --color-scrim: rgba(252, 252, 252, 0.85);

  /* 글자 크기(줄간격 포함) — text-ui, text-body, text-caption, text-title, text-display, text-eyebrow 로 사용 */
  --text-caption: 12px;  --text-caption--line-height: 16px;
  --text-ui: 13px;       --text-ui--line-height: 16px;
  --text-body: 14px;     --text-body--line-height: 22px;
  --text-title: 14px;    --text-title--line-height: 20px;
  --text-display: 22px;  --text-display--line-height: 24px;
  --text-eyebrow: 12px;  --text-eyebrow--line-height: 16px;

  /* 자간 */
  --tracking-display: 0.05em;
  --tracking-eyebrow: 0.2em;
  --tracking-wordmark: 0.22em;

  /* 치수 — h-band, h-header, h-control, h-chip 등으로 사용 */
  --spacing-gutter: 12px;
  --spacing-band: 36px;
  --spacing-header: 60px;
  --spacing-header-m: 56px;
  --spacing-catrow: 40px;
  --spacing-control: 48px;
  --spacing-chip: 24px;
  --spacing-info: 450px;

  /* 모션 */
  --ease-out: cubic-bezier(.22, 1, .36, 1);
  --radius-none: 0px;
}

@layer base {
  body {
    background-color: var(--color-paper);
    color: var(--color-ink);
    font-size: var(--text-ui);
    line-height: var(--text-ui--line-height);
    letter-spacing: 0;
    word-break: keep-all;
    overflow-wrap: anywhere;
  }
  /* 손님 화면 공통 포커스 */
  :where(a, button, input, select, textarea, summary):focus-visible {
    outline: 1px solid var(--color-ink);
    outline-offset: 2px;
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { transition-duration: 0ms !important; animation-duration: 0ms !important; }
  }
}

@layer components {
  /* 가격 — 헬퍼 won() 이 찍는 span 에 붙는다 */
  .price { font-family: var(--font-mono); font-variant-numeric: tabular-nums; color: var(--color-ink-2); font-size: var(--text-ui); line-height: var(--text-ui--line-height); }
  .price-lg { font-size: 14px; line-height: 20px; }
  .price-sale { color: var(--color-sale); }

  /* 버튼 */
  .btn { display: inline-flex; align-items: center; justify-content: center; height: var(--spacing-control); padding: 0 24px; border: 1px solid var(--color-ink); border-radius: 0; font-size: var(--text-ui); line-height: var(--text-ui--line-height); font-weight: 500; transition: background-color 200ms var(--ease-out), color 200ms var(--ease-out); cursor: pointer; }
  .btn-primary { background: var(--color-ink); color: var(--color-inverse); }
  .btn-primary:hover { background: #1F1F1E; }
  .btn-primary:disabled { background: var(--color-placeholder); border-color: var(--color-placeholder); color: var(--color-ink-3); cursor: not-allowed; }
  .btn-secondary { background: transparent; color: var(--color-ink); }
  .btn-secondary:hover { background: var(--color-paper-2); }
  .btn-text { text-decoration: underline; text-underline-offset: 3px; font-weight: 500; }

  /* 카테고리 칩(마르지엘라식 선택 테두리) */
  .chip { display: inline-flex; align-items: center; height: var(--spacing-chip); padding: 0 8px; border: 1px solid transparent; font-size: var(--text-ui); font-weight: 500; white-space: nowrap; }
  .chip[aria-current="page"], .chip.is-selected { border-color: var(--color-ink); }

  /* 입력 */
  .field { height: var(--spacing-control); padding: 0 12px; border: 1px solid var(--color-hairline); border-radius: 0; background: transparent; font-size: var(--text-body); color: var(--color-ink); width: 100%; }
  .field:focus { border-color: var(--color-ink); outline: none; }

  /* 기호 링크 */
  .sym { font-weight: 500; }
  .sym:hover { text-decoration: underline; text-underline-offset: 3px; }
}
```

하지 말 것: 기존 Tailwind 기본 색(`gray-*` 등)을 `@theme` 에서 지우지 않는다(관리자 화면이 쓴다). `--font-sans` 스택 순서를 바꾸지 않는다.

### 1-2. 폰트 링크 — `app/views/layouts/application.html.erb` `<head>`

기존 Oswald 링크 한 줄을 아래로 교체한다. Pretendard jsdelivr 링크와 preconnect 는 그대로 둔다.

```erb
<link href="https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
```

Oswald 700 은 `intro.css` 가 쓰므로 이 단계에서는 유지한다(Phase 5 에서 제거).

### 1-3. 가격 헬퍼 — `app/helpers/application_helper.rb`

```ruby
# 가격 표기 단일 지점(DESIGN.md Typography/Price). 되돌릴 때는 이 메서드만 바꾼다.
# variant: :default(13px) | :lg(14px, 상세·합계)
def won(amount, variant: :default, sale: false)
  classes = [ "price", ("price-lg" if variant == :lg), ("price-sale" if sale) ].compact.join(" ")
  tag.span("₩ #{number_with_delimiter(amount.to_i)}", class: classes)
end
```

- 이 단계에서 `won()` 을 쓰는 곳: `products/_card.html.erb`, `products/index.html.erb`(손님 분기). 나머지 뷰(상세·장바구니·주문서·매거진·스냅)는 Phase 2·4 에서 차례로 바꾼다.
- 테스트: `test/helpers/application_helper_test.rb` 에 `won(239000)` → `"₩ 239,000"` 포함·`class="price"` 단언 추가.

### 1-4. 헤더·푸터 — `app/views/layouts/application.html.erb` `<body>`

구조를 아래와 같이 바꾼다. **ERB 조건문(`logged_in?`, `mall_admin?`, `magazine_available?`, `cart_count`)과 모든 경로 헬퍼는 그대로 재사용한다.** 아이콘 SVG 는 전부 제거하고 텍스트 버튼으로 바꾼다(마르지엘라 "메뉴/검색" 방식).

```
body.bg-paper.text-ink.font-sans.antialiased  (data-controller="lazy-load" 유지)
├─ div.band            h-band bg-ink text-inverse text-caption  (모바일 h-8)
│   ├─ p (가운데) "전 상품 무료배송 · 7일 내 반품"
│   └─ nav (오른쪽, hidden md:flex, gap-4)  ← 기존 "Top Utility Bar" 의 링크들을 그대로 옮긴다
│        logged_in? 분기 / 로그인 / 주문조회 / 장바구니 (n)
├─ header.sticky.top-0.z-50.bg-paper.border-b.border-line   h-header-m md:h-header, px-gutter
│   grid grid-cols-[1fr_auto_1fr] items-center
│   ├─ 왼쪽: details.menu > summary "메뉴"  ·  details.search > summary "검색"(hidden md:inline-flex)
│   │     (summary 는 button 모양: text-ui font-medium, list-none, cursor-pointer, h-chip)
│   │     details 두 개에 name="header-panel" 을 준다(배타적 열림, 미지원 브라우저는 둘 다 열릴 수 있음 — 허용)
│   ├─ 가운데: a[href="/"] "JIEUM"  font-display font-medium text-[18px] md:text-[22px] tracking-wordmark uppercase  (italic·font-bold 제거)
│   └─ 오른쪽: a 주문조회(hidden md:inline-flex) · a "장바구니 (n)"  text-ui font-medium gap-4 justify-end
│        장바구니 수량은 괄호 숫자로만. 빨간 원형 배지(bg-red-600 rounded-full) 제거
│
│   details.menu 의 패널(absolute left-0 right-0 top-full bg-scrim border-b border-line px-gutter py-6):
│     - 모바일 전용 검색 폼(md:hidden) — 아래 search 패널과 같은 폼
│     - ul: "전체"(root_path) + shop_categories 각 항목(root_path(category:, anchor: "ranking")) + "상품"(products_path) + 매거진(magazine_available? 조건) + 모바일 전용 "주문조회"
│       li a: text-ui font-medium py-2 block
│   details.search 의 패널(같은 위치, 높이 44px 행): 기존 form_with(root_path, :q) 그대로, input 은 .field h-11 border-0 border-b border-line, placeholder "무엇을 찾고 계신가요?" 대신 기존 문구 유지 가능
│
├─ div.catrow  h-catrow border-b border-hairline px-gutter flex items-center gap-2 overflow-x-auto   (모바일에도 표시 — 기존 hidden md:block 제거)
│   └─ a.chip "전체" + shop_categories 각각 a.chip  (선택 판별 로직은 기존 "Secondary Category Nav" 의 params[:category] 비교식을 그대로 옮기고, 선택 항목에 aria-current="page")
│   (기존 "모바일 메뉴" div 는 삭제 — 랭킹/상품/매거진 링크는 메뉴 패널로 이동)
├─ mall_admin? 관리자 줄 2개(데스크톱·모바일): 위치·링크·조건 그대로. 바깥 div 클래스만 `border-b border-hairline px-gutter py-2 text-caption flex flex-wrap gap-x-4 gap-y-1` 로. 링크 클래스는 손대지 않는다.
├─ main  (flash: 바깥 div 를 `px-gutter pt-6` 로, 알림 박스는 `border border-ink px-4 py-3 text-body` + notice 는 `text-notice`, alert 는 `text-sale`. bg-green-50/rounded-lg 제거)
└─ footer.border-t.border-line.bg-paper.px-gutter.pt-12.pb-20.mt-20.text-caption.text-ink-2
    grid md:grid-cols-4 gap-8
    ├─ 브랜드(2열): "JIEUM" font-display font-medium text-display tracking-wordmark uppercase(italic 제거) + 기존 두 문장(text-caption text-ink-3)
    ├─ HELP: h4 font-display text-eyebrow tracking-eyebrow uppercase text-ink-3 + 기존 링크 3개(text-ink-2 hover:text-ink)
    ├─ POLICY: 같은 형식 + 기존 항목 2개(font-bold 제거)
    └─ 하단: border-t border-hairline pt-6 text-caption text-ink-3 (문구 유지 — ISS-148 결정)
```

하지 말 것: `cart_path`·`orders_lookup_path`·`workspace_path`·`logout_path`·`login_path`·`magazine_path` 호출을 지우거나 바꾸지 않는다. `data-controller="lazy-load"` 유지. 새 Stimulus 컨트롤러를 만들지 않는다(`<details>` 로 충분).

### 1-5. 상품 카드 — `app/views/products/_card.html.erb`

캐시 키를 `"product-card-v4"` 로 올린다. 내용:

```erb
<%= link_to product_path(product), class: "group block relative" do %>
  <div class="relative w-full aspect-[2/3] bg-placeholder overflow-hidden">
    <img ... class="w-full h-full object-cover" ...>      <%# group-hover:scale-105 transition-transform 제거 %>
    <%# 이미지 없음: text-caption text-ink-3 가운데 "이미지 준비 중" (uppercase·tracking-widest·font-bold 제거) %>
    <%# 찜 버튼: wishlist 컨트롤러·data 속성·aria 는 그대로. 위치 top-2 right-2, 버튼 w-8 h-8 bg-transparent shadow 없음, 아이콘 w-5 h-5 stroke-width 1.25 text-ink.
        표시: `opacity-0 group-hover:opacity-100 focus-within:opacity-100 [@media(hover:none)]:opacity-100` %>
  </div>
  <div class="mt-3 text-left">
    <h3 class="text-ui font-medium text-ink line-clamp-2"><%= product.name %></h3>
    <p class="mt-1"><%= won(product.price, sale: discount_rate(product) > 0) %>
      <% if discount_rate(product) > 0 %><s class="ml-2 text-caption text-ink-3"><%= won(discounted_price(product)) %></s><% end %>  <%# 정가/할인가 의미는 기존 헬퍼 동작을 확인한 뒤 맞춘다 %>
    </p>
    <% if (colors = product.color_names).size > 1 %>
      <p class="mt-1 text-caption text-ink-3"><%= colors.size %>가지 색상</p>
    <% end %>
  </div>
<% end %>
```

제거하는 것: 색상 점·사이즈 범위 줄, `% SALE` 배지, 평점 별·숫자, `worn_label`, `product_badges` 배지 줄, `min-h-[2.75em]`, `group-hover:underline`. (평점·착용 라벨은 상세에서 보여 준다 — Phase 2.)

하지 말 것: `product_image_source`·`wishlist` 컨트롤러 data 속성·`loading="lazy" decoding="async"`·캐시 키 구성 요소(variants updated_at, worn_character)를 지우지 않는다.

### 1-6. 목록 그리드 — 카드를 쓰는 모든 곳을 같은 그리드로

공통 그리드 클래스: `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-x-2 md:gap-x-3 gap-y-7 md:gap-y-10`

| 파일 | 바꿀 것 |
|---|---|
| `app/views/home/index.html.erb` | 바깥 `div#shop` 을 `max-w-[1600px] mx-auto px-4 md:px-8 py-6` → `px-gutter py-6` (컨테이너 제거). 랭킹 그리드 `grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-x-2 gap-y-8 sm:gap-x-4` → 공통 그리드. 캐시 키 `"ranked-products-grid"` → `"ranked-products-grid-v2"`. 랭킹 배지 div 를 `absolute top-0 left-0 z-10 w-6 h-6 grid place-items-center bg-ink text-inverse font-display text-caption` 로(`text-lg px-2.5 py-1 font-bold` 제거). 랭킹 머리: `h2.text-2xl.font-bold` → `<p class="font-display text-eyebrow tracking-eyebrow uppercase text-ink-3">RANKING</p><h2 class="text-title font-semibold">JIEUM 랭킹</h2>` (문구 "JIEUM 랭킹" 유지 — 테스트), 구분선 `border-b border-line pb-3` 유지, 갱신 시각 `text-caption text-ink-3`. 카테고리 필터 링크: `px-3 py-1.5 text-xs font-bold border … bg-black text-white` 류 → `chip` + 선택 시 `is-selected`. |
| `app/views/home/_story.html.erb` | 상품 그리드 `grid-cols-2 md:grid-cols-4 gap-x-4 gap-y-10` → 공통 그리드. 배너 `-mx-4 md:-mx-8` → `-mx-gutter`. "전체 보기" 링크 → `btn btn-secondary`. 캡션: 아이브로 `font-oswald text-sm tracking-[.2em]` → `font-display text-eyebrow tracking-eyebrow`, 제목 `text-3xl md:text-4xl font-bold` → `text-display font-display font-medium tracking-display uppercase`(영문일 때) / 한글 제목이면 `text-title font-semibold text-[18px]`. 이 단계에서는 배너 구조는 유지. |
| `app/views/home/_filter_section.html.erb` | 정렬 링크 4개 → `chip`(선택 `is-selected`). `text-sm text-gray-500` → `text-caption text-ink-3`. 검색 input → `field`. "초기화" → `btn btn-secondary h-chip px-3`. |
| `app/views/home/_category_grid.html.erb` | 원형 아이콘 그리드 → 텍스트 목록: `ul.flex.flex-wrap.gap-x-6.gap-y-2` + `a.sym "▸ 아우터"`. 제목 `text-lg font-bold` → `text-title font-semibold`. 이미지는 쓰지 않는다(이미지 자산은 지우지 않고 참조만 뺀다). |
| `app/views/products/index.html.erb` | **손님 분기 신설**: `mall_admin?` 가 false 이면 `<div class="px-gutter py-8">` + 머리(아이브로 "ALL PRODUCTS" + `h1.text-title.font-semibold` "상품 목록" + `p.text-caption.text-ink-3` "총 N개") + 공통 그리드에 `render partial: "products/card", collection: @products, as: :product`. `mall_admin?` 가 true 면 **기존 블록 그대로**(관리자 카드·버튼은 범위 밖). 빈 상태·검색 결과 없음 분기는 유지하되 손님 분기 안에서는 `text-title`·`text-body`·`btn btn-secondary` 로. |
| `app/views/magazine/show.html.erb`, `app/views/characters/show.html.erb` | 카드 그리드의 `grid-cols-*`·`gap-*` 만 공통 그리드로 교체. 다른 내용은 건드리지 않는다. |
| `app/views/products/show.html.erb` 연관 상품 | 이 단계에서는 **손대지 않는다**(Phase 2). |

`catalog_image_tag`·`image_tag` 의 `sizes` 가 있는 곳은 `"(min-width: 1024px) 25vw, (min-width: 768px) 33vw, 50vw"` 로 맞춘다.

### 1-7. 테스트 수정

- `test/system/products_test.rb`: `assert_selector ".font-bold", minimum: 1` → `assert_selector ".price", minimum: 1`. 상세의 `assert_text "#{…}원"` 은 Phase 2 에서 바꾸므로 이 단계에서는 상세 가격 표기가 아직 `원` 이라 그대로 통과한다.
- `test/system/homepage_test.rb`: 문구 "JIEUM 랭킹"·`.grid`·인트로 선택자는 유지되므로 수정 없음. 실행해 확인만.

### 1-8. 하지 말 것 (Phase 1)

- 상세 페이지(`products/show.html.erb`, `_detail_page.html.erb`, `_spec*.erb`), 장바구니, 주문서, 로그인 뷰는 열지 않는다.
- `app/assets/stylesheets/intro.css`, `home/_intro.html.erb` 는 열지 않는다.
- 발렌시아가·마르지엘라의 아이콘 SVG·로고·문구를 넣지 않는다. 기호는 `▸` `»` 유니코드 문자만.
- `font-bold`/`font-extrabold` 를 손님 화면에 새로 쓰지 않는다. 허용 굵기 `font-normal`·`font-medium`·`font-semibold`.
- `rounded-*`(견본 원 `rounded-full` 제외), `shadow-*`, `bg-gray-*`, `text-gray-*`, `bg-blue-*`, `bg-green-*` 를 손님 화면에 남기지 않는다(관리자 분기는 예외).

### 1-9. 검증 (Phase 1)

| URL | 뷰포트 | 확인 |
|---|---|---|
| `/` | 1440×900 전체 | 띠 36px 검정 → 헤더 60px(좌 "메뉴 검색", 중앙 JIEUM 정체 대문자 자간, 우 "주문조회 장바구니 (n)") → 아래 1px 검정선 → 카테고리 줄 40px·선택 칩에 1px 테두리. 인트로 아래 랭킹 그리드가 **4열·간격 12px·좌우 12px**, 사진 2:3, 상품명 13px 왼쪽, 가격 `₩ 239,000` 모노 회색. 카드에 배지·별점·색상 점 없음. 랭킹 번호 24px 검정 사각. 푸터 흰 바탕 + 위 1px 검정선. 그림자 없음. |
| `/` | 375×812 | 띠 32px, 헤더 56px(메뉴 · JIEUM · 장바구니 n), 카테고리 줄 가로 스크롤, 카드 2열 간격 8px, 가로 넘침 없음(`document.documentElement.scrollWidth === 375`). "메뉴" 탭 시 패널 열리고 검색창·카테고리·주문조회 보임. |
| `/products` | 1440·375 | 손님(비로그인)으로 열어 4열/2열 카드가 홈과 동일. "보기" 버튼·테두리 카드·`hover:shadow-lg` 없음. |
| `/?category=아우터` | 1440 | 카테고리 줄과 랭킹 필터 모두 "아우터" 칩만 1px 테두리. |
| 관리자 로그인 후 `/` | 1440 | 관리자 메뉴 줄 2개가 그대로 보이고 링크 전부 동작(색상 태그 유지). `/products` 는 관리자용 기존 카드. |
| 테스트 | — | `bin/rails test test/system test/helpers` 통과, `bin/rubocop` 0 offense. |
| 폰트 | DevTools Network | `IBM+Plex+Mono` woff2 와 `Oswald` 400/500/700 이 내려오고 Pretendard dynamic-subset 유지. 가격 span 의 computed font-family 가 "IBM Plex Mono". |

### 1-10. 되돌리기 (Phase 1)

- 전체: `git revert <p1 커밋>`.
- 가격 표기만: `ApplicationHelper#won` 본문을 `tag.span("#{number_with_delimiter(amount.to_i)}원", class: classes)` 로 바꾸고 시스템 테스트 단언 복원.
- 카드만: `_card.html.erb` 를 `git checkout main -- app/views/products/_card.html.erb` 후 캐시 키를 v5 로 올린다(v3 으로 내리면 10분 캐시가 옛 v3 조각을 되살릴 수 있으므로 **항상 위로** 올린다).
- 헤더만: 레이아웃 파일을 main 에서 복원하면 폰트 링크도 같이 돌아간다 → 1-2 의 링크 줄을 다시 넣어 토큰(`font-mono`)이 깨지지 않게 한다.

---

## Phase 2 — 상품 상세(PDP): 구매 상자·갤러리·상세 본문 글자

### 2-1. `app/views/products/show.html.erb`

- 바깥 컨테이너 `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 md:py-12` → `px-gutter py-6 lg:py-8`.
- `mall_admin?` 공개 상태 바(`publication-bar`)는 **그대로**(관리자 전용). AI 가상 인물 안내 `p` → `text-caption text-ink-3`.
- 메인 그리드 `grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-16` → `grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-6`.
- **갤러리**(`data-testid="product-gallery"`): 2열(`grid-cols-2 gap-1.5`) → **1열 세로 스택** `grid-cols-1 gap-0`(마르지엘라 720×1080 스택). `figure` 의 `col-span-2` 조건·zoom 컨트롤러·`data-real`·`figcaption` 은 유지. `sizes` → `"(min-width: 1024px) 50vw, 100vw"`(이미 그 값). `bg-gray-100` → `bg-placeholder`.
- 갤러리 없는 분기(영상·단일 이미지·썸네일 4칸): `aspect-[3/4]` → `aspect-[2/3]`, `bg-gray-100/50` → `bg-placeholder`, 썸네일 `border-2 border-black` → `border border-ink`.
- **정보 열**: `space-y-6 lg:sticky lg:top-24` → `lg:max-w-info lg:sticky lg:top-[84px] space-y-5`.
  - 브랜드 `p.text-sm.font-medium.text-gray-500.uppercase` → `text-caption text-ink-3`(uppercase 는 라틴 브랜드명일 때만 — 값이 "JIEUM" 이면 `font-display tracking-eyebrow uppercase`).
  - `h1.text-2xl.md:text-3xl.font-bold` → `text-title font-semibold`.
  - `detail-headline` p → `text-body text-ink`, sub → `text-body text-ink-2`.
  - 착용 모델 p → `text-caption text-ink-2`, 링크 `font-bold underline` → `underline underline-offset-3`.
  - 가격 `p.text-3xl.font-bold` → `<%= won(@product.price, variant: :lg) %>`.
  - `div.h-px.bg-gray-200` 삭제(선택 행이 선을 가진다).
  - **선택 행**(`fieldset[data-testid="variant-picker"]`): fieldset 에 `border-y border-line py-4 space-y-4`. legend "색상 / 사이즈" → `text-ui font-medium`(legend 는 fieldset 밖으로 그려지므로 `float-left w-full mb-3` 처리). 색상 라벨 `w-28 text-sm text-gray-800` → `w-28 text-ui`. 사이즈 라벨 span: `min-w-12 h-11 px-3 border border-gray-300 text-sm font-medium … peer-checked:ring-1` → `min-w-12 h-11 px-3 border border-hairline text-ui font-medium peer-checked:border-ink peer-disabled:text-ink-3 peer-disabled:line-through`(ring 제거). "사이즈 안내" → `btn-text text-ui`.
  - 배송 p → `text-caption text-ink-2`, `font-bold` → `font-medium`.
  - 수량 라벨 → `text-ui font-medium`, 입력 `w-24 border border-gray-400 p-3` → `field w-24`.
  - 버튼 2열 `grid-cols-2 gap-3` → **세로 2개** `space-y-2`: "장바구니" → `btn btn-primary w-full`, "바로구매" → `btn btn-secondary w-full`. 순서: 장바구니(위), 바로구매(아래). `disabled:opacity-40` 제거(`.btn-primary:disabled` 가 처리; secondary 는 `disabled:text-ink-3 disabled:border-hairline`).
  - 아코디언 `details`: 바깥 `border-t border-gray-200 divide-y divide-gray-200 text-sm` → `border-t border-hairline divide-y divide-hairline text-body`; summary `font-bold` → `text-title font-semibold py-1 list-none flex justify-between` + 끝에 `<span aria-hidden="true" class="text-ui">+</span>`(열림 시 `−` 는 `details[open] summary span::before` 대신 `group-open:` 로 — `details.group` 과 `group-open:hidden`/`group-open:inline` 두 span). 본문 `text-gray-700` → `text-ink-2`. dl `grid-cols-3` 의 dt → `text-ink-3`, dd → `text-ink`.
- **리뷰 섹션**: `border-t-2 border-gray-200 pt-12` → `border-t border-line pt-10`. h2 `text-xl md:text-2xl font-bold` → 아이브로 "REVIEWS" + `text-title font-semibold`. 별 `text-yellow-400` → `text-ink`(빈 별 `text-hairline`). 리뷰 카드 `border-gray-100` → `border-hairline`, 본문 `text-sm text-gray-700` → `text-body text-ink-2`, 메타 `text-xs text-gray-400` → `text-caption text-ink-3`, 태그 span `bg-gray-50 border border-gray-200` → `border border-hairline`. 관리자 리뷰 작성 폼(`mall_admin?`)은 입력만 `field` 로, 나머지 유지.
- **연관 상품**: 섹션 머리 동일 패턴. 그리드 → 공통 그리드(Phase 1-6). 내부 수제 카드 → `render partial: "products/card", collection: @related_products.take(4), as: :product`.
- 맨 아래 "의견 보내기" div → `px-gutter py-4 text-caption text-ink-3`.

### 2-2. `app/views/products/_detail_page.html.erb`

맨 위 로컬 변수 세 줄만 바꾼다(본문 구조는 유지 — ISS-142 모바일 세로 흐름):

```erb
<% eyebrow = "block font-display text-eyebrow tracking-eyebrow uppercase" %>
<% heading = "text-[20px] md:text-[22px] font-semibold leading-snug tracking-[-0.015em] text-balance" %>
```

추가 교체: `bg-[#f6f2ec]`·`bg-gray-50` → `bg-paper-2`; `bg-gray-100` → `bg-placeholder`; `text-gray-700/800` → `text-ink-2`; `text-gray-500/600` → `text-ink-3`; `text-[#8a6a4a]` → `text-ink-3`; `text-[#e7c9a5]` → `text-inverse`; `font-bold` → `font-semibold`; `text-lg font-bold` → `text-title font-semibold`; `text-[15px]` → `text-body`; `text-[17px] font-bold tabular-nums … 원` → `won(item.price, variant: :lg)`; `text-xs font-bold` 배지("실물 디테일"·"실물") → `text-caption font-medium`; 하단 CTA `a.bg-white.text-black.font-bold.py-4` → `btn btn-primary w-full` 의 반전(`bg-inverse text-ink border-inverse`). `bg-[#1b1b1d]` 섹션은 `bg-ink` 로. 모바일 구매 바: `bg-white border-t border-gray-200` → `bg-paper border-t border-line`, 가격 → `won(product.price, variant: :lg)`, 버튼 → `btn btn-primary h-11 flex-1 max-w-[60%]`.

### 2-3. `app/views/products/_spec.html.erb`, `_spec_measurements.html.erb`, `_return_policy.html.erb`

색·굵기 클래스만 위 매핑표대로 교체(`text-gray-*`→`text-ink-2/3`, `border-gray-*`→`border-hairline`, `font-bold`→`font-semibold`, `bg-gray-50`→`bg-paper-2`). 표 숫자 셀에 `tabular-nums`.

### 2-4. 테스트

- `test/system/products_test.rb:24` `assert_text "#{product.price.to_i.to_fs(:delimited)}원"` → `assert_text "₩ #{product.price.to_i.to_fs(:delimited)}"`.
- 상세 관련 단위·컨트롤러 테스트에 "원" 문자열 단언이 있는지 `grep -rn "원\"" test/` 로 확인해 같이 고친다.

### 2-5. 하지 말 것

- `form_with url: cart_items_path, id: "buy"` 의 필드 이름(`variant_id`, `quantity`, `buy_now`)과 `data-testid` 값을 바꾸지 않는다.
- zoom·wishlist Stimulus 컨트롤러 data 속성을 지우지 않는다.
- 상세 본문의 섹션 순서·조건문(`page["hero"]` 등)을 바꾸지 않는다.

### 2-6. 검증

| URL | 뷰포트 | 확인 |
|---|---|---|
| 상세 1개(`/products/<published id>`) | 1440 | 왼쪽 절반에 2:3 사진이 간격 0 으로 세로로 쌓이고, 오른쪽 열은 450px 이내·스크롤 시 고정. 제목 14px 600, 가격 `₩ 239,000` 14px 모노, 선택 행이 위아래 1px 검정선 사이, 버튼 2개 48px 세로(검정/테두리). 아코디언 `+`. 리뷰 별 검정. 연관 상품이 홈 카드와 동일. |
| 같은 상세 | 375 | 사진 스택 → 정보 열 순. 하단 구매 바 56px 흰 바탕·위 1px 검정선·가격 모노. 가로 넘침 없음. |
| 품절 옵션 있는 상품 | 1440 | 품절 사이즈 회색 취소선·클릭 불가. 옵션 없는 상품은 버튼이 회색 비활성. |
| 테스트 | — | `bin/rails test test/system/products_test.rb`, 상품 컨트롤러 테스트. |
| 기능 | — | 장바구니 담기 → `/cart` 수량 반영(기능 회귀 없음). |

### 2-7. 되돌리기

`git revert <p2 커밋>`. 상세만 되돌리고 Phase 1 을 유지해도 `won()`·토큰은 그대로라 깨지지 않는다(상세 가격은 `원` 표기로 돌아가고 테스트 단언도 같이 되돌아간다).

---

## Phase 3 — 홈 섹션·검색 빈 상태·인트로 글자

### 3-1. `app/views/home/_story.html.erb`

- 배너 캡션 그라데이션(`bg-gradient-to-t from-black/60`)은 유지하되 글자: 한글 제목 `text-[18px] font-semibold tracking-[-0.01em]`, 영문 아이브로 `font-display text-eyebrow tracking-eyebrow uppercase text-white/80`, 카피 `text-body text-white/90`.
- 섹션 사이 간격 `mb-20` → `mb-16 md:mb-20`.

### 3-2. `app/views/home/index.html.erb`

- 랭킹 섹션 `mt-16` → `mt-14 md:mt-20`. 필터 섹션과 그리드 사이 24px.

### 3-3. `app/views/products/_search_empty.html.erb`

아이콘 제거, `text-title font-semibold` + `text-body text-ink-2`, 되돌리기 링크 `btn btn-secondary`.

### 3-4. `app/views/home/_intro.html.erb` + `app/assets/stylesheets/intro.css` — 글자 토큰만

- `intro.css` 에서 `font-family: 'Oswald', sans-serif; font-weight: 700` 인 곳(`.intro-wordmark`, `.intro-card-band`, `.intro-card-initial`)을 `font-weight: 500` 으로, `.intro-eyebrow` 는 `letter-spacing: .2em`. `.intro-runway-copy h1`·`.intro-scene-heading h2`·`.intro-tagline-content h2`·`.intro-reel-heading h2` 의 `font-weight: 800` → `600`, `.intro-card-details h3` 800 → 600. `.intro-skip`·`.intro-cta`·`.intro-reel-details button` 의 `font-weight: 800/700` → `500`, `border-radius: 999px` → `0`.
- 연출(sticky·3D 링·영상)은 건드리지 않는다. 시스템 테스트 `homepage_test.rb` 의 인트로 선택자(`.intro-card-photo` 10개, `.intro-card-soon` 등)가 그대로 통과해야 한다.

### 3-5. 검증

`/` 1440 세 구간(0·900·1800 스크롤)과 375 캡처. 인트로 글자가 700/800 → 500/600 으로 가벼워졌는지, 스토리 배너 제목이 18px 600 인지, 검색 `?q=zzzz` 빈 상태가 아이콘 없이 나오는지. `bin/rails test test/system/homepage_test.rb`.

### 3-6. 되돌리기

`git revert <p3 커밋>`. intro.css 만 되돌려도 다른 단계에 영향 없음.

---

## Phase 4 — 장바구니·주문서·주문조회·로그인·정책·매거진·캐릭터

읽기 열 규칙: 바깥 컨테이너 `max-w-[720px] mx-auto px-gutter py-8 md:py-12`.

| 파일 | 바꿀 것 |
|---|---|
| `app/views/carts/show.html.erb` | h1 → 아이브로 "CART" + `text-title font-semibold`. 항목 `border-b border-gray-300 py-4` → `border-b border-hairline py-5`. 상품명 `font-bold` → `text-ui font-medium`. 옵션 `text-sm` → `text-caption text-ink-3`. 금액 → `won(item.line_total)`. 수량 입력 `w-20 border border-gray-400 p-2` → `field w-24 h-11`. "변경" → `btn btn-secondary h-11 px-4`. "삭제" → `btn-text text-caption`. 합계 `text-xl font-bold` → `flex justify-between border-t border-line pt-4 text-ui font-medium` + `won(@cart.total, variant: :lg)`. "비회원 주문하기" → `btn btn-primary w-full`. 빈 장바구니: `text-body text-ink-2` + "상품 둘러보기" `btn btn-secondary`. |
| `app/views/checkouts/new.html.erb` | h1 동일 패턴("CHECKOUT"). 오류 박스 `border border-black p-4` → `border border-sale text-sale px-4 py-3 text-body`. 항목 ul `border border-gray-300 divide-y divide-gray-200` → `border-y border-line divide-y divide-hairline`, 금액 → `won()`. 합계 → `won(@cart.total, variant: :lg)`. 라벨 `text-sm font-bold` → `text-ui font-medium`. 입력 `w-full min-w-0 border border-gray-400 p-3` → `field`. 안내문 `text-sm text-gray-600` → `text-caption text-ink-3`. 제출 버튼 → `btn btn-primary w-full`. 필드 이름·`inputmode`·`required`·체크박스·`data-testid` 는 유지. |
| `app/views/customer_orders/lookup.html.erb`, `show.html.erb`, `_payment_instruction.html.erb` | 같은 매핑(제목·라벨·입력·버튼·금액 `won()`). 표가 있으면 머리 `text-ui font-medium text-ink-3`, 셀 `text-body`, 행 `border-hairline`. |
| `app/views/sessions/new.html.erb` | h1 "관리자 로그인" 문구 유지, `text-title font-semibold`. 라벨 `text-ui font-medium mb-2`, 입력 `field`, 버튼 `btn btn-primary w-full`. `max-w-md` → `max-w-[400px]`. |
| `app/views/account_signups/new.html.erb` | 같은 폼 매핑(가입 플래그 꺼짐이라 노출 안 되지만 통일). |
| `app/views/policies/privacy.html.erb`, `returns.html.erb` | 읽기 열. h1 `text-title font-semibold`, h2 `text-ui font-medium mt-10 mb-3`, 본문 `text-body text-ink-2`, 표 hairline. |
| `app/views/magazine/index.html.erb`, `show.html.erb` | 제목·본문 매핑, 상품 그리드는 Phase 1 공통 그리드(이미 적용), 금액 `won()`. |
| `app/views/characters/show.html.erb` | 머리 매핑, 카드 그리드는 Phase 1 적용 확인. |
| `app/views/snaps/show.html.erb` | 금액 `won()`·색 매핑만(링크 안 되는 화면이라 최소). |
| `app/views/feedbacks/new.html.erb` | 폼 매핑(`field`, `btn`). |

테스트: `grep -rn "원\"\|원<\|원 " test/ --include=*.rb` 로 가격 단언을 찾아 `₩ ` 형식으로 수정. `bin/rails test`(전체).

검증: 1440·375 에서 `/cart`(상품 1개 담은 상태), `/checkout/new`, `/orders/lookup`, `/login`, `/privacy`, `/returns`. 입력 48px·1px 회색 테두리·포커스 시 검정, 버튼 48px, 가격 모노. 주문서 필수 4개 빈 제출 차단·정상 제출 흐름 회귀 없음(기존 야간 테스트 스크립트 `/tmp/ujt/scripts1110/walk.mjs` 가 통과해야 한다 — 선택자가 "비회원 주문하기" 문구 기준이므로 문구는 유지).

되돌리기: `git revert <p4 커밋>`.

---

## Phase 5 — 마무리: 호버 이미지 교체·레거시 정리·폰트 가중치 축소

- `_card.html.erb`: `product.gallery_image_urls` 두 번째 사진이 있으면 `<img>` 를 겹쳐 두고 `opacity-0 group-hover:opacity-100 transition-opacity duration-200 ease-[var(--ease-out)]`(캐시 키 v5). 사진이 하나면 변화 없음.
- 레이아웃 `<head>` 폰트 링크에서 Oswald `700` 제거(Phase 3 에서 intro.css 가 700 을 더 쓰지 않음을 `grep -n "700" app/assets/stylesheets/intro.css` 로 확인한 뒤).
- `@theme` 의 `--font-oswald` 별칭 제거 → `grep -rn "font-oswald" app/views app/assets` 가 0 건이어야 한다(관리자 뷰에 남아 있으면 그 뷰만 `font-display` 로 바꾸는 것은 허용 — 글자체 이름 변경일 뿐 디자인 변경이 아님).
- 손님 뷰에서 `grep -rn "text-gray-\|bg-gray-\|font-bold\|rounded-\(md\|lg\|xl\)\|shadow-" app/views/{home,products,carts,checkouts,customer_orders,sessions,policies,magazine,characters,layouts/application.html.erb}` 가 관리자 분기(`mall_admin?` 블록 내부) 외에 0 건.
- `docs/user-test/2026-11-10-luxury/` 캡처를 최종본으로 갱신하고 `DESIGN.md` 의 "시스템으로 승격하지 않은 것"을 실제 결과에 맞게 보정.

검증: 전체 `bin/rails test`, `bin/ci`(brakeman 경고 0), 1440·375 전 화면 캡처 재확인, Lighthouse 접근성(모바일) 점수가 Phase 0 대비 하락하지 않음(명령은 메모리 `factory-runner-local-env.md` 의 `CHROME_PATH=… npx -y lighthouse@12 …`).

되돌리기: `git revert <p5 커밋>`.

---

## 부록 A. 클래스 교체 규칙표(손님 화면 공통)

| 기존(Tailwind 기본) | 교체 | 비고 |
|---|---|---|
| `bg-white` | `bg-paper` | body 가 paper 라 대부분 삭제 가능 |
| `bg-gray-50`, `bg-gray-100`(면) | `bg-paper-2` | 이미지 자리면 `bg-placeholder` |
| `text-gray-900`, `text-black` | `text-ink` | 기본값이라 삭제 가능 |
| `text-gray-700`, `text-gray-800` | `text-ink-2` | |
| `text-gray-400/500/600` | `text-ink-3` | |
| `border-gray-100/200/300` | `border-hairline` | 구조선이면 `border-line` |
| `border-black` | `border-line` | |
| `font-bold`, `font-extrabold`, `font-black` | `font-semibold`(제목) / `font-medium`(라벨·버튼) | 손님 화면에서 700 이상 금지 |
| `text-xs` | `text-caption` | 12px 유지 |
| `text-sm`, `text-[15px]` | `text-ui`(한 줄 라벨) / `text-body`(두 줄 이상 한글) | |
| `text-base`, `text-lg` | `text-body` 또는 `text-title` | |
| `text-xl` ~ `text-3xl`(한글 제목) | `text-title font-semibold`(+ 위에 `font-display text-eyebrow` 아이브로) | 상세 본문 heading 은 20/22px 예외 |
| `font-oswald … uppercase tracking-*` | `font-display text-eyebrow tracking-eyebrow uppercase` 또는 `text-display tracking-display` | 라틴 전용 |
| `rounded-sm/md/lg/xl`, `rounded` | 삭제 | `rounded-full` 은 견본 원만 |
| `shadow-sm/lg` | 삭제 | |
| `bg-black text-white`(버튼) | `btn btn-primary` | |
| `border border-black`(버튼) | `btn btn-secondary` | |
| `underline`(링크 버튼) | `btn-text` | |
| `px-3 py-1.5 text-xs border …`(칩) | `chip` (+`is-selected`) | |
| `number_to_currency(x, unit: "", precision: 0)` + `원` | `won(x)` / `won(x, variant: :lg)` | |
| `transition-all`, `duration-300`, `ease-in-out` | `transition-colors duration-200 ease-[var(--ease-out)]` | transform 이면 `duration-400` |

## 부록 B. 캡처 체크리스트(모든 단계 공통)

1. 가로 넘침: `document.documentElement.scrollWidth === window.innerWidth`.
2. 글자 크기 12px 미만 0개: `[...document.querySelectorAll('main *')].filter(e => parseFloat(getComputedStyle(e).fontSize) < 12 && e.innerText?.trim()).length === 0`.
3. 손님 화면 굵기 700 이상 0개(인트로 제외): 같은 방식으로 `fontWeight >= 700`.
4. 그림자 0개: `getComputedStyle(e).boxShadow !== 'none'` 인 요소가 인트로 밖에 없음.
5. 검정 1px 구조선 ≤ 5개/화면.
6. 5xx·JS 콘솔 오류 0.

## 부록 C. 대표님 확인이 필요한 결정(구현 전)

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| 1 | 가격 표기 | A `₩ 239,000`(두 레퍼런스 동일, 모노 숫자) / B `239,000원` 유지 | **A**. 헬퍼 한 줄이라 언제든 B 로 복귀 가능 |
| 2 | 로고 글자 | A Oswald 500 정체 대문자 + 자간 .22em(발렌시아가식 콘덴스드 워드마크) / B 현재 Oswald 700 이탤릭 유지 | **A**. 이탤릭 볼드는 스포츠 브랜드 결이라 두 레퍼런스와 어긋남 |
| 3 | 기본 글자 크기 | A 13px(마르지엘라 단일 크기) / B 14px(발렌시아가 본문, 30~50대 가독성 여유) | **A** — 라벨·버튼·카드만 13px 이고 두 줄 이상 한글 본문은 14/22 로 올리므로 가독성 손실이 없다 |
| 4 | 홈 인트로(검정 시네마 구역) | A 유지하고 글자만 맞춤(Phase 3) / B 발렌시아가식 전폭 사진 히어로 한 장으로 교체 | **A** 우선. B 는 ISS-119·123·124 의 기능 삭제라 T2(DIRECTION) 결정 |
| 5 | 카드에서 빼는 정보 | A 배지·별점·색상 점·사이즈 범위를 카드에서 빼고 상세로(두 레퍼런스 동일) / B "N가지 색상" 외에 품절·신상 글자 캡션은 남김 | **A**. 품절은 Phase 2 상세에서 사이즈별로 보임 |

**결정(2026-11-10 대표님 "추천대로 진행해"):** 1-A `₩ 239,000` · 2-A Oswald 500 정체 대문자 · 3-A 기본 13px(두 줄 이상 한글 14/22) · 4-A 인트로 유지·글자만 · 5-A 카드는 이름·가격(+N가지 색상)만.
