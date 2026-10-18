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
- Real OS Wi-Fi access point scanning (macOS CoreWLAN, Windows netsh, Linux nmcli)
- Subnet TCP 8080 probe for live Instax SHARE hardware
- Dedicated /api/wifi-test diagnostics endpoint
- Built-in Virtual SP-1/2/3 TCP simulator support (127.0.0.1:18080)
"""

import argparse
import base64
import json
import os
import platform
import re
import socket
import struct
import subprocess
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Resolve canonical LegacyInstaxPrinterWeb.html path
LEGACY_HTML_PATH = None
for _cand in (
    os.path.join(SCRIPT_DIR, "LegacyInstaxPrinterWeb.html"),
    os.path.join(SCRIPT_DIR, "Web-WiFi-Offline", "LegacyInstaxPrinterWeb.html"),
    os.path.join(SCRIPT_DIR, "..", "Web-WiFi-Offline", "LegacyInstaxPrinterWeb.html"),
    os.path.join(SCRIPT_DIR, "..", "Legacy-Instax-Printer", "Web-WiFi-Offline", "LegacyInstaxPrinterWeb.html"),
):
    if os.path.isfile(_cand):
        LEGACY_HTML_PATH = os.path.abspath(_cand)
        break

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
        MODELS,
        LegacyInstaxClient,
        VirtualInstaxShareServer,
    )
    HAS_LEGACY_MODULE = True
except ImportError:
    HAS_LEGACY_MODULE = False
    MODELS = {}
    LegacyInstaxClient = None
    VirtualInstaxShareServer = None

SIM_SERVER = VirtualInstaxShareServer(port=18080, model="SP-2", pin=1111) if VirtualInstaxShareServer else None


def get_all_lan_ips() -> list:
    """Detect all non-loopback IPv4 addresses across all active network interfaces."""
    ips = []
    # Test routing to public DNS and printer gateway
    for target in [("8.8.8.8", 80), ("192.168.0.251", 8080), ("1.1.1.1", 80)]:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.settimeout(0.3)
            s.connect(target)
            ip = s.getsockname()[0]
            s.close()
            if ip and not ip.startswith("127.") and ip not in ips:
                ips.append(ip)
        except Exception:
            pass

    # Platform specific enumeration
    sys_name = platform.system().lower()
    try:
        if "darwin" in sys_name or "linux" in sys_name:
            out = subprocess.check_output(["ifconfig"], text=True, errors="ignore", timeout=2)
            for match in re.findall(r"inet\s+(\d+\.\d+\.\d+\.\d+)", out):
                if not match.startswith("127.") and match not in ips:
                    ips.append(match)
        elif "windows" in sys_name:
            out = subprocess.check_output(["ipconfig"], text=True, errors="ignore", timeout=3)
            for match in re.findall(r"IPv4 Address[.\s]+:\s*(\d+\.\d+\.\d+\.\d+)", out):
                if not match.startswith("127.") and match not in ips:
                    ips.append(match)
    except Exception:
        pass

    if not ips:
        try:
            ip = socket.gethostbyname(socket.gethostname())
            if not ip.startswith("127."):
                ips.append(ip)
        except Exception:
            pass

    return ips or ["127.0.0.1"]


def get_lan_ip() -> str:
    """Detect the machine's primary Wi-Fi / LAN IP address."""
    ips = get_all_lan_ips()
    # Prefer 192.168.0.x if connected to Instax Wi-Fi, otherwise first IP
    for ip in ips:
        if ip.startswith("192.168.0."):
            return ip
    return ips[0]


def get_connected_wifi_ssid() -> str:
    """Get the currently connected Wi-Fi SSID on macOS, Windows, or Linux."""
    sys_name = platform.system().lower()
    try:
        if "darwin" in sys_name:
            out = subprocess.check_output(["networksetup", "-getairportnetwork", "en0"], text=True, errors="ignore", timeout=3)
            if "Current Wi-Fi Network:" in out:
                return out.split(":", 1)[1].strip()
        elif "windows" in sys_name:
            out = subprocess.check_output(["netsh", "wlan", "show", "interfaces"], text=True, errors="ignore", timeout=4)
            for line in out.splitlines():
                if "SSID" in line and "BSSID" not in line and ":" in line:
                    return line.split(":", 1)[1].strip()
        elif "linux" in sys_name:
            out = subprocess.check_output(["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"], text=True, errors="ignore", timeout=4)
            for line in out.splitlines():
                if line.startswith("yes:"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    return "Not Connected"


def scan_all_nearby_wifi() -> list:
    """Scan all nearby Wi-Fi networks using native OS tools."""
    networks = []
    seen = set()
    sys_name = platform.system().lower()

    if "darwin" in sys_name:
        # Fast native CoreWLAN scan via swift
        swift_code = """
import CoreWLAN
if let iface = CWWiFiClient.shared().interface(), let list = try? iface.scanForNetworks(withName: nil) {
    for n in list {
        if let s = n.ssid, !s.isEmpty {
            print("\\(s)|\\(n.rssiValue)")
        }
    }
}
"""
        try:
            proc = subprocess.run(["swift", "-"], input=swift_code, capture_output=True, text=True, timeout=5)
            for line in proc.stdout.strip().splitlines():
                if "|" in line:
                    ssid, sig = line.split("|", 1)
                    ssid = ssid.strip()
                    if ssid and ssid not in seen:
                        seen.add(ssid)
                        networks.append({
                            "ssid": ssid,
                            "signal": f"{sig.strip()} dBm",
                            "is_instax": "INSTAX" in ssid.upper(),
                        })
        except Exception:
            pass

        # Fallback to system_profiler if swift scan didn't populate
        if not networks:
            try:
                out = subprocess.check_output(["system_profiler", "SPAirPortDataType"], text=True, errors="ignore", timeout=6)
                in_other = False
                for line in out.splitlines():
                    if "Other Local Wi-Fi Networks:" in line:
                        in_other = True
                        continue
                    if in_other:
                        stripped = line.strip()
                        if stripped.endswith(":") and not stripped.startswith("PHY") and not stripped.startswith("Channel") and not stripped.startswith("Security"):
                            ssid = stripped[:-1].strip()
                            if ssid and ssid not in seen:
                                seen.add(ssid)
                                networks.append({
                                    "ssid": ssid,
                                    "signal": "Visible",
                                    "is_instax": "INSTAX" in ssid.upper(),
                                })
            except Exception:
                pass

    elif "windows" in sys_name:
        try:
            out = subprocess.check_output(["netsh", "wlan", "show", "networks", "mode=bssid"], text=True, errors="ignore", timeout=5)
            curr_ssid = None
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("SSID") and ":" in line and "BSSID" not in line:
                    curr_ssid = line.split(":", 1)[1].strip()
                elif line.startswith("Signal") and ":" in line and curr_ssid:
                    sig = line.split(":", 1)[1].strip()
                    if curr_ssid and curr_ssid not in seen:
                        seen.add(curr_ssid)
                        networks.append({
                            "ssid": curr_ssid,
                            "signal": sig,
                            "is_instax": "INSTAX" in curr_ssid.upper(),
                        })
                    curr_ssid = None
        except Exception:
            pass

    elif "linux" in sys_name:
        try:
            out = subprocess.check_output(["nmcli", "-t", "-f", "SSID,SIGNAL", "dev", "wifi", "list"], text=True, errors="ignore", timeout=5)
            for line in out.splitlines():
                if ":" in line:
                    ssid, sig = line.split(":", 1)
                    ssid = ssid.strip()
                    if ssid and ssid not in seen:
                        seen.add(ssid)
                        networks.append({
                            "ssid": ssid,
                            "signal": f"{sig.strip()}%",
                            "is_instax": "INSTAX" in ssid.upper(),
                        })
        except Exception:
            pass

    # Sort so any INSTAX printers are at the top, then alphabetically
    networks.sort(key=lambda x: (not x["is_instax"], x["ssid"].lower()))
    return networks


def probe_tcp_printer(host: str, port: int, timeout: float = 0.5) -> bool:
    """Test raw TCP connection to an Instax SHARE printer."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False


def run_full_wifi_diagnostics(sim_port: int = 18080) -> dict:
    """Run full Wi-Fi environment test and printer discovery."""
    lan_ip = get_lan_ip()
    connected_ssid = get_connected_wifi_ssid()
    all_networks = scan_all_nearby_wifi()
    instax_networks = [n for n in all_networks if n["is_instax"]]

    # TCP Probes
    hardware_printer_found = probe_tcp_printer("192.168.0.251", 8080, timeout=0.6)
    alt_gw_found = probe_tcp_printer("192.168.0.1", 8080, timeout=0.4)
    sim_found = probe_tcp_printer("127.0.0.1", sim_port, timeout=0.2)

    # Build formatted dropdown items for UI
    items = []
    if hardware_printer_found:
        items.append({
            "label": "🟢 Discovered Live Instax Printer (192.168.0.251:8080)",
            "ip": "192.168.0.251",
            "port": 8080,
            "status": "online",
        })
    if alt_gw_found:
        items.append({
            "label": "🟢 Discovered Printer on Gateway (192.168.0.1:8080)",
            "ip": "192.168.0.1",
            "port": 8080,
            "status": "online",
        })

    # Add any nearby INSTAX-XXXXXXXX Wi-Fi networks found in the air
    for instax in instax_networks:
        items.append({
            "label": f"📸 {instax['ssid']} ({instax['signal']}) — Connect in Wi-Fi Settings",
            "ip": "192.168.0.251",
            "port": 8080,
            "ssid": instax["ssid"],
            "status": "hotspot_found",
        })

    items.append({
        "label": "🎯 Default Instax SHARE (192.168.0.251:8080)",
        "ip": "192.168.0.251",
        "port": 8080,
        "status": "default",
    })
    items.append({
        "label": "🧪 Built-in Virtual SP-1/2/3 Simulator (127.0.0.1:18080)",
        "ip": "127.0.0.1",
        "port": sim_port,
        "is_simulator": True,
        "status": "simulator",
    })

    return {
        "ok": True,
        "lan_ip": lan_ip,
        "connected_ssid": connected_ssid,
        "networks_count": len(all_networks),
        "all_networks": all_networks,
        "instax_networks": instax_networks,
        "hardware_printer_reachable": hardware_printer_found,
        "simulator_reachable": sim_found,
        "items": items,
    }


class LegacyBridgeHandler(BaseHTTPRequestHandler):
    server_version = "LegacyInstaxBridge/1.5.4"

    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError, TimeoutError, socket.timeout, OSError):
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
                "connected_wifi": get_connected_wifi_ssid(),
            })
            return

        if path in ("/api/scan", "/api/wifi-test"):
            diag = run_full_wifi_diagnostics(sim_port=18080)
            self._send_json(diag)
            return

        # Serve LegacyInstaxPrinterWeb.html at / or /LegacyInstaxPrinterWeb.html
        if path in ("/", "/index.html", "/LegacyInstaxPrinterWeb.html", "/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html"):
            if LEGACY_HTML_PATH and os.path.isfile(LEGACY_HTML_PATH):
                with open(LEGACY_HTML_PATH, "rb") as f:
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

        if path in ("/api/scan", "/api/wifi-test"):
            diag = run_full_wifi_diagnostics(sim_port=18080)
            self._send_json(diag)
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
        description="Legacy Instax Local Wi-Fi Bridge — Print from iPhone / iPad Safari to SP-1, SP-2 & SP-3"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0 for Wi-Fi access)")
    parser.add_argument("--port", type=int, default=8089, help="HTTP port (default: 8089)")
    parser.add_argument("--no-browser", action="store_true", help="Do not auto-open browser on startup")
    args = parser.parse_args()

    lan_ip = get_lan_ip()
    all_ips = get_all_lan_ips()
    local_url = f"http://127.0.0.1:{args.port}"
    lan_url = f"http://{lan_ip}:{args.port}"
    connected_wifi = get_connected_wifi_ssid()

    print("=" * 76)
    print("📸 LEGACY INSTAX LOCAL WI-FI BRIDGE (SP-1 • SP-2 • SP-3 • iPhone / Safari)")
    print("=" * 76)
    print(f"  🟢 Status:          Running on {platform.system()} ({socket.gethostname()})")
    print(f"  📶 Connected Wi-Fi: {connected_wifi}")
    print(f"  📱 iPhone / iPad:   Open Safari on your phone and go to:")
    for ip in all_ips:
        if ip.startswith("192.168.0."):
            print(f"                      👉 http://{ip}:{args.port}  (iPhone joined to {connected_wifi})")
        else:
            print(f"                      👉 http://{ip}:{args.port}  (iPhone on Home Wi-Fi / LAN)")
    print(f"  💻 This Computer:   {local_url}")
    print("-" * 76)
    print("  💡 How to print from iPhone / iPad Safari:")
    print("     1. Connect your iPhone's Wi-Fi to the same network as this computer.")
    print(f"     2. On your iPhone, open http://{lan_ip}:{args.port} in Safari.")
    print("     3. Pick photos from your Camera Roll, frame them & tap Print!")
    print("     (Press Ctrl+C to stop the bridge)")
    print("=" * 76)

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
