#!/usr/bin/env python3
"""
Instax Local Wi-Fi Bluetooth Bridge (for iPhone Safari, iPad Safari, Mac Safari & Firefox)
==========================================================================================
Why this exists:
  Apple disables the Web Bluetooth API (`navigator.bluetooth`) inside iOS Safari, iOS Chrome,
  and macOS Safari (and Mozilla disables it in Firefox).

How this solves it effortlessly at home:
  Run this lightweight bridge on your Mac, Windows PC, or Linux computer. It hosts the
  Instax Web App on your local home Wi-Fi (e.g. http://192.168.1.x:8765).
  Open that link in regular iPhone Safari (or Mac Safari / Firefox) — zero iOS apps required!
  When you tap Connect or Print on your iPhone, your iPhone sends the framed photo/collage/QR
  over Wi-Fi to your computer, which immediately prints it over Bluetooth to your Instax printer.
"""

import argparse
import base64
import json
import os
import platform
import re
import socket
import subprocess
import sys
import tempfile
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
WEB_HTML_PATH = os.path.join(SCRIPT_DIR, "InstaxPrinterWeb.html")


def get_lan_ip() -> str:
    """Detect the computer's active local Wi-Fi / LAN IPv4 address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass
    try:
        hostname = socket.gethostname()
        for addr in socket.gethostbyname_ex(hostname)[2]:
            if not addr.startswith("127."):
                return addr
    except Exception:
        pass
    return "127.0.0.1"


def find_cli_command(args_list):
    """Return the platform-appropriate CLI command to talk to the Instax BLE printer."""
    sys_name = platform.system()
    if sys_name == "Darwin":
        mac_bin = os.path.join(REPO_ROOT, "macOS", "instax-square")
        root_bin = os.path.join(REPO_ROOT, "instax-square")
        lr_bin = os.path.join(
            REPO_ROOT, "Lightroom-Classic-Plugin", "Instax-Printer.lrplugin", "bin", "mac", "instax-square"
        )
        for candidate in (mac_bin, root_bin, lr_bin):
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                return [candidate] + args_list
    # Fallback / Windows / Linux: use instax_printer.py
    win_py = os.path.join(REPO_ROOT, "Windows", "instax_printer.py")
    lin_py = os.path.join(REPO_ROOT, "Linux", "instax_printer.py")
    for py_script in (win_py, lin_py):
        if os.path.isfile(py_script):
            return [sys.executable, py_script] + args_list
    raise FileNotFoundError("Could not locate instax-square binary or instax_printer.py in repository.")


def run_ble_status(device: str = "INSTAX-") -> dict:
    """Query live printer telemetry (model, resolution, battery %, film remaining)."""
    sys_name = platform.system()
    if sys_name == "Darwin":
        cmd = find_cli_command(["status", "--device", device or "INSTAX-", "--json"])
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=18)
        if proc.returncode != 0:
            err_msg = (proc.stderr or proc.stdout or "Failed to connect to Instax printer").strip()
            raise RuntimeError(err_msg)
        stdout = proc.stdout.strip()
        # Extract JSON object from stdout
        start_idx = stdout.find("{")
        end_idx = stdout.rfind("}")
        if start_idx != -1 and end_idx != -1:
            data = json.loads(stdout[start_idx : end_idx + 1])
            data["ok"] = True
            return data
        raise RuntimeError("Unexpected status output: " + stdout)
    else:
        cmd = find_cli_command(["status", "--device", device or "INSTAX-"])
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        out = (proc.stdout or "") + "\n" + (proc.stderr or "")
        if proc.returncode != 0:
            raise RuntimeError(out.strip() or "Failed to connect to Instax printer")
        # Parse text output from instax_printer.py status
        film = 0
        batt = 100
        charging = False
        w, h = 800, 800
        dev_name = device or "INSTAX"
        m_film = re.search(r"Film(?: Remaining| Left)?\s*:\s*(\d+)/10", out, re.I)
        if m_film:
            film = int(m_film.group(1))
        m_batt = re.search(r"Battery\s*:\s*(\d+)%", out, re.I)
        if m_batt:
            batt = int(m_batt.group(1))
        if "charging" in out.lower() and "discharging" not in out.lower():
            charging = True
        m_res = re.search(r"(\d{3,4})\s*[x×]\s*(\d{3,4})", out)
        if m_res:
            w, h = int(m_res.group(1)), int(m_res.group(2))
        return {
            "ok": True,
            "deviceName": dev_name,
            "width": w,
            "height": h,
            "batteryPercent": batt,
            "isCharging": charging,
            "filmRemaining": film,
            "isCoverOpen": "cover open" in out.lower(),
        }


class InstaxWiFiBridgeHandler(BaseHTTPRequestHandler):
    server_version = "InstaxWiFiBridge/1.5.4"

    def log_message(self, fmt, *args):
        sys.stdout.write(f"[Wi-Fi Bridge] {self.address_string()} - {fmt % args}\n")

    def _send_json(self, payload: dict, status_code: int = 200):
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path == "/api/bridge-ping":
            lan_ip = get_lan_ip()
            port = self.server.server_address[1]
            self._send_json({
                "ok": True,
                "bridge": "instax-wifi-bridge",
                "version": "1.5.4",
                "platform": platform.system(),
                "hostname": socket.gethostname(),
                "lan_ip": lan_ip,
                "lan_url": f"http://{lan_ip}:{port}",
            })
            return

        if path == "/api/status":
            device = qs.get("device", ["INSTAX-"])[0]
            try:
                status_data = run_ble_status(device=device)
                self._send_json(status_data)
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, status_code=500)
            return

        # Serve InstaxPrinterWeb.html at / or /InstaxPrinterWeb.html
        if path in ("/", "/index.html", "/InstaxPrinterWeb.html", "/Web-Bluetooth-Offline/InstaxPrinterWeb.html"):
            if os.path.isfile(WEB_HTML_PATH):
                with open(WEB_HTML_PATH, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        # Also allow serving LegacyInstaxPrinterWeb.html if navigated via header button
        if path.endswith("LegacyInstaxPrinterWeb.html"):
            legacy_html = os.path.join(REPO_ROOT, "Legacy-Instax-Printer", "Web-WiFi-Offline", "LegacyInstaxPrinterWeb.html")
            if os.path.isfile(legacy_html):
                with open(legacy_html, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        self.send_error(404, "Not Found")

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", "0"))
        body_bytes = self.rfile.read(length) if length > 0 else b"{}"
        try:
            data = json.loads(body_bytes.decode("utf-8"))
        except Exception:
            data = {}

        if path == "/api/stop-led":
            device = data.get("device") or "INSTAX-"
            try:
                cmd = find_cli_command(["led", "--off", "--device", device])
                subprocess.run(cmd, capture_output=True, text=True, timeout=12)
                self._send_json({"ok": True})
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, status_code=500)
            return

        if path == "/api/print":
            b64 = data.get("image_base64", "")
            model = data.get("model", "auto")
            mode = data.get("mode", "rich")
            dry_run = bool(data.get("dry_run", False))
            device = data.get("device") or "INSTAX-"

            if "," in b64:
                b64 = b64.split(",", 1)[1]

            if not b64:
                self._send_json({"ok": False, "error": "Missing image_base64 payload"}, status_code=400)
                return

            tmp_fd, tmp_path = tempfile.mkstemp(prefix="instax_wifi_bridge_", suffix=".jpg")
            os.close(tmp_fd)
            try:
                with open(tmp_path, "wb") as f:
                    f.write(base64.b64decode(b64))

                cli_args = [
                    "print",
                    tmp_path,
                    "--model", model,
                    "--mode", mode,
                    "--fit", "stretch",
                    "--device", device,
                ]
                if dry_run:
                    cli_args.append("--dry-run")

                cmd = find_cli_command(cli_args)
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
                combined_output = ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip()

                if proc.returncode != 0:
                    self._send_json({
                        "ok": False,
                        "error": combined_output or f"CLI exited with status {proc.returncode}",
                    }, status_code=500)
                    return

                # Query updated status after print if possible
                updated_status = None
                try:
                    updated_status = run_ble_status(device=device)
                except Exception:
                    pass

                self._send_json({
                    "ok": True,
                    "dry_run": dry_run,
                    "output": combined_output,
                    "status": updated_status,
                })
            except Exception as e:
                self._send_json({"ok": False, "error": str(e)}, status_code=500)
            finally:
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass
            return

        self.send_error(404, "Not Found")


def main():
    parser = argparse.ArgumentParser(
        description="Instax Local Wi-Fi Bluetooth Bridge — Print from iPhone/iPad/Mac Safari or Firefox over Home Wi-Fi"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0 for LAN Wi-Fi access)")
    parser.add_argument("--port", type=int, default=8765, help="HTTP port (default: 8765)")
    parser.add_argument("--no-browser", action="store_true", help="Do not auto-open browser on startup")
    args = parser.parse_args()

    lan_ip = get_lan_ip()
    lan_url = f"http://{lan_ip}:{args.port}"
    local_url = f"http://127.0.0.1:{args.port}"

    print("=" * 74)
    print("📸 INSTAX LOCAL WI-FI BLUETOOTH BRIDGE (iPhone / iPad / Safari / Firefox)")
    print("=" * 74)
    print(f"  🟢 Status:          Running on {platform.system()} ({socket.gethostname()})")
    print(f"  📱 iPhone / iPad:   Open Safari on your phone and go to:")
    print(f"                      👉  {lan_url}")
    print(f"  💻 This Computer:   {local_url}")
    print("-" * 74)
    print("  💡 How it works:")
    print("     1. Keep this window open on your computer (with Bluetooth ON).")
    print(f"     2. On your iPhone/iPad (connected to the same Wi-Fi), open {lan_url} in Safari.")
    print("     3. Tap '📡 Connect Instax' & '🖨 Print Physical Photo' right inside Safari!")
    print("     (Press Ctrl+C to stop the bridge)")
    print("=" * 74)

    server = ThreadingHTTPServer((args.host, args.port), InstaxWiFiBridgeHandler)
    if not args.no_browser:
        try:
            webbrowser.open(local_url)
        except Exception:
            pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Stopping Instax Local Wi-Fi Bluetooth Bridge...")
        server.server_close()


if __name__ == "__main__":
    main()
