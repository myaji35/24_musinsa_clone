# JIEUM 운영자 매뉴얼 빌드

저장소 루트에서 실행한다. 원고 `docs/manual/operator-manual.md`는 읽기만 한다.
앱·서버·브라우저는 이 도구를 실행하는 사용자의 환경에서 준비한다. 커밋은 하지 않는다.

## 필요한 것

- Rails 8 개발 DB와 기존 상품·옵션 최소 2개. 기본 계정은 앱과 동일한 `Account.primary` (`slug: jieum`)를 사용한다. 숫자 ID 1을 임의로 가정하지 않는다.
- 기존 관리자 `admin@jieun.test`. 계정이 없으면 앱의 기존 개발 데이터 준비 절차로 만든다. 이 스크립트는 관리자 비밀번호를 바꾸지 않는다.
- 기본 계정의 현재 `wechat_channel_mode: mac_app`. 다른 모드이면 seed가 중단되며 계정 설정을 변경하지 않는다.
- Node.js와 Playwright, Playwright Chromium. 아래 `NODE_PATH` 경로의 기존 패키지를 사용한다. ESM에서도 `createRequire`로 로드하므로 `NODE_PATH`가 적용된다.
- Python 3과 Pillow (`python3 -m pip install Pillow`). **pypdf 또는 poppler** 중 하나. `pypdf`가 있으면 텍스트 추출·병합에 사용하며, 없으면 `pdftotext -layout`과 `pdfunite`가 모두 필요하다. 예: `python3 -m pip install pypdf` 또는 `brew install poppler`.
- macOS 본문 글꼴 Apple SD Gothic Neo와 Menlo.
- 제목 글꼴 3개: `/Volumes/E_SSD/02_GitHub.nosync/0058_insuPro/videos/shorts/engine/fonts/Pretendard-{SemiBold,Bold,ExtraBold}.otf`. HTML의 `@font-face`가 `file://`로 읽는다. 글꼴이 없으면 빌드는 중단된다.

Chromium이 아직 없다면 다음 명령으로 한 번 설치한다.

```sh
export NODE_PATH=/Volumes/E_SSD/02_GitHub.nosync/0060_seoullive/node_modules
node -e 'require("playwright/cli")' install chromium
```

## 1. 예시 데이터

```sh
unset WECHAT_MAC_AUTO_SEND
RAILS_ENV=development bin/rails runner docs/manual/build/seed_demo.rb
```

DB 변경을 포함한다. 거래처·대화방·발주 메모·메시지 내용으로 기존 예시를 찾아 재사용한다. 발주 납기는 실행일 +21일로 갱신한다. 예시 발주를 실무에서 확정·입고·취소했다면 덮어쓰지 않고 중단하므로 먼저 해당 예시 상태를 확인한다. 동시에 여러 번 실행하지 않는다.

발주 2건은 작성 중과 제출됨이다. `PurchaseOrder#submit!` 및 `Wechat::PurchaseOrderNotifier.call`을 그대로 사용하며 `pending_manual`을 만든다. 처리 기록을 보여 주기 위해 별도의 `sent_manual` 통보 기록도 넣는다. 실제 위챗 발송, 이메일, Slack 전송은 하지 않는다. runner 프로세스의 ActiveJob 어댑터는 예시용 무발송 어댑터로 바꾸어 주문 콜백에서 외부 알림 작업도 등록하지 않는다.

입금 대기 주문이 하나도 없을 때만 가격·재고가 있는 기존 옵션을 골라 `Orders::Intake`로 1개 주문한다. 이 경우 앱 규칙대로 재고 1개 차감·출고 로그·배송지 스냅샷이 생긴다. 이름과 주소는 `예시 고객`, 전화·우편번호는 영(0)으로만 구성한 가상 값이다. 공장 클레임은 같은 거래처의 발주에 연결하되 기존 상품의 거래처를 변경하지 않기 위해 옵션 연결은 생략한다.

결과: `docs/manual/build/out/demo_ids.json`.

## 2. 화면 캡처

개발 서버를 별도 터미널에서 실행한 다음 캡처한다.

```sh
bin/rails server -p 3053
```

```sh
export NODE_PATH=/Volumes/E_SSD/02_GitHub.nosync/0060_seoullive/node_modules
# 기본 비밀번호가 다를 때만 설정한다.
export MANUAL_ADMIN_PASSWORD='JieunDev!2026'
node docs/manual/build/capture.mjs http://localhost:3053
```

`BASE_URL`은 첫 번째 위치 인자이며 생략하면 `http://localhost:3053`이다. 1366×900 CSS px, 배율 2로 캡처한다. 인증 정보를 출력하거나 파일로 저장하지 않는다. 대화 상세에 들어가면 앱 규칙대로 읽음 처리가 된다. 다시 안 읽음 예시가 필요하면 운영 DB가 아닌 개발 예시에서 준비한다.

`screens.json`은 장·주소·캡처 영역·번호별 locator를 정의한다. `{submitted_po_id}` 같은 치환은 URL과 선택자 모두 지원한다. `clip: "main"`은 바깥 레이아웃의 `body > main`, 다른 문자열은 CSS/Playwright 선택자다. `menu-row`는 판매현황부터 `menuEnd`(현재 클레임)까지 캡처한다. 6장은 거래처 연결·대화 내역과 두 메시지 폼을 각각 캡처한다. `clipMaxWidth`는 왼쪽 기준 최대 폭이며 8장은 900px 안에 입금 확인 버튼이 들어오는지 검증한다. `actions: [{"click": "선택자"}]`로 캡처 전에 버튼을 눌러 패널을 열 수 있다. 0장의 `ch0-feedback`은 의견 패널을 연 상태를 캡처한다. callout은 `selector` 또는 정확히 일치하는 `text`를 지정한다.

선택자는 `app/views/layouts/application.html.erb`, `suppliers/new`, `purchase_orders/{new,show}`, `wechat/{index,show,_settings,_message_actions,_purchase_order_messages}`, `admin_orders/index`, `sales/index`를 기준으로 정했다. 누락된 callout만 경고하고 계속하며, 인증 실패·화면 이동 실패·캡처 영역 누락은 중단한다. 앱의 버튼을 눌러 상태를 변경하지 않는다.

현재 원고와 화면이 다른 부분은 원고·앱을 고치지 않고 경고로 보존한다.

- 2장 ②: 거래처 신규 화면에 종류 입력이 없다.
- 7장 ②: 제출됨 발주에는 입고 버튼이 없다(`confirmed` 전용).
- 7장 ③: 현재 앱은 품목별 받은 수량 입력 없이 발주 수량 전량을 입고한다.
- 5장 ④: 별도의 수동 발송 기록에서 처리자·시각을 보여 준다.

결과는 `docs/manual/build/out/shots/<id>.png` 및 `.json`이다. JSON의 `width`, `height`, `callouts[].box`는 **캡처 좌측 상단 기준 CSS px**다. PNG 실제 픽셀은 그 값의 2배이며 `deviceScaleFactor`에 명시된다. 경고도 JSON에 남는다. 원고의 번호·순서를 유지하므로 누락된 번호를 재번호 매기지 않는다.

## 3. PDF·HTML

```sh
export NODE_PATH=/Volumes/E_SSD/02_GitHub.nosync/0060_seoullive/node_modules
python3 docs/manual/build/build.py
```

출력:

- `docs/manual/out/JIEUM_운영자매뉴얼_v1.0.pdf`
- `docs/manual/out/JIEUM_운영자매뉴얼_v1.0.html`

주석은 Pillow로 `build/out/annotated/<id>.png`에 합성한다(자동 분할은 `<id>-<번호>.png`). 번호는 Pretendard Bold, 포인트색 원·흰 숫자·흰 테두리이며 바깥 배치와 겹침 회피를 적용한다. 원 지름은 캡처 폭의 7/174로 정해 전체 폭 인쇄 시 약 7mm다. 높이 제한으로 축소되면 원도 같은 비율로 축소된다. HTML은 합성 PNG 하나를 그림으로 사용하고 최대 높이 118mm, 최대 폭 100%로 비율을 유지한다. 의견란·주의 상자·그림은 통째로 쪽을 넘긴다.

HTML은 이미지가 데이터 URL로 내장되어 미리보기 파일 하나로 볼 수 있다. 제목 글꼴은 위 로컬 경로가 필요하다. 인쇄 최종본은 PDF다. 긴 화면은 읽을 수 있는 크기를 유지하도록 여러 그림으로 나누고 각 그림에 원고 포인트 설명을 배치한다. 찾지 못한 포인트는 원고 설명을 유지하고 위치 누락 안내를 붙인다. 원고의 문장은 수정하지 않으며 표·굵은 글씨·고정폭 등 서식만 변환한다. 장 제목 외의 목적·언제 문장은 요약 상자에 그대로 들어간다. 손글씨 의견란·그림 캡션·문서 정보는 편집용 요소로 추가된다.

2패스 절차:

1. 고유 마커가 있는 전체 문서를 A4 PDF로 렌더한다.
2. pypdf 또는 `pdftotext -layout`으로 실제 장 시작 쪽을 찾는다. 표지부터 1쪽으로 센다.
3. 같은 레이아웃에 목차 쪽 번호를 넣고 다시 렌더한다. 목차 숫자는 고정 폭이며 마커는 자리 그대로 투명하게 유지한다.
4. 전체 문서의 `pageRanges`로 표지·문서 정보·목차·각 장을 출력한다. 표지에만 머리글·바닥글을 끈다. 나머지는 해당 장 제목과 전체 문서의 `n / 전체` 쪽 번호를 `headerTemplate`/`footerTemplate`으로 출력한다.
5. pypdf 또는 `pdfunite`로 순서대로 합친다. 1·2차 전체 쪽 수가 다르면 실패한다.

중간 HTML·PDF·렌더 작업 목록·쪽 번호 지도는 `docs/manual/build/out/pdf/`에 있다. 캡처와 출력은 생성물이며 `.gitignore`로 제외한다. 마커를 못 찾았을 때 임의의 쪽 번호로 배포하지 않는다.

## 구문 검사만 할 때

아래 명령은 Rails 데이터 생성이나 브라우저·서버 접속을 하지 않는다.

```sh
ruby -c docs/manual/build/seed_demo.rb
node --check docs/manual/build/capture.mjs
node --check docs/manual/build/pdf.mjs
python3 -m py_compile docs/manual/build/build.py
```
