#!/usr/bin/env python3
"""
ping-server.py — tiny HTTP server used by open-dashboard to detect browser tab close.
Exits after GRACE seconds of no pings (default 15).

Usage: ping-server.py <port> [grace-seconds]
"""

import http.server, time, sys, threading

last  = [time.time()]
grace = float(sys.argv[2]) if len(sys.argv) > 2 else 15.0


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if '/ping' in self.path:
            last[0] = time.time()
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(b'ok')

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(('localhost', int(sys.argv[1])), Handler)
thread = threading.Thread(target=server.serve_forever)
thread.daemon = True
thread.start()

while True:
    time.sleep(2)
    if time.time() - last[0] > grace:
        break

server.shutdown()
