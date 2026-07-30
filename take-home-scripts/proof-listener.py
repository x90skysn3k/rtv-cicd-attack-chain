#!/usr/bin/env python3
"""TLS listener for RTV credential capture from the persistence Lambda."""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import ssl


MAX_BODY_BYTES = 16_384
BASE_KEYS = {
    "kind",
    "fired_at",
    "invocation_id",
    "session_label",
}
CRED_KEYS = {
    "access_key_id",
    "secret_access_key",
    "session_token",
    "role_label",
}
VALID_KEYSETS = {frozenset(BASE_KEYS), frozenset(BASE_KEYS | CRED_KEYS)}

class ProofHandler(BaseHTTPRequestHandler):
    server_version = "RTVCredCapture/1"

    def log_message(self, _format, *_args):
        return

    def do_GET(self):
        if self.path != "/healthz":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"ready"}\n')

    def do_POST(self):
        if self.path != "/":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400)
            return
        if length <= 0 or length > MAX_BODY_BYTES:
            self.send_error(413)
            return

        try:
            payload = json.loads(self.rfile.read(length))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self.send_error(400)
            return

        if not isinstance(payload, dict) or frozenset(payload) not in VALID_KEYSETS:
            self.send_error(422)
            return
        visible = {key: payload[key] for key in sorted(payload)}
        print(json.dumps(visible, sort_keys=True), flush=True)
        self.send_response(204)
        self.end_headers()



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=1337)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), ProofHandler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.cert, args.key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(
        json.dumps(
            {
                "status": "credential capture listener ready",
                "port": args.port,
            },
            sort_keys=True,
        ),
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
