# 서울라이브 결제완료 웹훅

기본은 꺼짐이다. 다음 환경변수 세 개를 모두 설정하면 주문의 paid 전환 커밋 후 default 큐에 발신 작업을 등록한다.

- SEOULLIVE_ORDER_WEBHOOK_ENABLED: 1 또는 true
- SEOULLIVE_ORDER_WEBHOOK_URL: 서울라이브 HTTPS 수신 주소 (/api/ai-channel/webhooks/jieum)
- SEOULLIVE_ORDER_WEBHOOK_SECRET: 수신 서버와 공유하는 시크릿

배송지 이름은 한글 첫 글자+*, 그 외 첫 글자+***로 마스킹한다. 이름이 없거나 배송지가 삭제됐으면 고객으로 보낸다. 원문 이름이나 요청 본문을 로그에 기록하지 않는다.

JSON 원문으로 HMAC-SHA256 hex를 계산해 X-Jieum-Signature: sha256=<hex>로 보낸다. 주문 행별 order.id를 문자열로 보내며 link_code로 유입 코드를 전달한다.

연결 3초, 응답 5초 제한이며 네트워크 오류와 2xx 이외 응답은 polynomially_longer 간격으로 최대 5회 시도한다. default 큐 워커가 필요하다. 중복 발신은 수신 측 order.id로 처리한다. 큐 등록 실패는 주문 처리를 막지 않고 경고를 남긴다. 별도 영구 발신 기록이나 자동 복구 기능은 없다.
