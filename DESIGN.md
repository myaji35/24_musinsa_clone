---
name: JIEUM (지음)
description: 두 럭셔리 하우스의 문법 — 발렌시아가의 차가운 뼈대와 마르지엘라의 단일 크기 글자 — 을 한국 여성복 쇼핑몰의 것으로 소화한 디자인 시스템
colors:
  paper: "#FCFCFC"
  paper-2: "#F7F7F2"
  placeholder: "#EAEAE6"
  ink: "#000000"
  ink-2: "#404040"
  ink-3: "#767676"
  inverse: "#FFFFFF"
  line: "#000000"
  hairline: "#E5E5E5"
  sale: "#BF1D1D"
  notice: "#2D7652"
  scrim: "rgba(252, 252, 252, 0.85)"
typography:
  hero: { fontFamily: "Oswald, sans-serif", fontSize: "clamp(32px, 4vw, 56px)", fontWeight: 500, lineHeight: 1.0, letterSpacing: "0.04em", textTransform: "uppercase" }
  display: { fontFamily: "Oswald, sans-serif", fontSize: "22px", fontWeight: 500, lineHeight: "24px", letterSpacing: "0.05em", textTransform: "uppercase" }
  eyebrow: { fontFamily: "Oswald, sans-serif", fontSize: "12px", fontWeight: 400, lineHeight: "16px", letterSpacing: "0.2em", textTransform: "uppercase" }
  title: { fontFamily: "Pretendard Variable, Pretendard, sans-serif", fontSize: "14px", fontWeight: 600, lineHeight: "20px", letterSpacing: "-0.01em" }
  ui: { fontFamily: "Pretendard Variable, Pretendard, sans-serif", fontSize: "13px", fontWeight: 500, lineHeight: "16px", letterSpacing: "0" }
  body: { fontFamily: "Pretendard Variable, Pretendard, sans-serif", fontSize: "14px", fontWeight: 400, lineHeight: "22px", letterSpacing: "-0.005em" }
  caption: { fontFamily: "Pretendard Variable, Pretendard, sans-serif", fontSize: "12px", fontWeight: 400, lineHeight: "16px", letterSpacing: "0" }
  price: { fontFamily: "IBM Plex Mono, monospace", fontSize: "13px", fontWeight: 400, lineHeight: "16px", letterSpacing: "0", fontVariantNumeric: "tabular-nums" }
  price-lg: { fontFamily: "IBM Plex Mono, monospace", fontSize: "14px", fontWeight: 400, lineHeight: "20px", letterSpacing: "0", fontVariantNumeric: "tabular-nums" }
rounded:
  none: "0px"
  swatch: "999px"
spacing:
  gutter: "12px"
  grid-gap: "12px"
  grid-gap-mobile: "8px"
  band: "36px"
  header: "60px"
  header-mobile: "56px"
  category-row: "40px"
  control: "48px"
  chip: "24px"
  info-column: "450px"
  section: "80px"
  section-mobile: "56px"
components:
  button-primary: { backgroundColor: "{colors.ink}", textColor: "{colors.inverse}", borderColor: "{colors.ink}", borderWidth: "1px", borderRadius: "{rounded.none}", height: "{spacing.control}", padding: "0 24px", font: "{typography.ui}", boxShadow: "none" }
  button-secondary: { backgroundColor: "transparent", textColor: "{colors.ink}", borderColor: "{colors.ink}", borderWidth: "1px", borderRadius: "{rounded.none}", height: "{spacing.control}", padding: "0 24px", font: "{typography.ui}", boxShadow: "none" }
  button-text: { backgroundColor: "transparent", textColor: "{colors.ink}", textDecoration: "underline", textUnderlineOffset: "3px", font: "{typography.ui}" }
  category-chip: { backgroundColor: "transparent", textColor: "{colors.ink}", height: "{spacing.chip}", padding: "0 8px", borderWidth: "1px", borderColor: "transparent", selectedBorderColor: "{colors.ink}", borderRadius: "{rounded.none}", font: "{typography.ui}" }
  product-card: { imageAspect: "2 / 3", imageBackground: "{colors.placeholder}", textAlign: "left", nameFont: "{typography.ui}", priceFont: "{typography.price}", priceColor: "{colors.ink-2}", gapBelowImage: "12px", boxShadow: "none", borderRadius: "{rounded.none}" }
  site-band: { backgroundColor: "{colors.ink}", textColor: "{colors.inverse}", height: "{spacing.band}", font: "{typography.caption}" }
  site-header: { backgroundColor: "{colors.paper}", height: "{spacing.header}", borderBottom: "1px solid {colors.line}", boxShadow: "none", layout: "left text buttons · center wordmark · right text buttons" }
  input: { backgroundColor: "transparent", textColor: "{colors.ink}", borderWidth: "1px", borderColor: "{colors.hairline}", focusBorderColor: "{colors.ink}", borderRadius: "{rounded.none}", height: "{spacing.control}", padding: "0 12px", font: "{typography.body}" }
  divider-strong: { borderTop: "1px solid {colors.line}" }
  divider: { borderTop: "1px solid {colors.hairline}" }
  flash: { backgroundColor: "{colors.paper}", borderWidth: "1px", borderColor: "{colors.ink}", borderRadius: "{rounded.none}", padding: "12px 16px", font: "{typography.body}" }
  overlay: { backgroundColor: "{colors.scrim}", backdropFilter: "none", borderBottom: "1px solid {colors.line}" }
---

# Design System: JIEUM (지음)

## Overview

**Creative North Star: "The Quiet Fitting Room" (조용한 피팅룸)**

JIEUM의 화면은 조용한 피팅룸이다. 거울 앞에는 옷과 가격표만 있고, 벽은 아주 옅은 오프화이트이며, 선은 검정 1px 하나뿐이다. 글자는 거의 한 크기로 또박또박 적혀 있어 어느 것도 소리치지 않는다. 사진이 말하고, 글자는 라벨처럼 붙어 있다.

대표님이 지정한 두 레퍼런스는 성격이 다르다. 발렌시아가는 순백·순흑·촘촘한 4열 그리드와 전체폭 사각 버튼의 "차가운 뼈대"이고, 메종 마르지엘라는 오프화이트 종이 위에 13px 한 크기 글자, 간격 0의 큰 2:3 사진, 기호(▸ ») 를 쓰는 "타자기 라벨"이다. JIEUM은 둘을 반반 섞지 않는다. **뼈대는 발렌시아가, 글자 결과 색은 마르지엘라**로 역할을 나눈다.

**섞는 원칙(한 줄):** 발렌시아가의 뼈대(헤더 3분할·4열 12px 그리드·상세 좌우 2분할·전체폭 사각 버튼) 위에, 마르지엘라의 살갗(오프화이트 #FCFCFC·13px 단일 크기 500·2:3 사진·1px 선으로 묶은 선택 행)을 입힌다. 두 하우스의 로고·SVG·사진·문구·노이즈 질감은 가져오지 않는다.

**핵심 특징:**

- 오프화이트 종이(#FCFCFC) 위의 순검정 글자, 보조색은 회색 둘(#404040, #767676)뿐
- 거의 모든 글자가 13px/16px·500 — 위계는 크기가 아니라 굵기·간격·대문자 콘덴스드로 만든다
- 4열 12px 그리드, 좌우 여백 12px, 사진 2:3(카탈로그 원본 720×1080과 동일 비율이라 잘리지 않는다)
- 그림자·둥근 모서리 없음. 깊이는 1px 선과 배경 교대로만
- 가격은 `₩ 239,000` — 모노스페이스 숫자, 글자색 #404040
- 한글은 `word-break: keep-all`, 최소 12px(ISS-144 계승)

## 레퍼런스 분석

2026-11-10 실제 브라우저(1440×900, macOS)에서 계산된 스타일을 추출했다. 원본: `scratchpad/ref/bal/*.json`, `scratchpad/ref/mm/*.json`, 캡처 `*-1440*.png`, `*-clean*.png`. 마르지엘라 PLP/PDP JSON의 `card.prices`·`buttons`에는 홈 상품·로그인 패널이 섞여 있어 그리드 값과 `typeCombos`만 믿고 화면은 캡처로 판단했다.

### 폰트

| 항목 | 발렌시아가 ko-kr | 메종 마르지엘라 ko-kr |
|---|---|---|
| 한글 본문 face | `YDGothic520` (윤고딕 520, 유료) | CSS 이름은 `CourierNewRecast`·`HelveticaNowProText`이지만 실제 파일은 `NotoSansKR-Medium.ttf`·`NotoSansKR-Regular.ttf` |
| 한글 강조 face | `YDGothic550` (제목·상품명·대문자 머리말) | 같은 Noto Sans KR Medium(굵기 하나) |
| 라틴 face | `BB-Regular`(본문)·`BB-CondBold`(머리말, 콘덴스드 대문자) — 자체 폰트 | `Margiela Sans`·`Margiela Mono` 변수는 있으나 KR에서 로드 안 됨 |
| `:root` 폰트 변수 | `--bal-font-base: "BB-Regular"`, `--bal-font-headings: "BB-CondBold"` | `--mm-font-sans-serif`, `--mm-font-monospace`, `--mm-body-font-size: 1rem`, `--mm-body-line-height: 1.5` |
| 로고 | 콘덴스드 대문자 SVG, 가운데, 약 128×15px | 세리프 SVG, 가운데, 200×27px |

### 글자 조합(빈도순, 계산된 스타일)

| 발렌시아가 (PLP, 사용 횟수) | 마르지엘라 (PLP, 사용 횟수) |
|---|---|
| 12px / 15.6px / 400 / 자간 0.12px — **239** (카드 가격·푸터·보조) | 13px / 16px / 500 / 자간 0 — **525** (거의 전부) |
| 14px / 19.6px / 400 — 109 (본문·메뉴) | 13px / 16px / 500 / uppercase — 101 (메뉴·카테고리·버튼) |
| 10px / 13px / 400 / uppercase — 36 (국가·언어 등 각주) | 13px / 16px / 400 / 자간 -0.13px (HelveticaNow→Noto Regular) — 51 |
| 12px / 15.6px / 400 / 자간 0.36px / uppercase — 29 (상단 메뉴) | 10~11px — 4건뿐 |
| 14px / 16.1px / 400 / 자간 0.42px / uppercase (YDGothic550) — 13 (섹션 머리) | 13px 700 — 1건 |
| 12px / 13.8px / uppercase (YDGothic550) — 12 (**카드 상품명**) | — |
| 22px / 24.2px / 자간 1.1px(0.05em) / uppercase — 1 (**PLP h1**, 홈 타일 제목) | — |
| 45px / 63px BB-Regular — 4 (장식 숫자) | — |

요약: 발렌시아가는 12·14px 두 크기 + 22px 머리말, 전부 400(강조는 face 교체). 마르지엘라는 13px·500 하나다. 두 사이트 모두 굵기 700을 사실상 쓰지 않는다.

### 색

| 항목 | 발렌시아가 | 마르지엘라 |
|---|---|---|
| 배경 | `#FFFFFF` (순백) | `#FCFCFC` (헤더·푸터·본문 실측) — 변수 `--mm-body-bg: #f7f7f2`(ecru-05) |
| 글자 기본 | `#000000` (507회) | `#000000` (521회), `#121212` (116회) |
| 글자 보조 | `#767676` (52회) · `#555555` | `#404040` (**가격**, 35회) · `#6C6C6C` · `#707070` |
| 선 | 헤더 아래 1px `#000` · 구분선 `#E5E5E5` 계열 | 1px `#000` (사이즈 선택 위아래) · `#E5E5E5` (`--color-mm-base-neutral-100`) · `#CCCCCC` |
| 이미지 자리 | `#D8D8D8` (54회) · `#F6F5F3` | `#EAEAE6` (`--mm-ecru-10`) ~ `#1F1F1E` (`--mm-ecru-90`) 9단 회색 |
| 강조 | 거의 없음. `#0066FF` 링크 3회(프리오더) | `--mm-danger #F4502F`, dark-red `#BF1D1D`, success `#41AA75`, info `#1F69FF` (알림 전용) |
| 팝업 배경 | `rgba(255,255,255,.5)` | `rgba(252,252,252,.85)` + 노이즈 질감 이미지 |
| 푸터 | `#AAAAAC` 회색 띠 | `#FCFCFC` (본문과 동일) |

### 헤더·레이아웃

| 항목 | 발렌시아가 | 마르지엘라 |
|---|---|---|
| 상단 띠 | 검정 약 45px, 12px 흰 글자, 닫기 × | 없음 |
| 헤더 높이 | 45px(띠 포함 90px), 흰 배경, 아래 1px 검정선 | 60px, `#FCFCFC`, 좌우 패딩 14.82px, 선 없음(그림자 없음) |
| 헤더 구성 | 왼쪽 텍스트 메뉴(12px, 자간 0.36px) · 가운데 로고 · 오른쪽 고객서비스/로그인/검색/위시/백 아이콘 | 왼쪽 "☰ 메뉴" "⌕ 검색" 텍스트 버튼(13px 500 uppercase, 46×24) · 가운데 세리프 로고 · 오른쪽 ✱(위시) 계정 백 아이콘 |
| 검색 | 헤더 아래 전체폭 44px 입력 줄(홈), 좌 아이콘 | "검색" 글자 버튼 → 패널 |
| PLP 카테고리 | 필터/정렬 텍스트 + 아이콘 (오른쪽) | 상단 고정 줄: 카테고리 글자 13px 500 uppercase, 선택 항목만 1px 검정 사각 테두리(24px 높이, 패딩 0 7.41px), 오른쪽 "☰ 필터" |
| 브레드크럼 | 14px, 45px 줄, 아래 1px 선 | 헤더 왼쪽에 "▸레디 투 웨어 ▸▸드레스" 식 기호 계층 |
| 섹션 머리 | 22px 콘덴스드 대문자, 가운데 | 13px 500, 왼쪽, 위 "▸ 살펴보기" 기호 링크 |

### 목록(PLP) 그리드·카드

| 항목 | 발렌시아가 | 마르지엘라 |
|---|---|---|
| 열 | `345px × 4`, 컨테이너 1440 | `360px × 4`, 컨테이너 1440 |
| 간격 | 열 12px, 행 12px | **0 / 0** |
| 좌우 여백 | 12px | 0 |
| 이미지 비율 | 345×431 = **1.25 (4:5)**, `object-fit: cover` | 364×545 = **1.5 (2:3)**, `object-fit: cover`, 배경 흰색 |
| 상품명 | 12px/13.8 YDGothic550 uppercase, **가운데 정렬** | 13px/16 500, **왼쪽 정렬**, 사진 아래 16px |
| 가격 | 12px/15.6 400 `₩ 2,240,000`, 검정, 가운데 | 13px/16 500 `₩ 1,890,000`, **#404040**, 왼쪽 |
| 보조 | "3 색상", "지금 프리 오더"(파랑) | 없음 |
| 위시 | 하트 아이콘, 이미지 우상단 | `*` 기호, 이미지 우상단 |
| 호버 | 이미지 교체 | 없음 |

### 상세(PDP)

| 항목 | 발렌시아가 | 마르지엘라 |
|---|---|---|
| 좌우 분할 | 왼쪽 이미지 720px(절반, 1:1에 가까운 세로 스택) · 오른쪽 정보 열 466px(x=844부터) | 왼쪽 이미지 **720×1080(2:3) 세로 스택** · 오른쪽 정보 열 **450px**(x=735부터) |
| 제목 | 14px YDGothic550(굵은 느낌) | **13px 500 uppercase**(본문과 같은 크기) |
| 가격 | **14px** 400 `₩ 4,620,000` | 13px 500 `₩ 4,460,000` #404040 |
| 설명 | 14px/19.6 400 | 13px/16 500, 들여쓰기, "◆A·상세 정보 »" 기호 링크 |
| 선택 행 | 컬러 썸네일 + 사이즈 썸네일, 아래 1px #E5E5E5 | **"사이즈 선택 »" 행이 위아래 1px 검정선 사이**(높이 33px+패딩) |
| 주 버튼 | 검정 전체폭(466px) **약 40~44px**, 글자 12~14px 흰색, radius 0 | 검정 전체폭(450px) **48px**, 패딩 16px 29.64px, radius **1px**, 13px 500 uppercase |
| 보조 버튼 | 밑줄 텍스트 "매장 재고 확인" | 1px 검정 테두리 50px, 투명 |
| 입력 | 1px 검정, radius 4px, 40px | 테두리 없음(밑줄형), 16px 높이 텍스트 |
| 탭 | 14px 회색/검정 텍스트 탭 | "배송 옵션" 13px, 항목 "»" 기호 |

### 모션

| 항목 | 발렌시아가 | 마르지엘라 |
|---|---|---|
| 이징 변수 | `--ease: cubic-bezier(.4,0,.2,1)`, `--ease-fade: cubic-bezier(.19,1,.22,1)`, `--ease-transform / --ease-out-quint: cubic-bezier(.22,1,.36,1)`, `--ease-bounce: cubic-bezier(.65,-.55,.25,1.5)` | `cubic-bezier(0, 0, .58, 1)` (ease-out) 0.2s·0.3s |
| 실측 transition | `transform .3s ease-in-out`, `opacity .2s linear`, `box-shadow .15s ease-out` | `transform .2s`, `opacity .2s/.3s`, `.1s linear` |

### JIEUM 현재 상태(바꾸기 전)

`jieum/home.png`, `plp.png`, `pdp.png`(1440) 기준: Pretendard + Oswald 700 이탤릭 로고, 헤더 80px(회색 검색창 가운데, `shadow-sm`), 카테고리 줄 40px 회색 글자 굵게, 홈 랭킹 5열(`gap-x-4`), 카드 4:5 + 색상 점·사이즈·배지·평점, 상품명 15px 500, 가격 17px 700 `239,000원`, /products 는 별도 카드(테두리·`rounded-lg`·`hover:shadow-lg`·"보기" 버튼), 상세 제목 30px 700, 가격 30px 700, 사이즈 버튼 44px 회색 테두리, 2열 버튼(바로구매 테두리/장바구니 검정). 푸터 `bg-gray-100`. 글자 크기가 11~30px까지 10단계 이상이다.

## JIEUM 결정값과 근거

| 결정 | JIEUM 값 | 어디서 왔나 |
|---|---|---|
| 배경 | `#FCFCFC` | 마르지엘라 헤더·푸터·본문 실측. 순백(발렌시아가)보다 사진의 회색 스튜디오 배경이 덜 튄다 |
| 교대 배경 | `#F7F7F2` | 마르지엘라 `--mm-ecru-05`(body-bg 변수) |
| 이미지 자리 | `#EAEAE6` | 마르지엘라 `--mm-ecru-10` |
| 글자 | `#000` / `#404040` / `#767676` | 검정은 둘 다. #404040은 마르지엘라 가격색, #767676은 발렌시아가 보조색(흰 배경 대비 4.54:1, AA 통과) |
| 선 | `#000` 1px 구조선, `#E5E5E5` 1px 보조선 | 발렌시아가 헤더 밑선·마르지엘라 사이즈 행 / 두 사이트의 neutral-100 |
| 기본 글자 | 13px/16px 500 | 마르지엘라 단일 크기. 발렌시아가의 12px보다 1px 커서 한글 가독성 여유 |
| 본문 단락 | 14px/22px 400 | 발렌시아가 본문 14px. 줄간격은 19.6→22로 한글에 맞게 늘림 |
| 캡션 | 12px/16px | 발렌시아가 최빈 조합(12/15.6). ISS-144 최소 12px 규칙 유지 — 발렌시아가의 10px은 채택하지 않음 |
| 머리말 | Oswald 500 22px/24 자간 .05em 대문자 | 발렌시아가 PLP h1·홈 타일(22/24.2, 자간 1.1px, CondBold) |
| 상세 제목 | 14px 600 | 발렌시아가 PDP 제목(14px, 550 face). 마르지엘라처럼 본문과 거의 같은 크기 |
| 가격 | `₩ 239,000`, 모노 13px(#404040), 상세 14px | 표기·색은 마르지엘라, 상세 14px은 발렌시아가 |
| 헤더 | 띠 36px 검정 + 헤더 60px + 카테고리 줄 40px, 아래 1px 검정 | 띠·1px선·3분할은 발렌시아가(45px→36px로 축소), 60px·텍스트 버튼은 마르지엘라 |
| 그리드 | 4열, 간격 12px, 좌우 12px | 발렌시아가 그대로(1440에서 345px 열). 마르지엘라의 0 간격은 JIEUM 사진 배경 톤이 제각각이라 얼룩져 보인다 |
| 이미지 비율 | 2:3 | 마르지엘라. **JIEUM 카탈로그 원본이 720×1080(2:3)**이라 crop 없이 꽉 찬다(현재 4:5는 무릎을 자른다) |
| 카드 글자 정렬 | 왼쪽 | 마르지엘라. 한글은 왼쪽 정렬이 읽기 쉽고 상세 정보 열과 결이 맞는다 |
| 버튼 | 48px, radius 0, 검정 전체폭 / 1px 테두리 | 높이·전체폭은 마르지엘라(48px), 각진 모서리는 발렌시아가(0) |
| 입력 | 48px, 1px #E5E5E5 → 포커스 1px #000, radius 0 | 버튼과 같은 높이. 발렌시아가의 radius 4px은 버리고 0으로 통일 |
| 이징 | `cubic-bezier(.22,1,.36,1)` 400ms(transform) / 200ms(opacity·color) | 발렌시아가 `--ease-out-quint` + 마르지엘라 0.2s |
| 기호 | `»`(더 보기), `▸`(살펴보기 류 링크) — 텍스트 문자만 | 마르지엘라식 기호 화살표를 유니코드 문자로. 아이콘 SVG를 가져오지 않는다 |

## Colors

종이 한 장과 검정 잉크, 회색 둘. 색은 여기서 끝난다.

### Neutral

- **paper** (#FCFCFC): 본문·헤더·푸터·카드 배경. 순백이 아니라서 사진의 회색 스튜디오 배경과 싸우지 않는다.
- **paper-2** (#F7F7F2): 교대 섹션(상세 본문의 SIZE & FIT·실물 섹션 등). 두 종이의 차이는 눈에 띄지 않을 정도여야 한다.
- **placeholder** (#EAEAE6): 이미지가 로드되기 전 자리, 이미지 없음 상태.
- **ink** (#000000): 기본 글자, 구조선, 주 버튼 배경.
- **ink-2** (#404040): 가격, 보조 본문. "가격은 상품명보다 한 톤 낮다."
- **ink-3** (#767676): 캡션, 비활성, 메타 정보. 이보다 옅은 글자색은 쓰지 않는다(대비 4.5:1 하한).
- **inverse** (#FFFFFF): 검정 위의 글자.

### Lines

- **line** (#000000, 1px): 헤더 아래, 사이즈 선택 행 위아래, 섹션 머리 아래, 푸터 위. 화면당 "검정선"은 5개를 넘기지 않는다.
- **hairline** (#E5E5E5, 1px): 아코디언·표·입력 테두리·카테고리 줄 아래.

### Functional

- **sale** (#BF1D1D): 할인가·오류 문구에만. 배지 배경으로 쓰지 않는다.
- **notice** (#2D7652): 완료 알림 글자에만. 배경은 paper 그대로.
- **scrim** (rgba(252,252,252,.85)): 메뉴·검색 패널 뒤. 노이즈·블러 없이 단색 반투명.

### Named Rules

**The Two Grays Rule.** 회색은 #404040과 #767676 둘뿐이다. Tailwind `text-gray-500`·`text-gray-600`·`bg-gray-100` 같은 기본 팔레트를 손님 화면에 남기지 않는다.

**The Black Line Budget Rule.** 1px 검정선은 구조를 나누는 자리(헤더·선택 행·섹션 머리·푸터)에만 쓴다. 나머지는 hairline이다.

**The No Tint Rule.** 파랑·보라·초록 배지(현재 `bg-blue-100` 신상, `bg-green-100` 재입고)를 손님 화면에서 없앤다. 상태는 글자(캡션)로 말한다.

## Typography

세 폰트, 역할이 겹치지 않는다. 전부 OFL(무료·재배포 가능)이다.

| 역할 | 폰트 | 선택 이유 | 탈락 후보 |
|---|---|---|---|
| 한글·기본 | **Pretendard Variable** (OFL, jsdelivr 동적 서브셋 v1.3.9, 이미 로드 중) | 마르지엘라가 실제로 쓰는 Noto Sans KR보다 자폭이 좁고 숫자·라틴이 깔끔해 13px 단일 크기에서 밀도가 맞다. 가변 폰트라 400/500/600을 파일 하나로 쓴다. 이미 운영 중이라 교체 위험이 0이다 | Noto Sans KR: 글자가 크고 넓어 13px에서 마르지엘라와 같은 "타자기 라벨" 밀도가 안 나오고, 전 화면 폰트 교체는 위험 대비 효과가 작다 |
| 라틴 콘덴스드(로고·머리말·아이브로) | **Oswald** 400·500 (OFL, Google Fonts, latin subset, 이미 로드 중) | 발렌시아가 BB-CondBold의 "좁고 곧은 대문자" 역할. 500 대문자 + 자간 .05~.2em으로 쓰면 700 이탤릭이던 현재 로고의 스포츠 느낌이 사라진다 | Archivo Narrow: 덜 좁아 22px 대문자에서 헬베티카 콘덴스드에 가깝지만 새로 로드해야 하고 Oswald와 구분 가치가 작다. Barlow Condensed: 둥글어 차가운 느낌이 약하다 |
| 가격·코드·숫자 | **IBM Plex Mono** 400·500 (OFL, Google Fonts, latin subset) | 마르지엘라의 타자기 결을 "숫자"에만 입힌다. Plex 가족에 IBM Plex Sans KR이 있어 한글 고딕 옆에서 설계된 비례라 13px에서 Pretendard와 x-height가 맞는다. 400이 충분히 진해 작게 써도 흐리지 않다 | Courier Prime: Courier New Recast에 가장 가깝지만 획이 가늘고 x-height가 낮아 13px 한글 옆에서 흐릿하다. JetBrains Mono: 코드 에디터 인상이 강해 쇼핑몰 가격에 어색하다 |

**로드 방식**

- Pretendard: `https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css` (현행 유지, `preconnect cdn.jsdelivr.net`).
- Oswald + IBM Plex Mono: Google Fonts 한 요청. `https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;700&family=IBM+Plex+Mono:wght@400;500&display=swap`. Oswald 700은 인트로(`intro.css`)가 아직 쓰므로 Phase 5에서 인트로를 재조정한 뒤 제거한다. 두 폰트 모두 latin subset만 내려온다(Google Fonts가 unicode-range로 자동 분할).
- `font-display: swap`. 모노·오스왈드는 장식 역할이라 FOUT이 보여도 레이아웃이 흔들리지 않는다(가격은 `tabular-nums`로 폭 고정).

**Character:** 글자는 라벨이다. 크기를 키워 외치지 않고, 굵기 한 단계(400→500→600)와 대문자 콘덴스드 한 줄로 위계를 만든다.

### Hierarchy

- **Hero:** Oswald 500, `clamp(32px, 4vw, 56px)`, 1.0, .04em, 대문자. 홈 전폭 사진 위 한 줄(발렌시아가 홈 타일). 라틴 전용 — 한글 문구는 `display`로 내려간다.
- **Display:** Oswald 500, 22px/24px, .05em, 대문자. 섹션 머리("NEW ARRIVALS", "RANKING"). 한글 섹션 머리("JIEUM 랭킹")는 Pretendard 600 14px `title`로 쓰고 그 위에 Oswald 아이브로를 둔다.
- **Eyebrow:** Oswald 400, 12px/16px, .2em, 대문자, ink-3. "POINT 01", "SIZE & FIT".
- **Title:** Pretendard 600, 14px/20px, -0.01em. 상세 상품명, 장바구니·주문서 h1, 아코디언 제목.
- **UI:** Pretendard 500, 13px/16px. 메뉴·버튼·카테고리 칩·카드 상품명·라벨·표 머리. **화면의 70% 이상이 이 한 조합이어야 한다.**
- **Body:** Pretendard 400, 14px/22px. 상품 설명·정책·리뷰 본문. 한 줄 60자 이내(정보 열 450px에서 자연히 맞는다).
- **Caption:** Pretendard 400, 12px/16px, ink-3. 메타·각주·푸터 링크·"N가지 색상".
- **Price:** IBM Plex Mono 400, 13px/16px, `tabular-nums`, ink-2. `₩ 239,000` — 기호와 숫자 사이 공백 하나. 상세·장바구니 합계는 **price-lg** 14px/20px.

### 한글 규칙

- `word-break: keep-all; overflow-wrap: anywhere;` 를 body에 유지한다(현행).
- 최소 12px. 발렌시아가의 10px 각주는 채택하지 않는다(ISS-144).
- 13px 한글은 줄간격 16px(한 줄 라벨)에서만 허용한다. 두 줄 이상 이어지는 한글은 반드시 `body`(14/22)로 올린다.
- 대문자 변환(`uppercase`)은 라틴 문자열에만 건다. 한글에 `tracking-widest`를 걸지 않는다(자간은 라틴 콘덴스드 전용).
- 가격 표기는 `₩ 239,000` 하나로 통일한다. 스크린리더는 "원 239,000"으로 읽으므로 의미가 유지된다. `239,000원`으로 되돌릴 때는 헬퍼 `won()` 한 줄만 바꾼다.

### Named Rules

**The One Size Rule.** 손님 화면의 라벨·메뉴·버튼·카드는 13px/16px/500 하나다. 새 크기를 추가하려면 이 문서의 Hierarchy에 먼저 적는다.

**The Weight Ladder Rule.** 굵기는 400·500·600 세 단뿐이다. 700·800은 손님 화면에서 쓰지 않는다(현재 `font-bold`·`font-extrabold`·`font-oswald italic`은 전부 교체 대상).

**The Latin-Only Condensed Rule.** Oswald와 IBM Plex Mono에는 한글을 넣지 않는다. 한글이 섞이는 문자열은 Pretendard다.

## Layout

컨테이너는 없다. 화면은 좌우 12px 여백을 두고 끝까지 쓴다(발렌시아가·마르지엘라 모두 1440을 꽉 채운다). 읽는 글이 긴 화면(주문서·정책·장바구니)만 가운데 정렬 열 `max-width: 720px`를 쓴다.

### 그리드

| 뷰포트 | 열 | 열 간격 | 행 간격 | 좌우 여백 | 카드 폭(참고) |
|---|---|---|---|---|---|
| ≥1024px | 4 | 12px | 40px | 12px | 1440에서 345px (발렌시아가와 동일) |
| 768–1023px | 3 | 12px | 32px | 12px | — |
| <768px (375 기준) | 2 | 8px | 28px | 12px | 171.5px, 사진 높이 257px |

- 상품 사진은 항상 `aspect-ratio: 2 / 3`, `object-fit: cover`, 배경 placeholder.
- 홈 랭킹·스토리·매거진·캐릭터·/products 가 전부 같은 그리드를 쓴다(현재 5열·4열·3열이 섞여 있다).
- `<img sizes>`는 `(min-width: 1024px) 25vw, (min-width: 768px) 33vw, 50vw`.

### 헤더(공통 레이아웃)

위에서부터:

1. **Band** 36px, ink 배경, caption 12px inverse. 가운데 "전 상품 무료배송 · 7일 내 반품", 오른쪽 끝(데스크톱만) 로그인/워크스페이스/로그아웃/주문조회 텍스트 링크. 스크롤하면 올라간다.
2. **Header** 60px, paper, 아래 1px line, `position: sticky; top: 0`. 좌측 x=12: "메뉴" "검색" 텍스트 버튼(UI 13/500). 가운데: JIEUM 워드마크(Oswald 500 22px 자간 .22em 대문자, 이탤릭 없음). 우측: "주문조회" "장바구니 (2)" 텍스트 버튼. 아이콘 없음.
3. **Category row** 40px, 아래 1px hairline. 칩 24px 높이, 패딩 0 8px, 선택된 칩만 1px ink 테두리(마르지엘라). 가로 스크롤 허용.
4. 관리자(`mall_admin?`) 메뉴 줄은 카테고리 줄 아래 같은 40px 규격으로 남긴다. 링크·경로·색상 태그는 건드리지 않고 글자 크기만 caption 12px로 맞춘다.

모바일(<768): Band 32px(문구만), Header 56px — 좌 "메뉴", 중앙 워드마크 18px, 우 "장바구니 2". "주문조회"·검색창은 메뉴 패널 안으로 들어간다. 카테고리 줄은 가로 스크롤.

메뉴·검색 패널: 헤더 바로 아래 전체폭, scrim 배경, 아래 1px line, 패딩 24px 12px. 검색은 발렌시아가처럼 전체폭 44px 입력 한 줄.

### 상세(PDP) 레이아웃

- ≥1024: 2열. 왼쪽 50%(1440에서 708px, 좌 여백 12px) 사진을 2:3으로 세로 스택(간격 0 — 마르지엘라). 오른쪽 열은 x=50%+24px부터 `max-width: 450px`, `position: sticky; top: 84px`(헤더 60 + 24).
- <1024: 사진 스택 → 정보 열 순서로 1열. 하단 고정 구매 바 56px(기존 유지, 토큰 적용).
- 정보 열 순서(위에서): 상품명(title) · 가격(price-lg) · 착용 모델 한 줄(caption) · 설명(body) · **선택 행**(위아래 1px line: "색상" 행, "사이즈" 행) · 주 버튼 48px · 보조 버튼 48px · 배송 한 줄(caption) · 아코디언(hairline).

### 섹션 리듬

- 데스크톱 섹션 간격 80px, 모바일 56px.
- 섹션 머리: 아이브로(Oswald 12px) + 제목(title 14px) 왼쪽 정렬, 아래 1px line, 제목과 그리드 사이 24px.

### Named Rules

**The 12px Edge Rule.** 모든 화면의 좌우 여백은 12px이다. 카드·헤더·푸터가 같은 세로선에 맞아야 한다. 유일한 예외는 읽기 열(720px 가운데 정렬)이다.

**The Full Frame Rule.** 상품 사진은 2:3 프레임을 꽉 채운다. 4:5·3:4·1:1 프레임을 손님 화면에 남기지 않는다(상세 본문의 "실물 디테일" 정사각형만 예외 — 실물 사진은 900×1200(3:4)이라 `object-contain`).

## Elevation & Depth

그림자는 쓰지 않는다. 현재 `shadow-sm`(헤더)·`hover:shadow-lg`(/products 카드)·`shadow-sm`(찜 버튼)은 전부 제거한다. 깊이는 paper/paper-2 교대와 1px 선으로만 만든다. 패널은 scrim 반투명 단색이다. 둥근 모서리는 0이며 색상 견본 원(999px)만 예외다.

### Named Rules

**The Flat Paper Rule.** `box-shadow`·`backdrop-filter`·`border-radius > 0`(견본 원 제외)을 손님 화면에 두지 않는다.

## Components

- **button-primary:** ink 배경, inverse 글자, 1px ink 테두리, 48px, radius 0, UI 13/500, 패딩 0 24px, 전체폭. hover: 배경 #1F1F1E(마르지엘라 ecru-90), 200ms. disabled: 배경 placeholder·글자 ink-3·테두리 placeholder(불투명도 트릭 금지).
- **button-secondary:** 투명 배경, 1px ink, 48px, radius 0, UI 13/500. hover: 배경 paper-2.
- **button-text:** 밑줄(offset 3px) UI 13/500. "사이즈 안내", "배송·반품 안내 전체 보기".
- **symbol-link:** `▸ 살펴보기`, `상세 정보 »` — UI 13/500, 기호는 문자, 기호와 글자 사이 공백 하나. 밑줄 없음, hover에 밑줄.
- **category-chip:** 24px, 패딩 0 8px, 1px 투명 테두리 → 선택 시 ink. 배경 채움 없음(현재 `bg-black text-white` 칩은 폐기).
- **product-card:** 2:3 사진(placeholder 배경) → 12px → 상품명(UI, ink, 두 줄 말줄임) → 4px → 가격(price, ink-2) → 색상 2개 이상이면 4px → "N가지 색상"(caption). 찜: 1.25px 선 하트 20px, 사진 우상단 8px, 데스크톱은 hover·포커스 시, 터치 기기는 항상 표시(`@media (hover: none)`). 배지·사이즈 범위·평점·착용 라벨은 카드에서 뺀다(상세에서 보여 준다). 할인: 가격을 sale 색으로, 정가는 옆에 caption 취소선.
- **rank-mark:** 홈 랭킹 번호. Oswald 400 12px inverse, 24×24 ink 사각, 사진 좌상단 0,0.
- **site-band / site-header / category-row:** Layout 절 참고.
- **input / select / textarea:** 48px, 1px hairline, radius 0, 패딩 0 12px, body 14px. focus: 테두리 ink, outline 없음. 라벨은 UI 13/500, 입력 위 8px. 수량 입력은 폭 96px.
- **size-chip:** 44px 높이·최소 폭 48px, 1px hairline, UI 13/500. 선택: 1px ink + 글자 ink. 품절: 글자 ink-3 취소선, 커서 not-allowed. 행 전체는 위아래 1px line 사이에 "사이즈" 라벨과 함께 놓인다(마르지엘라).
- **swatch:** 16px 원(999px), `ring-1 ring-black/15`. 색 이름 UI 13px 옆에.
- **divider-strong / divider:** 1px line / 1px hairline. `<hr>` 또는 `border-t`.
- **accordion:** `<details>` 그대로. summary는 title 14/600, 패딩 16px 0, 사이 hairline, 열림 표시는 끝의 `+`/`−` 문자(13px).
- **table:** 머리 UI 13/500 ink-3, 셀 body 14px, 행 사이 hairline, 숫자 열 `tabular-nums` 우측 정렬.
- **flash:** paper 배경, 1px ink, 패딩 12px 16px, body 14px. 성공은 글자 notice, 오류는 글자 sale. 색 배경·라운드 없음.
- **footer:** paper, 위 1px line, 패딩 48px 12px 80px. 열 4개(브랜드 문장 2열 + HELP + POLICY), 머리 Oswald 12px 아이브로, 링크 caption 12px ink-2. 맨 아래 caption ink-3.
- **mobile-buy-bar:** 56px, paper, 위 1px line, 왼쪽 price-lg, 오른쪽 button-primary(높이 44px) "구매하기".
- **empty-state:** 가운데, title 14/600 + body, 버튼은 secondary. 아이콘 없음.

측정되지 않은 상태(active·focus 등)는 위 정의에 없는 한 추가하지 않는다. focus-visible은 전 요소 공통 `outline: 1px solid #000; outline-offset: 2px`.

## Motion

- 이징: `--ease-out: cubic-bezier(.22, 1, .36, 1)` (발렌시아가 ease-out-quint) 하나만 쓴다.
- 시간: 색·불투명도 200ms, 위치·크기 400ms.
- 사진 hover 확대(`group-hover:scale-105`)는 없앤다. 두 하우스 모두 사진을 키우지 않는다. 대신 Phase 5에서 두 번째 사진으로 교체(opacity 200ms).
- 패널 열림: `opacity 0→1` 200ms + `translateY(-4px→0)` 400ms.
- `prefers-reduced-motion: reduce`: 모든 transition을 0ms로.
- 홈 인트로(`intro.css`)의 스크롤 연출은 이 시스템의 예외 구역이다. 글자 토큰(Oswald 500·13px)만 맞추고 연출은 유지한다.

### Named Rules

**The One Curve Rule.** 손님 화면의 transition은 `--ease-out` 하나, 200ms/400ms 둘로 끝난다. `ease-in-out`·`linear`·bounce를 새로 쓰지 않는다.

## Do's and Don'ts

1. **베끼지 않는다.** 발렌시아가·마르지엘라의 로고·SVG 아이콘·사진·문구·노이즈 이미지·CSS 변수 이름(`--bal-*`, `--mm-*`)을 가져오지 않는다. 가져오는 것은 치수·비율·굵기·색값 같은 "문법"뿐이다.
2. **크기로 외치지 않는다.** 글자는 13px 라벨이 기본이고, 강조는 500→600, 또는 Oswald 아이브로 한 줄이다. 24px 이상 한글 제목을 손님 화면에 새로 만들지 않는다(인트로 제외).
3. **색을 더하지 않는다.** Tailwind 기본 `gray-*`·`blue-*`·`green-*`·`purple-*`·`amber-*`를 손님 화면에 남기지 않는다. 허용된 색은 YAML의 12개다.
4. **그림자·둥근 모서리를 쓰지 않는다.** 견본 원만 예외.
5. **사진을 자르지 않는다.** 2:3 프레임, 확대 hover 없음.
6. **한글에 자간·대문자 규칙을 걸지 않는다.** `uppercase`·`tracking-*`은 Oswald·Plex Mono의 라틴 문자열 전용.
7. **관리자 화면(/workspace, admin 계열)은 건드리지 않는다.** 공통 헤더의 관리자 줄은 구조·링크를 유지하고 글자 크기만 맞춘다.
8. **한 번에 다 바꾸지 않는다.** `docs/plan/2026-11-10-luxury-redesign-plan.md`의 Phase 순서를 따르고, 단계마다 1440·375 캡처로 확인한 뒤 다음으로 간다.
9. **가격 표기는 헬퍼 하나로만 찍는다.** `won(amount)` 외에 `number_to_currency(... unit: "") + "원"`을 뷰에 직접 쓰지 않는다.

## 시스템으로 승격하지 않은 것

- **마르지엘라의 노이즈 질감·`*` 위시 기호·세리프 로고:** 브랜드 고유 장치라 가져오지 않는다. 위시는 선 하트, 로고는 Oswald 워드마크.
- **발렌시아가의 10px 각주·radius 4px 입력·회색(#AAAAAC) 푸터:** 10px은 ISS-144 최소 크기 위반, radius는 0으로 통일, 푸터는 paper 유지.
- **마르지엘라의 0 간격 그리드:** 사진 배경 톤이 균일할 때만 성립한다. JIEUM 카탈로그 배경이 균일해지면 재검토.
- **홈 인트로의 검정 시네마 구역과 Oswald 700 이탤릭:** 운영 중인 기능(ISS-119·123·124)이라 Phase 5에서 글자 토큰만 맞춘다. 발렌시아가식 전폭 사진 히어로로 교체할지는 대표님 결정 사항.
- **가격 `₩` 표기:** 럭셔리 문법에 맞춰 채택했으나 한국 쇼핑 관습(`원`)과 다르다. 대표님 확인 전까지 헬퍼 뒤에 둔다.
