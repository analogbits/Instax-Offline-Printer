#!/usr/bin/env python3
"""
Legacy Instax Printer — Local Web-to-TCP Wi-Fi Direct Bridge (SP-1 • SP-2 • SP-3)
=================================================================================
Allows any web browser (iPhone/iPad Safari, Mac Safari, Chrome, Firefox, Edge)
running LegacyInstaxPrinterWeb.html to communicate with Fujifilm Instax SHARE SP-1,
SP-2, and SP-3 printers over raw TCP sockets (192.168.0.251:8080) and scan for nearby
INSTAX-XXXXXXXX Wi-Fi Direct networks.

Provides:
- Mobile Safari & iPhone / iPad Wi-Fi access over local network
- Suppressed socket reset / broken pipe errors from iOS Safari speculative connections
- REST endpoints: /api/bridge-ping, /api/scan, /api/status, /api/print
- Built-in Virtual SP-1/2/3 TCP simulator support (127.0.0.1:18080)
"""

import argparse
import base64
import json
import os
import platform
import socket
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# Resolve paths to locate legacy_instax_printer.py
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

# Look for legacy_instax_printer in common directories
for cand in [
    SCRIPT_DIR,
    os.path.join(SCRIPT_DIR, "..", "macOS"),
    os.path.join(SCRIPT_DIR, "..", "Windows"),
    os.path.join(SCRIPT_DIR, "..", "Linux"),
]:
    if os.path.isdir(cand) and cand not in sys.path:
        sys.path.insert(0, cand)

try:
    from legacy_instax_printer import (
        LegacyInstaxClient,
        VirtualInstaxShareServer,
        scan_wifi_and_printers,
    )
    HAS_LEGACY_MODULE = True
except ImportError:
    HAS_LEGACY_MODULE = False
    LegacyInstaxClient = None
    VirtualInstaxShareServer = None
    scan_wifi_and_printers = None

SIM_SERVER = VirtualInstaxShareServer(port=18080, model="SP-2", pin=1111) if VirtualInstaxShareServer else None


def get_lan_ip() -> str:
    """Detect the machine's primary Wi-Fi / LAN IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"


class LegacyBridgeHandler(BaseHTTPRequestHandler):
    server_version = "LegacyInstaxBridge/1.5.4"

    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError, TimeoutError, socket.timeout, OSError):
            # iOS Safari opens speculative preconnect sockets and terminates them with RST
            pass

    def log_message(self, fmt, *args):
        sys.stdout.write(f"[Legacy Bridge] {self.address_string()} - {fmt % args}\n")
        sys.stdout.flush()

    def _send_json(self, payload: dict, status_code: int = 200):
        raw = json.dumps(payload).encode("utf-8")
        try:
            self.send_response(status_code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
        except (ConnectionResetError, BrokenPipeError, OSError):
            pass

    def do_OPTIONS(self):
        try:
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Connection", "close")
            self.end_headers()
        except (ConnectionResetError, BrokenPipeError, OSError):
            pass

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path in ("/favicon.ico", "/apple-touch-icon.png", "/apple-touch-icon-precomposed.png"):
            try:
                self.send_response(204)
                self.send_header("Connection", "close")
                self.end_headers()
            except (ConnectionResetError, BrokenPipeError, OSError):
                pass
            return

        if path == "/api/bridge-ping":
            lan_ip = get_lan_ip()
            port = self.server.server_address[1]
            self._send_json({
                "ok": True,
                "bridge": "legacy-instax-bridge",
                "version": "1.5.4",
                "platform": platform.system(),
                "hostname": socket.gethostname(),
                "lan_ip": lan_ip,
                "lan_url": f"http://{lan_ip}:{port}",
            })
            return

        if path == "/api/scan":
            if HAS_LEGACY_MODULE and scan_wifi_and_printers:
                items = scan_wifi_and_printers(sim_port=18080)
            else:
                items = [{"label": "📡 Default Instax SHARE (192.168.0.251:8080)", "ip": "192.168.0.251", "port": 8080}]
            self._send_json({"ok": True, "items": items})
            return

        # Serve LegacyInstaxPrinterWeb.html at / or /LegacyInstaxPrinterWeb.html
        if path in ("/", "/index.html", "/LegacyInstaxPrinterWeb.html", "/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html"):
            html_path = os.path.join(SCRIPT_DIR, "LegacyInstaxPrinterWeb.html")
            if os.path.isfile(html_path):
                with open(html_path, "rb") as f:
                    content = f.read()
                try:
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
                    self.send_header("Connection", "close")
                    self.send_header("Content-Length", str(len(content)))
                    self.end_headers()
                    self.wfile.write(content)
                except (ConnectionResetError, BrokenPipeError, OSError):
                    pass
                return

        # Also permit seamless switching to BLE Link Web App
        if path.endswith("InstaxPrinterWeb.html"):
            ble_html = os.path.join(REPO_ROOT, "Web-Bluetooth-Offline", "InstaxPrinterWeb.html")
            if os.path.isfile(ble_html):
                with open(ble_html, "rb") as f:
                    content = f.read()
                try:
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
                    self.send_header("Connection", "close")
                    self.send_header("Content-Length", str(len(content)))
                    self.end_headers()
                    self.wfile.write(content)
                except (ConnectionResetError, BrokenPipeError, OSError):
                    pass
                return

        try:
            self.send_error(404, "Not Found")
        except (ConnectionResetError, BrokenPipeError, OSError):
            pass

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", "0"))
        body_bytes = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(body_bytes.decode("utf-8"))
        except Exception:
            data = {}

        if path == "/api/scan":
            if HAS_LEGACY_MODULE and scan_wifi_and_printers:
                items = scan_wifi_and_printers(sim_port=18080)
            else:
                items = [{"label": "📡 Default Instax SHARE (192.168.0.251:8080)", "ip": "192.168.0.251", "port": 8080}]
            self._send_json({"ok": True, "items": items})
            return

        host = data.get("ip", "192.168.0.251")
        port = int(data.get("port", 8080))
        pin = int(data.get("pin", 1111))
        model = data.get("model", "SP-2")
        simulate = bool(data.get("simulate", False))

        if simulate and SIM_SERVER:
            SIM_SERVER.model = model
            SIM_SERVER.pin = pin
            SIM_SERVER.start()
            host, port = "127.0.0.1", 18080

        if not HAS_LEGACY_MODULE or not LegacyInstaxClient:
            self._send_json({"ok": False, "error": "legacy_instax_printer module not available on server"}, status_code=500)
            return

        try:
            client = LegacyInstaxClient(host=host, port=port, pin=pin)
            if path == "/api/status":
                st = client.get_printer_status()
                self._send_json({"ok": True, "status": st})
                return
            elif path == "/api/print":
                b64_planar = data.get("planar_base64", "")
                dry_run = bool(data.get("dry_run", False))
                planar_bytes = base64.b64decode(b64_planar)
                res = client.print_planar_rgb(planar_bytes, model_name=model, dry_run=dry_run)
                self._send_json({"ok": True, "result": res})
                return
        except Exception as exc:
            self._send_json({"ok": False, "error": str(exc)}, status_code=500)
            return

        self._send_json({"ok": False, "error": "Unknown endpoint"}, status_code=404)


def main():
    parser = argparse.ArgumentParser(
        description="Legacy Instax Printer Local Wi-Fi Bridge — Print from iPhone/iPad/Safari to SP-1, SP-2 & SP-3"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0 for LAN access)")
    parser.add_argument("--port", type=int, default=8089, help="HTTP port (default: 8089)")
    parser.add_argument("--no-browser", action="store_true", help="Do not auto-open browser on startup")
    args = parser.parse_args()

    lan_ip = get_lan_ip()
    lan_url = f"http://{lan_ip}:{args.port}"
    local_url = f"http://127.0.0.1:{args.port}"

    print("=" * 74)
    print("📸 LEGACY INSTAX WI-FI DIRECT BRIDGE (SP-1 • SP-2 • SP-3 • iPhone / Safari)")
    print("=" * 74)
    print(f"  🟢 Status:          Running on {platform.system()} ({socket.gethostname()})")
    print(f"  📱 iPhone / iPad:   Open Safari on your phone and go to:")
    print(f"                      👉  {lan_url}")
    print(f"  💻 This Computer:   {local_url}")
    print("-" * 74)
    print("  💡 How it works:")
    print("     1. Keep this window open on your computer (computer connected to home Wi-Fi).")
    print(f"     2. On your iPhone/iPad (connected to same Wi-Fi), open {lan_url} in Safari.")
    print("     3. Pick photos from your iPhone camera roll & tap Print!")
    print("     (Press Ctrl+C to stop the bridge)")
    print("=" * 74)

    class ReusableThreadingHTTPServer(ThreadingHTTPServer):
        allow_reuse_address = True
        daemon_threads = True

        def handle_error(self, request, client_address):
            exc = sys.exc_info()[1]
            if isinstance(exc, (ConnectionResetError, BrokenPipeError, TimeoutError, socket.timeout)):
                return
            super().handle_error(request, client_address)

    try:
        server = ReusableThreadingHTTPServer((args.host, args.port), LegacyBridgeHandler)
    except OSError as e:
        print(f"  ℹ️  Note: Port {args.port} is already active ({e}).")
        print(f"  🟢 Your Legacy Wi-Fi Bridge is already running at: {lan_url}")
        if not args.no_browser:
            try:
                webbrowser.open(local_url)
            except Exception:
                pass
        return

    if not args.no_browser:
        try:
            webbrowser.open(local_url)
        except Exception:
            pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Stopping Legacy Instax Wi-Fi Bridge...")
        server.server_close()


if __name__ == "__main__":
    main()
