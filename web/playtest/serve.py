#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import threading
import webbrowser


HOST = "127.0.0.1"
PORT = 8000


class AvalonHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


def main() -> None:
    os.chdir(Path(__file__).resolve().parent)
    url = f"http://{HOST}:{PORT}/index.html"
    server = ThreadingHTTPServer((HOST, PORT), AvalonHandler)
    threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    print(f"Avalon is available at {url}")
    print("Keep this window open while playing. Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
