#!/usr/bin/env python3
"""Static server for the web export.

Python's http.server does not always know .wasm, and a wrong Content-Type makes
WebAssembly.instantiateStreaming reject a perfectly good build. Registering the
type here keeps that failure mode off the table.

Deliberately serves *no* COOP/COEP headers: this is the test that proves the
build runs on ordinary static hosting.
"""
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

SimpleHTTPRequestHandler.extensions_map.update({
    ".wasm": "application/wasm",
    ".js": "text/javascript",
    ".pck": "application/octet-stream",
})


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):  # keep the test output readable
        pass


if __name__ == "__main__":
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=directory)).serve_forever()
