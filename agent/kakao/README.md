# 지음 카톡 수집 에이전트

macOS Python 3.9 이상과 설치된 kmsg가 필요합니다. pip 설치는 필요 없습니다. 읽기만 하며 메시지를 보내는 기능은 없습니다.

1. 이 폴더의 `jieum_kakao_agent.py`를 `~/jieum-kakao/`에 복사합니다.
2. 워크스페이스 → 카톡 수집 기기 연결에서 기기를 만들고, 한 번 표시되는 명령을 실행합니다.

```sh
mkdir -p ~/jieum-kakao
cp agent/kakao/jieum_kakao_agent.py ~/jieum-kakao/
python3 ~/jieum-kakao/jieum_kakao_agent.py setup --server https://서버주소 --token 발급받은토큰
python3 ~/jieum-kakao/jieum_kakao_agent.py run-once
python3 ~/jieum-kakao/jieum_kakao_agent.py status
```

설정은 `~/.jieum-kakao/config.json`에 권한 600으로 저장됩니다. 토큰을 공유하거나 저장소에 올리지 마세요. 분실하면 서버에서 기기를 폐기하고 다시 연결합니다.

시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 kmsg 및 실행 터미널에 필요한 권한을 허용하세요. 카카오톡에 로그인하고 수집할 방 창을 열어 두세요. 서버에서 카톡 방 이름을 정확히 등록해야 합니다.

## 15분 자동 실행

`com.jieum.kakao-agent.plist.example`을 `~/Library/LaunchAgents/com.jieum.kakao-agent.plist`로 복사하고 모든 `YOUR_NAME`과 Python 경로를 실제 절대 경로로 바꿉니다. `python3 --version`으로 3.9 이상인지 확인합니다.

```sh
mkdir -p ~/Library/LaunchAgents
cp agent/kakao/com.jieum.kakao-agent.plist.example ~/Library/LaunchAgents/com.jieum.kakao-agent.plist
# 편집기로 경로를 바꾼 다음 실행
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jieum.kakao-agent.plist
# 해제
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jieum.kakao-agent.plist
```

기본 수집 시간은 맥 로컬 시각 09시 이상 19시 미만입니다. 시작이 끝보다 크면 자정을 넘는 시간대입니다. 같으면 수집하지 않습니다. 시간대 밖에서는 config 요청만 하고 상태 전송이나 kmsg 실행을 하지 않습니다.

## 포커스와 문제 해결

기본값은 `--background-safe`로 이미 열린 방만 읽습니다. 방을 열지 않으면 실패하거나 빈 결과가 나올 수 있습니다. 포커스 허용을 체크하면 카톡 창을 열어 읽으므로 방당 약 1분간 맥 사용이 불편합니다. 방마다 순서대로 실행하며 최대 90초 기다립니다. 별도로 kmsg를 동시에 실행하지 마세요. 강제 종료는 카톡 창 상태를 꼬이게 할 수 있습니다.

`status`로 kmsg 경로와 마지막 오류를 확인합니다. 경로 검색 순서는 `KMSG_BIN`, `~/.local/bin/kmsg`, `/opt/homebrew/bin/kmsg`, PATH입니다. launchd에서 별도 경로가 필요하면 plist의 EnvironmentVariables에 KMSG_BIN을 설정하세요. 로그는 `~/.jieum-kakao/agent.log`, `agent-error.log`입니다. 인증 오류는 서버 주소와 기기 폐기 여부를 확인합니다. 한 방 실패 시 다음 방은 계속 수집하고 오류를 서버에 보고합니다.

최근 전송한 digest 5000개를 로컬에 저장하며 서버도 중복을 차단합니다. 같은 방·작성자·날짜·분·내용은 하나로 합쳐집니다. kmsg가 읽는 최근 30개보다 메시지가 많이 쌓이면 누락될 수 있습니다. 여러 기기는 같은 맥 설정 폴더를 공유하지 않도록 운영하세요.
