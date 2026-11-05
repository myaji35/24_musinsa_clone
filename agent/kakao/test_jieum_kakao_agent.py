import datetime
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

from jieum_kakao_agent import Agent, message_digest, save_json


class AgentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.calls = []
        self.config = {"rooms": ["거래처"], "collect_start_hour": 0, "collect_end_hour": 23,
                       "allow_focus": False, "limit": 30}
        hour = datetime.datetime.now().hour
        if hour == 23:
            self.config.update(collect_start_hour=23, collect_end_hour=22)
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(owner.config).encode())

            def do_POST(self):
                owner.calls.append((self.path, json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{}')

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.agent = Agent(self.home)
        save_json(self.home / 'config.json', {'server': 'http://127.0.0.1:%s' % self.server.server_port, 'token': 'secret'})
        self.binary = self.home / 'kmsg'
        self.flags = self.home / 'flags'
        self.binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "' + str(self.flags) + '"\necho \'{"messages":[{"author":"홍길동","date":"2026-11-06","time_raw":"오후 3:47","body":" 내일 30장 보내주세요 "}]}\'\n')
        self.binary.chmod(0o700)
        self.environment = patch.dict(os.environ, {'KMSG_BIN': str(self.binary)})
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def test_shared_digest_vector(self):
        self.assertEqual('baaf3ba0248cf7d04f007b7e45d0c3371622b776a7056c631fed0cccc0b87a0b', message_digest('거래처', {'author': '홍길동', 'date': '2026-11-06', 'time_raw': '오후 3:47', 'body': ' 내일 30장 보내주세요 '}))

    def test_dedup_and_background_flag(self):
        self.assertEqual(0, self.agent.run_once())
        self.assertIn('--background-safe', self.flags.read_text())
        self.assertEqual(0, self.agent.run_once())
        messages = [body for path, body in self.calls if path.endswith('/messages')]
        self.assertEqual([1, 0], [len(body['messages']) for body in messages])
        self.config['allow_focus'] = True
        self.agent.run_once()
        self.assertNotIn('--background-safe', self.flags.read_text())

    def test_outside_hours(self):
        self.config.update(collect_start_hour=0, collect_end_hour=0)
        self.assertEqual(0, self.agent.run_once())
        self.assertFalse(self.flags.exists())
        self.assertEqual([], self.calls)

    def test_failure_reports_and_continues(self):
        self.binary.write_text('#!/bin/sh\nexit 1\n')
        self.config['rooms'].append('다음 방')
        self.assertEqual(1, self.agent.run_once())
        status = self.calls[-1][1]
        self.assertFalse(status['ok'])
        self.assertIn('거래처', status['error'])
        self.assertIn('다음 방', status['error'])


if __name__ == '__main__':
    unittest.main()
