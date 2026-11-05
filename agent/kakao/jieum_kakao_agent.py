#!/usr/bin/env python3
"""카카오톡 읽기 전용 수집 에이전트 (Python 3.9+, 표준 라이브러리)."""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import unicodedata
import urllib.request


def message_digest(room, message):
    body = unicodedata.normalize("NFC", message.get("body", "")).strip()
    text = room + "\0" + "".join(str(message.get(k) or "") for k in ("author", "date", "time_raw")) + body
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def save_json(path, data):
    temporary = path.with_suffix(".tmp")
    fd = os.open(str(temporary), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(data, stream, ensure_ascii=False)
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def kmsg_path():
    candidates = [os.environ.get("KMSG_BIN"), str(Path.home() / ".local/bin/kmsg"), "/opt/homebrew/bin/kmsg", shutil.which("kmsg")]
    return next((p for p in candidates if p and os.path.isfile(p) and os.access(p, os.X_OK)), None)


class Agent:
    def __init__(self, home=None):
        self.home = Path(home) if home else Path.home() / ".jieum-kakao"
        self.home.mkdir(mode=0o700, parents=True, exist_ok=True)

    def load(self, name, default=None):
        path = self.home / name
        return json.loads(path.read_text()) if path.exists() else default

    def request(self, endpoint, data=None):
        config = self.load("config.json")
        request = urllib.request.Request(config["server"].rstrip("/") + "/api/kakao_agent/" + endpoint,
                                         data=None if data is None else json.dumps(data).encode(),
                                         headers={"Authorization": "Bearer " + config["token"], "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    def run_once(self):
        with open(self.home / "run.lock", "a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("이미 수집 중입니다")
                return 0
            return self.collect()

    def collect(self):
        errors = []
        try:
            config = self.request("config")
            hour = datetime.datetime.now().hour
            start, end = config["collect_start_hour"], config["collect_end_hour"]
            inside = start <= hour < end if start <= end else hour >= start or hour < end
            if not inside:
                print("시간대 밖")
                return 0
            sent = self.load("sent.json", [])
            known = set(sent)
            binary = kmsg_path()
            if not binary:
                raise RuntimeError("kmsg 실행 파일을 찾을 수 없습니다")
            for room in config["rooms"]:
                try:
                    command = [binary, "read", room, "--limit", str(config["limit"]), "--json"]
                    if not config["allow_focus"]:
                        command.append("--background-safe")
                    # kmsg를 강제 종료하면 창 상태가 꼬일 수 있어 90초까지 기다립니다.
                    result = subprocess.run(command, capture_output=True, text=True, timeout=90)
                    if result.returncode:
                        raise RuntimeError("kmsg 실행 실패 (종료 코드 %s)" % result.returncode)
                    messages = json.loads(result.stdout)["messages"]
                    pending, digests = [], []
                    for message in messages:
                        digest = message_digest(room, message)
                        if digest not in known and digest not in digests:
                            pending.append(message)
                            digests.append(digest)
                    # 빈 요청도 보내 방의 수집 시각과 순환 순서를 갱신합니다.
                    self.request("messages", {"room": room, "messages": pending})
                    sent = (sent + digests)[-5000:]
                    known = set(sent)
                    save_json(self.home / "sent.json", sent)
                except Exception as error:
                    errors.append(room + ": " + self.safe_error(error))
        except Exception as error:
            errors.append(self.safe_error(error))
        summary = {"ok": not errors, "error": "; ".join(errors)}
        try:
            self.request("status", summary)
        except Exception as error:
            errors.append("상태 전송 실패: " + self.safe_error(error))
            summary = {"ok": False, "error": "; ".join(errors)}
        summary["at"] = datetime.datetime.now().isoformat()
        save_json(self.home / "last_run.json", summary)
        print("수집 완료" if summary["ok"] else summary["error"])
        return 0 if summary["ok"] else 1

    def safe_error(self, error):
        config = self.load("config.json", {})
        token = config.get("token")
        text = str(error)
        return text.replace(token, "[숨김]") if token else text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    setup = sub.add_parser("setup")
    setup.add_argument("--server", required=True)
    setup.add_argument("--token", required=True)
    sub.add_parser("run-once")
    sub.add_parser("status")
    args = parser.parse_args()
    agent = Agent()
    if args.command == "setup":
        if not args.server.startswith(("https://", "http://")):
            parser.error("서버는 http:// 또는 https:// 주소여야 합니다")
        save_json(agent.home / "config.json", {"server": args.server, "token": args.token})
        print("설정 저장 완료")
        return 0
    if args.command == "status":
        config = agent.load("config.json", {})
        print("서버:", config.get("server", "미설정"))
        print("토큰:", "설정됨" if config.get("token") else "미설정")
        print("kmsg:", kmsg_path() or "없음")
        print("마지막 실행:", agent.load("last_run.json", "없음"))
        return 0
    return agent.run_once()


if __name__ == "__main__":
    raise SystemExit(main())
