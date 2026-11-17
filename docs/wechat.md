# 위챗 채널 운영

중국 공장 담당자와의 발주 통보·대화에 수동 복사, 맥 앱 에이전트, 공식계정 중 하나를 선택합니다. 기본은 수동 복사입니다. 아래 공식계정 준비 절차는 official 방식에서만 필요합니다. 현재 공식계정은 JIEUM 전용이며 수신은 기존 `Account.primary`(slug `jieum`)에 귀속됩니다. 다른 테넌트의 담당자를 이 공식계정에 연결하면 안 됩니다.

## 준비

1. 위챗 공식계정 관리자(mp.weixin.qq.com)에서 인증된 서비스 계정과 API 사용 권한을 준비합니다.
2. 개발 기본 설정에서 AppID와 AppSecret을 확인하고 서버 환경변수에 보관합니다. 화면에는 값 대신 설정 여부만 표시됩니다.
3. 관리자 `/wechat`에 표시되는 서버 URL을 서버 설정에 넣습니다. 기존 `APP_HOST` 설정을 사용하므로 운영에서는 공개 HTTPS 호스트를 지정합니다(예: `https://orders.example.com`). 경로는 `/webhooks/wechat`입니다.
4. 임의의 검증 Token을 설정하고 서버의 `WECHAT_TOKEN`과 동일하게 맞춥니다. 안전 모드 사용 시 EncodingAESKey도 동일하게 설정합니다. 서버 URL 확인 후 메시지 수신을 활성화합니다.
5. API 호출 서버의 고정 출구 IP를 위챗 IP 화이트리스트에 등록합니다.
6. 템플릿 메시지 기능을 신청하고 발주 통보에 적합한 템플릿을 승인받습니다. 승인된 템플릿의 필드와 코드의 `Wechat::PurchaseOrderNotifier` 데이터 필드(`number`, `item_count`, `quantity`, `delivery_date`)를 맞춥니다. 위챗이 발급하는 실제 필드명은 템플릿별로 다르므로, 운영 템플릿에 맞게 이 매핑을 수정해야 합니다.

## 공장 담당자 연결

공식계정 QR 팔로우 → 담당자가 메시지 한 번 보내기 → 관리자가 `/wechat`에서 미연결 담당자 대화 열기 → 거래처 선택 후 연결 저장. 한 거래처에 여러 담당자를 연결할 수 있습니다. 닉네임은 별도 프로필 조회를 하지 않으므로 초기에는 미연결 담당자로 표시됩니다.

일반 텍스트 답장은 마지막 사용자 메시지 후 48시간 내에만 보냅니다. 구독 이벤트만으로는 창을 열지 않습니다. 창이 닫힌 발주 통보는 설정된 템플릿으로 전환하며, 템플릿이 없으면 `window_closed`로 기록됩니다. 담당자가 공식계정에 메시지를 다시 보내야 일반 대화를 재개할 수 있습니다. 구독 해제 담당자에게는 발송하지 않습니다. API의 추가 발송량 제한·권한 오류는 `failed`로 표시됩니다.

발주 제출은 기존 이메일·Slack에 더해 백그라운드 위챗 작업을 등록합니다. 큐 워커를 실행해야 합니다. 위챗 실패가 발주 제출을 취소하지 않습니다. 발주 상세에서 결과를 확인하고 제출 상태 발주에 대해 재발송할 수 있습니다. 재발송은 중복 메시지를 만들 수 있으니 상태를 확인합니다.

## 환경변수

| 변수 | 용도 |
| --- | --- |
| `WECHAT_APP_ID` | 공식계정 AppID |
| `WECHAT_APP_SECRET` | 공식계정 API 비밀키 |
| `WECHAT_TOKEN` | 서버 서명 검증 Token |
| `WECHAT_ENCODING_AES_KEY` | 선택: 안전 모드 43자 AES 키 |
| `WECHAT_PO_TEMPLATE_ID` | 선택: 승인된 발주 알림 템플릿 ID |
| `WECHAT_SEND_ENABLED` | 정확히 `true`일 때만 API 발송. 기본 꺼짐 |
| `WECHAT_MAC_AUTO_SEND` | 정확히 `true`일 때만 맥 앱 자동 발송 승인·outbox 활성화. 기본 꺼짐 |
| `APP_HOST` | 기존 앱 공개 URL/호스트(발주 확정 링크·웹훅 URL) |

공식계정 API 발송을 끄면 유효한 메시지는 `disabled`로만 저장하고 토큰 요청을 포함해 외부 API를 호출하지 않습니다. 나중에 켜도 저장된 메시지를 자동 발송하지 않습니다. 본문은 1~2000자로 제한합니다. 토큰은 `stable_token` POST로 취득하고 만료 5분 전까지 Rails.cache에 보관하며, 운영에서는 공유 캐시 사용을 권장합니다. 토큰 만료 오류는 갱신 후 한 번만 재시도합니다.

## 검증

`source ~/.claude/factory-runner/scripts/env0053.sh`로 환경을 로드하고 `bin/rails db:migrate` 후 다음을 실행합니다. 위챗 테스트는 HTTP callable 주입 또는 스텁만 사용합니다.

```sh
bin/rails test test/services/wechat test/controllers/wechat_webhook_test.rb test/controllers/wechat_controller_test.rb test/controllers/purchase_orders_controller_test.rb
bin/rails test
```

프로토콜 참고: 제공된 Next.js 초안의 SHA1 서명·AES 규격을 Rails로 구현했습니다. 운영 설정과 템플릿 권한은 [위챗 공식계정 관리자](https://mp.weixin.qq.com/) 및 [공식 개발 문서](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Overview.html)에서 확인합니다.

## 개인 계정과 채널 방식

계정별 기본 방식은 **manual**입니다. 공식계정 키가 없는 JIEUM도 개인 위챗으로 운영할 수 있습니다. 관리자 `/wechat` 상단에서 변경하며 변경·토큰 발급/폐기·메시지 처리의 계정/처리자 ID는 서버 로그에 기록됩니다. 기존 메시지는 방식 변경으로 자동 변환하거나 발송하지 않습니다.

| 방식 | 계정/준비 | 발주·대화 발송 | 수신 |
| --- | --- | --- | --- |
| manual (기본) | 개인 위챗 | pending_manual → 복사해서 직접 보내기 → sent_manual | 받은 메시지 붙여넣기 → received_manual |
| mac_app | 개인 위챗, 운영자 맥·키체인·권한 | 기본 pending_manual → 복사해서 직접 보내기 → sent_manual (자동 발송 켜짐: awaiting_approval → 승인 → queued_mac → sent_mac/failed) | 로컬 알림 폴링 → received_mac |
| official | 인증 공식계정·기존 환경변수 | 기존 공식 API와 48시간/템플릿 규칙 | 서명 검증 웹훅 |

### manual 운영

1. `/wechat`에서 거래처와 위챗 표시 이름(대화방 이름)으로 상대를 추가합니다. 개인 계정은 open_id가 필요 없습니다. 공식계정 상대는 open_id가 필수입니다.
2. 발주 제출 후 큐 워커가 중·한 병기 통보문을 만듭니다. 발주 상세 또는 대화 화면에서 복사하여 개인 위챗에 직접 보냅니다.
3. 실제 보낸 뒤 **보냈음 표시**를 눌러 처리자·시각을 남깁니다. 버튼을 누르는 것만으로 위챗에 보내지 않습니다.
4. 공장 답장은 대화 화면의 **받은 메시지 붙여넣기**로 기록합니다.

### mac_app 운영

실측 결과 WeChat 4.2 맥 앱은 화면 캡처·손쉬운 사용 정보로 현재 대화방을 확인할 수 없습니다. 로컬 에이전트 자동 발송은 맞는 대화방인지 검증할 수 없는 ‘눈 감고 보내기’이므로 **받기=에이전트 자동, 보내기=복사해서 직접 보내기**가 기본입니다. 서버 `WECHAT_MAC_AUTO_SEND=true`일 때만 기존 승인 대기 → 보내기 승인 → `queued_mac` 흐름을 허용하며 에이전트에도 `--send`가 필요합니다. 다른 값과 미설정은 꺼짐입니다. 켜도 기존 `pending_manual` 메시지는 자동 변환하지 않습니다.

1. 방식을 mac_app으로 변경하고 대화방의 실제 이름을 정확히 등록합니다. 같은 표시 이름은 계정 내 하나만 등록할 수 있습니다.
2. 에이전트 이름으로 토큰을 발급하고 한 번 표시되는 원문을 맥 키체인에 저장합니다. 서버 DB에는 SHA256 digest만 저장합니다. 분실하면 폐기 후 새로 발급합니다.
3. [로컬 에이전트 설치 안내](../script/wechat_mac_agent/README.md)를 따라 수신 전용으로 시작합니다. 받기는 맥 위챗 알림을 자동으로 대화함에 넣습니다.
4. 보내기는 발주 통보·대화 모두 기본 `pending_manual`입니다. **복사**하여 위챗에서 직접 보내고 **보냈음 표시**로 `sent_manual` 처리합니다. 자동 발송 꺼짐에서는 보내기 승인 버튼을 숨기고 서버도 승인을 거부하며 기존 `queued_mac`도 outbox에서 숨깁니다.
5. 상단 마지막 접속을 확인합니다. 활성 토큰의 heartbeat가 없거나 5분 넘게 지나면 **연결 끊김**이 표시됩니다. 폐기한 토큰은 즉시 API 401 처리됩니다.

에이전트 API는 Bearer 토큰으로 인증하고 mac_app 계정만 허용합니다. 일반 API Rack::Attack 제한(5분/IP당 300건)을 적용합니다. `GET /api/wechat_agent/outbox`, `POST /api/wechat_agent/outbox/:id/result` (`ok`: JSON boolean, `error`), `POST /api/wechat_agent/inbox` (`display_name`, `content`, ISO8601 `received_at`, `external_key`), `POST /api/wechat_agent/heartbeat`를 제공합니다. inbox external_key는 계정 안에서 중복을 무시하며, 모르는 표시 이름은 거래처 미연결 상대를 생성합니다. API에는 브라우저 세션이나 CSRF 토큰을 사용하지 않습니다.

검증 환경은 반드시 다음과 같이 로드합니다(PATH만 변경하면 GemNotFound 발생).

```sh
source ~/.claude/factory-runner/scripts/env0053.sh
bin/rails db:migrate
bin/rails test
bundle exec rubocop app/services/wechat app/controllers/wechat_controller.rb app/controllers/webhooks/wechat_controller.rb app/controllers/api/wechat_agent_controller.rb app/models/wechat*.rb app/jobs/wechat_purchase_order_job.rb script/wechat_mac_agent test/script/wechat_mac_agent_test.rb test/controllers/wechat* test/services/wechat db/migrate/*wechat*.rb
```
