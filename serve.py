#!/usr/bin/env python3
"""Serve current directory over HTTP with byte-Range support (for <video> seek)."""
import os, re, sys, mimetypes
from http.server import HTTPServer, SimpleHTTPRequestHandler


class RangeHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        rng = self.headers.get("Range")
        if not rng:
            return super().do_GET()
        m = re.match(r"bytes=(\d+)-(\d*)", rng)
        if not m:
            return super().do_GET()
        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            return super().do_GET()
        size = os.path.getsize(path)
        start = int(m.group(1))
        end = int(m.group(2)) if m.group(2) else size - 1
        end = min(end, size - 1)
        if start >= size:
            self.send_error(416, "Range Not Satisfiable")
            return
        length = end - start + 1
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        self.send_response(206)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(length))
        self.end_headers()
        with open(path, "rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(64 * 1024, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f"Serving on http://0.0.0.0:{port}  (Range-aware, video seek works)")
    HTTPServer(("0.0.0.0", port), RangeHandler).serve_forever()
