# 개인 위챗 macOS 로컬 에이전트

개인 계정에는 공식 API가 없습니다. 이 스크립트는 운영자가 로그인한 WeChat.app을 손쉬운 사용 기능으로 조작합니다. 위챗 약관상 회색지대이며 계정 제한 가능성이 있습니다. 앱 업데이트·검색 결과 순서·포커스 이동에 따라 잘못된 대화방에 보내거나 실패할 수 있습니다. `sent_mac`은 키 입력 완료이며 상대방 수신 보증이 아닙니다. 먼저 수신 전용으로 운영하고, 발송 전 대화방 이름이 유일하고 정확한지 확인하세요. 여러 맥에서 같은 outbox를 발송하지 마세요.

## 설치

1. macOS에서 WeChat에 로그인합니다. 서버의 `/wechat`에서 맥 위챗 앱 방식을 선택하고 대화 상대의 **실제 대화방 이름**을 등록합니다. 이름이 같은 대화방은 지원하지 않습니다.
2. Ruby 3.3 이상과 `sqlite3` gem이 필요합니다. 저장소의 Bundler 환경 또는 별도 Ruby 환경에 설치하세요(`gem install sqlite3`). Rails 서버는 맥에 설치할 필요가 없습니다.
3. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 실행 터미널/Ruby에 권한을 줍니다. 전체 디스크 접근 권한도 주고 터미널을 다시 실행합니다. 자동화에서 System Events/WeChat 제어 요청을 허용합니다. 알림에서 WeChat 알림·미리보기를 활성화합니다. 잠금 상태·미리보기 숨김·알림 비활성 상태의 수신은 읽지 못할 수 있습니다.
4. `/wechat`에서 에이전트 토큰을 발급합니다. 원문은 한 번만 표시됩니다. **키체인 접근 앱**에서 일반 암호 항목을 생성하고 서비스 이름 `jieum-wechat-agent`, 계정 `operator`, 암호에 토큰을 넣으세요. 명령줄 인자로 토큰을 넣으면 셸 기록/프로세스 목록에 남을 수 있으므로 GUI 저장을 권장합니다. 스크립트는 `security find-generic-password -s jieum-wechat-agent -a operator -w`로 읽습니다. 설정 파일에는 평문 토큰을 넣지 않습니다.
5. 다음 `config.json`을 준비합니다. 상태 파일에는 수신 rec_id·발송 시도 시각·결과를 저장하며, 삭제하면 수신 중복/발송 제한 기록이 사라집니다. 키체인과 상태 경로는 운영자별로 분리합니다.

```json
{
  "server_url": "https://orders.example.com",
  "keychain_service": "jieum-wechat-agent",
  "keychain_account": "operator",
  "state_path": "~/.local/state/wechat_mac_agent/state.json"
}
```

```sh
ruby script/wechat_mac_agent/agent.rb --config config.json --read-only
ruby script/wechat_mac_agent/agent.rb --config config.json --send --dry-run
ruby script/wechat_mac_agent/agent.rb --config config.json --send
```

기본은 `--read-only`입니다. `--send`를 명시해야 발송합니다. `--dry-run`은 발송·수신 저장 없이 ID만 로그에 출력하고 heartbeat/outbox 조회는 수행합니다. 종료는 Ctrl+C입니다. 서버에는 승인한 메시지만 노출되며, 발송 시도 간 최소 20초·최근 1시간 최대 30건입니다. 단일 상태 파일 잠금으로 중복 프로세스를 막습니다. 앱 조작 전에 시도와 불확실 결과를 저장하므로 크래시 후 자동 재발송하지 않습니다. 결과 보고 실패 시 저장된 결과만 재보고합니다. 실패 메시지는 실제 위챗에서 발송 여부를 확인한 뒤 새 메시지로 재작성하세요.

수신은 `~/Library/Group Containers/group.com.apple.usernoted/db2/db`를 **읽기 전용**으로 열고 `app.identifier = com.tencent.xinWeChat` 알림의 plist `req.titl`/`req.body`를 파싱합니다. macOS 버전에 따라 DB 스키마/필드가 달라질 수 있습니다. 알림이 오지 않거나 DB 접근이 실패하면 수동 붙여넣기를 사용하세요. heartbeat는 프로세스 접속 표시이며 수신 성공 보증은 아닙니다. 알림은 전체 대화 이력이 아니며 잘리거나 누락될 수 있습니다. 운영 중 DB를 수정하지 마세요.

토큰이 유출되거나 맥 사용을 중지하면 `/wechat`에서 즉시 폐기하고 키체인 항목을 삭제합니다. 토큰 소유자는 해당 계정의 대기 발송 내용과 수신 API에 접근합니다. HTTPS 서버를 사용하세요(개발 localhost만 HTTP 허용).
