# 위챗 공식계정 연결

중국 공장 담당자와의 발주 통보·대화에 WeChat 공식계정(서비스 계정, 服务号)을 사용합니다. 현재 공식계정은 JIEUM 전용이며 수신은 기존 `Account.primary`(slug `jieum`)에 귀속됩니다. 다른 테넌트의 담당자를 이 공식계정에 연결하면 안 됩니다.

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
| `APP_HOST` | 기존 앱 공개 URL/호스트(발주 확정 링크·웹훅 URL) |

발송을 끄면 유효한 메시지는 `disabled`로만 저장하고 토큰 요청을 포함해 외부 API를 호출하지 않습니다. 나중에 켜도 저장된 메시지를 자동 발송하지 않습니다. 본문은 1~2000자로 제한합니다. 토큰은 `stable_token` POST로 취득하고 만료 5분 전까지 Rails.cache에 보관하며, 운영에서는 공유 캐시 사용을 권장합니다. 토큰 만료 오류는 갱신 후 한 번만 재시도합니다.

## 검증

Ruby 3.3을 PATH 앞에 설정하고 `bin/rails db:migrate` 후 다음을 실행합니다. 위챗 테스트는 HTTP callable 주입 또는 스텁만 사용합니다.

```sh
bin/rails test test/services/wechat test/controllers/wechat_webhook_test.rb test/controllers/wechat_controller_test.rb test/controllers/purchase_orders_controller_test.rb
bin/rails test
```

프로토콜 참고: 제공된 Next.js 초안의 SHA1 서명·AES 규격을 Rails로 구현했습니다. 운영 설정과 템플릿 권한은 [위챗 공식계정 관리자](https://mp.weixin.qq.com/) 및 [공식 개발 문서](https://developers.weixin.qq.com/doc/offiaccount/Getting_Started/Overview.html)에서 확인합니다.
