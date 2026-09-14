#!/usr/bin/env -S uv run --script
"""
One-shot HTTP receiver for VTT transcript downloads.

Usage:
    python3 scripts/vtt_receiver.py <dest-dir> [port]

Starts an HTTP server on localhost:<port> (default 8765) that accepts a single
POST request. The request path becomes the filename; the body is written as-is
to <dest-dir>/<filename>. The server shuts down after one successful POST.

Called by the fetch-recording-transcript skill: the Stream player tab fetches
the transcript via the SharePoint API (using its own session cookies) and POSTs
the content here, writing directly to docs/meetings/ with no browser download
dialog and no ~/Downloads detour.
"""
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer


def main():
    if len(sys.argv) < 2:
        print("Usage: vtt_receiver.py <dest-dir> [port]", file=sys.stderr)
        sys.exit(1)

    dest_dir = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8765

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # silence access log

        def do_OPTIONS(self):
            self._cors()
            self.end_headers()

        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            filename = self.path.lstrip("/")
            dest = f"{dest_dir}/{filename}"
            with open(dest, "wb") as f:
                f.write(body)
            print(f"Written {len(body)} bytes → {dest}", flush=True)
            self._cors()
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
            threading.Thread(target=self.server.shutdown).start()

        def _cors(self):
            self.send_response(200)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")

    server = HTTPServer(("127.0.0.1", port), Handler)
    print(f"Listening on 127.0.0.1:{port} → {dest_dir}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
