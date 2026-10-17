#!/usr/bin/env python3
"""
Legacy Instax Printer — Local Web-to-TCP Wi-Fi Direct Bridge (SP-1 • SP-2 • SP-3)
=================================================================================
Allows any web browser (Chrome, Safari, Firefox, Edge, Brave) running
LegacyInstaxPrinterWeb.html to communicate with Fujifilm Instax SHARE SP-1, SP-2,
and SP-3 printers over raw TCP sockets (192.168.0.251:8080) and scan for nearby
INSTAX-XXXXXXXX Wi-Fi Direct networks.

Usage:
  python3 legacy_web_bridge.py
  Then open http://127.0.0.1:8089 in your browser!
"""

import base64
import json
import os
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Windows"))
from legacy_instax_printer import (
    LegacyInstaxClient,
    VirtualInstaxShareServer,
    scan_wifi_and_printers,
)

SIM_SERVER = VirtualInstaxShareServer(port=18080, model="SP-2", pin=1111)


class BridgeHandler(BaseHTTPRequestHandler):
    def _send_cors(self, code=200, content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_OPTIONS(self):
        self._send_cors(200)

    def do_GET(self):
        if self.path in ("/", "/index.html", "/LegacyInstaxPrinterWeb.html"):
            html_path = os.path.join(os.path.dirname(__file__), "LegacyInstaxPrinterWeb.html")
            if os.path.exists(html_path):
                with open(html_path, "rb") as f:
                    data = f.read()
                self._send_cors(200, "text/html; charset=utf-8")
                self.wfile.write(data)
                return
        elif self.path == "/api/scan":
            items = scan_wifi_and_printers(sim_port=18080)
            self._send_cors(200)
            self.wfile.write(json.dumps({"ok": True, "items": items}).encode("utf-8"))
            return
        self._send_cors(404)
        self.wfile.write(json.dumps({"error": "Not found"}).encode("utf-8"))

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        try:
            body = json.loads(raw.decode("utf-8"))
        except Exception:
            body = {}

        if self.path == "/api/scan":
            items = scan_wifi_and_printers(sim_port=18080)
            self._send_cors(200)
            self.wfile.write(json.dumps({"ok": True, "items": items}).encode("utf-8"))
            return

        host = body.get("ip", "192.168.0.251")
        port = int(body.get("port", 8080))
        pin = int(body.get("pin", 1111))
        model = body.get("model", "SP-2")
        simulate = bool(body.get("simulate", False))

        if simulate:
            SIM_SERVER.model = model
            SIM_SERVER.pin = pin
            SIM_SERVER.start()
            host, port = "127.0.0.1", 18080

        try:
            client = LegacyInstaxClient(host=host, port=port, pin=pin)
            if self.path == "/api/status":
                st = client.get_printer_status()
                self._send_cors(200)
                self.wfile.write(json.dumps({"ok": True, "status": st}).encode("utf-8"))
                return
            elif self.path == "/api/print":
                b64_planar = body.get("planar_base64", "")
                dry_run = bool(body.get("dry_run", False))
                planar_bytes = base64.b64decode(b64_planar)
                res = client.print_planar_rgb(planar_bytes, model_name=model, dry_run=dry_run)
                self._send_cors(200)
                self.wfile.write(json.dumps({"ok": True, "result": res}).encode("utf-8"))
                return
        except Exception as exc:
            self._send_cors(500)
            self.wfile.write(json.dumps({"ok": False, "error": str(exc)}).encode("utf-8"))
            return

        self._send_cors(404)
        self.wfile.write(json.dumps({"ok": False, "error": "Unknown endpoint"}).encode("utf-8"))


def main():
    port = 8089
    server = HTTPServer(("127.0.0.1", port), BridgeHandler)
    url = f"http://127.0.0.1:{port}/LegacyInstaxPrinterWeb.html"
    print(f"🌐 Legacy Instax Printer Web Bridge listening on {url}")
    try:
        webbrowser.open(url)
    except Exception:
        pass
    server.serve_forever()


if __name__ == "__main__":
    main()
