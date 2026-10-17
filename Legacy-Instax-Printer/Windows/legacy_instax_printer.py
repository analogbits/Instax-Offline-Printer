#!/usr/bin/env python3
"""
Legacy Instax Printer — Offline Wi-Fi Direct Engine & CLI (SP-1 • SP-2 • SP-3)
==============================================================================
100% offline TCP/IP protocol implementation for Fujifilm Instax SHARE SP-1, SP-2,
and SP-3 printers over Wi-Fi Direct (192.168.0.251:8080, default PIN 1111).
Includes a built-in Virtual SP-1/2/3 TCP Server (127.0.0.1:18080) and Dry-Run
0-Film Verification mode.
"""

import argparse
import socket
import struct
import sys
import threading
import time
from typing import Callable, Optional, Tuple

try:
    from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# Command Types (mode = 0x24 = 36, response mode = 0x2A = 42)
CMD_SPECIFICATIONS = 0x4F  # 79
CMD_RESET          = 0x50  # 80
CMD_PREP_IMAGE     = 0x51  # 81
CMD_SEND_IMAGE     = 0x52  # 82
CMD_TRIGGER_PRINT  = 0x53  # 83
CMD_LOCK_STATE     = 0xB0  # 176
CMD_PRINTER_LOCK   = 0xB3  # 179
CMD_VERSION        = 0xC0  # 192
CMD_PRINT_COUNT    = 0xC1  # 193
CMD_MODEL_NAME     = 0xC2  # 194
CMD_PRINT_STATUS   = 0xC3  # 195
CMD_PRE_PRINT      = 0xC4  # 196

MODELS = {
    "SP-1": {"width": 600, "height": 800, "segment_size": 60000, "segments": 24, "rotate_cw": True},
    "SP-2": {"width": 600, "height": 800, "segment_size": 60000, "segments": 24, "rotate_cw": True},
    "SP-3": {"width": 800, "height": 800, "segment_size": 60000, "segments": 32, "rotate_cw": True},
}

RETURN_CODE_LABELS = {
    0: "OK (Ready)",
    127: "Parameter / Syntax Error (0x7F)",
    160: "Printer Busy (0xA0)",
    161: "Invalid Image Data Format (0xA1)",
    162: "Battery Too Low to Print (0xA2)",
    163: "Printing in Progress (0xA3)",
    164: "Ejecting Film (0xA4)",
    180: "Printer Charging / Voltage Wait (0xB4)",
    244: "Out of Instax Film (0xF4)",
    245: "Cam Point / Mechanism Error (0xF5)",
    246: "Film Motor Jam Error (0xF6)",
    247: "Incorrect Printer PIN Code (0xF7 — Default is 1111)",
    248: "PI Sensor Error (0xF8)",
}


def build_command_packet(cmd_type: int, session_time: int, pin_code: int = 1111, payload: bytes = b"") -> bytes:
    total_len = 16 + len(payload)
    header = struct.pack(
        ">BBHIHH",
        0x24,
        cmd_type & 0xFF,
        total_len & 0xFFFF,
        session_time & 0xFFFFFFFF,
        pin_code & 0xFFFF,
        0x0000,
    )
    body = header + payload
    chk = (sum(body) ^ 0xFFFF) & 0xFFFF
    trailer = struct.pack(">HBB", chk, 0x0D, 0x0A)
    return body + trailer


def parse_response_packet(data: bytes) -> dict:
    if len(data) < 16:
        raise ValueError(f"Packet too short ({len(data)} bytes)")
    mode, cmd_type, length, session_time = struct.unpack(">BBHI", data[:8])
    return_code = data[12]
    unknown1 = data[13]
    ejecting = (data[14] >> 2) & 0xFF
    batt_and_prints = data[15]
    battery = (batt_and_prints >> 4) & 0x07
    film = batt_and_prints & 0x0F
    payload_end = max(16, min(len(data), length) - 4)
    payload = data[16:payload_end]
    return {
        "mode": mode,
        "cmd_type": cmd_type,
        "length": length,
        "session_time": session_time,
        "return_code": return_code,
        "return_label": RETURN_CODE_LABELS.get(return_code, f"Code {return_code}"),
        "unknown1": unknown1,
        "ejecting": ejecting,
        "battery": battery,
        "film": film,
        "payload": payload,
    }


def encode_planar_rgb(pil_image: "Image.Image", model_name: str = "SP-2", hw_width: Optional[int] = None, hw_height: Optional[int] = None) -> bytes:
    spec = MODELS.get(model_name.upper(), MODELS["SP-2"])
    portrait_w = hw_width or spec["width"]
    portrait_h = hw_height or spec["height"]
    img = pil_image.convert("RGB").resize((portrait_w, portrait_h), Image.Resampling.LANCZOS)
    # Rotate 90 degrees clockwise so printWidth = portrait_h (800 scanlines) and printHeight = portrait_w (600 or 800 dots)
    img = img.rotate(-90, expand=True)
    print_w, print_h = img.size

    raw_rgb = img.tobytes()
    planar = bytearray(print_w * print_h * 3)
    for h in range(print_h):
        row_offset = h * print_w * 3
        for w in range(print_w):
            px = row_offset + w * 3
            col_base = w * print_h * 3
            planar[col_base + h] = raw_rgb[px]
            planar[col_base + print_h + h] = raw_rgb[px + 1]
            planar[col_base + (print_h * 2) + h] = raw_rgb[px + 2]
    return bytes(planar)


class VirtualInstaxShareServer:
    """Built-in loopback simulator for SP-1, SP-2, and SP-3 on 127.0.0.1:18080."""

    def __init__(self, port: int = 18080, model: str = "SP-2", pin: int = 1111):
        self.port = port
        self.model = model
        self.pin = pin
        self.film_remaining = 8
        self.battery_level = 4
        self.total_prints = 128
        self._poll_counter = 0
        self._sock: Optional[socket.socket] = None
        self._running = False

    def start(self) -> bool:
        if self._running:
            return True
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind(("127.0.0.1", self.port))
            s.listen(8)
            self._sock = s
            self._running = True
            t = threading.Thread(target=self._accept_loop, daemon=True)
            t.start()
            return True
        except Exception:
            return False

    def stop(self):
        self._running = False
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass
            self._sock = None

    def _accept_loop(self):
        while self._running and self._sock:
            try:
                conn, _ = self._sock.accept()
                threading.Thread(target=self._handle_client, args=(conn,), daemon=True).start()
            except Exception:
                break

    def _handle_client(self, conn: socket.socket):
        with conn:
            while self._running:
                hdr = self._recv_exact(conn, 4)
                if not hdr:
                    break
                total_len = (hdr[2] << 8) | hdr[3]
                if total_len < 16 or total_len > 70000:
                    break
                rest = self._recv_exact(conn, total_len - 4)
                if not rest:
                    break
                pkt = hdr + rest
                cmd_type = pkt[1]
                session_time = struct.unpack(">I", pkt[4:8])[0]
                client_pin = struct.unpack(">H", pkt[8:10])[0]
                resp = self._build_response(cmd_type, session_time, pkt, client_pin == self.pin)
                conn.sendall(resp)

    @staticmethod
    def _recv_exact(conn: socket.socket, count: int) -> Optional[bytes]:
        buf = bytearray()
        while len(buf) < count:
            chunk = conn.recv(count - len(buf))
            if not chunk:
                return None
            buf.extend(chunk)
        return bytes(buf)

    def _build_response(self, cmd_type: int, session_time: int, pkt: bytes, pin_ok: bool) -> bytes:
        rc = 0 if pin_ok else 247
        payload = b""
        spec = MODELS.get(self.model, MODELS["SP-2"])

        if pin_ok:
            if cmd_type == CMD_MODEL_NAME:
                payload = self.model.encode("ascii")
            elif cmd_type == CMD_VERSION:
                payload = bytes([0x00, 0x01, 0x01, 0x12, 0x01, 0x00, 0x00, 0x00])
            elif cmd_type == CMD_PRINT_COUNT:
                payload = struct.pack(">I12x", self.total_prints)
            elif cmd_type == CMD_SPECIFICATIONS:
                payload = struct.pack(
                    ">HHHH4xHH16x",
                    spec["width"],
                    spec["height"],
                    0x0100,
                    0x0010,
                    spec["segment_size"],
                    0x0018,
                )
            elif cmd_type == CMD_PRE_PRINT:
                cmd_no = pkt[15] if len(pkt) >= 16 else 1
                payload = bytes([0x00, cmd_no, 0x00, 0x00])
            elif cmd_type in (CMD_PRINTER_LOCK, CMD_RESET):
                payload = b""
            elif cmd_type == CMD_PREP_IMAGE:
                payload = bytes([0x00, 0x1E, 0x00, 0x00])
            elif cmd_type == CMD_SEND_IMAGE:
                payload = pkt[12:16] if len(pkt) >= 16 else bytes(4)
            elif cmd_type == CMD_TRIGGER_PRINT:
                self._poll_counter = 2
                if self.film_remaining > 0:
                    self.film_remaining -= 1
                self.total_prints += 1
                payload = bytes(4)
            elif cmd_type == CMD_LOCK_STATE:
                payload = bytes([0, 0, 0, 1])
            elif cmd_type == CMD_PRINT_STATUS:
                if self._poll_counter > 0:
                    self._poll_counter -= 1
                    rc = 163
                else:
                    rc = 0
                payload = bytes(4)
            else:
                payload = bytes(4)

        total_len = 20 + len(payload)
        batt_and_prints = ((self.battery_level & 0x07) << 4) | (self.film_remaining & 0x0F)
        header = struct.pack(
            ">BBHI4xBBBB",
            0x2A,
            cmd_type & 0xFF,
            total_len & 0xFFFF,
            session_time & 0xFFFFFFFF,
            rc & 0xFF,
            0,
            0,
            batt_and_prints,
        )
        body = header + payload
        chk = (sum(body) ^ 0xFFFF) & 0xFFFF
        trailer = struct.pack(">HBB", chk, 0x0D, 0x0A)
        return body + trailer


class LegacyInstaxClient:
    """Multi-session TCP client for Instax SHARE SP-1, SP-2, and SP-3."""

    def __init__(self, host: str = "192.168.0.251", port: int = 8080, pin: int = 1111, timeout: float = 4.0):
        self.host = host
        self.port = port
        self.pin = pin
        self.timeout = timeout
        self.session_time = int(time.time() * 1000) & 0xFFFFFFFF

    def _open_session(self) -> socket.socket:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(self.timeout)
        s.connect((self.host, self.port))
        return s

    def _send_and_recv(self, sock: socket.socket, cmd_type: int, payload: bytes = b"") -> dict:
        pkt = build_command_packet(cmd_type, self.session_time, self.pin, payload)
        sock.sendall(pkt)
        hdr = VirtualInstaxShareServer._recv_exact(sock, 4)
        if not hdr:
            raise ConnectionError("Printer closed TCP connection unexpectedly.")
        total_len = (hdr[2] << 8) | hdr[3]
        rest = VirtualInstaxShareServer._recv_exact(sock, total_len - 4)
        if not rest:
            raise ConnectionError("Incomplete response packet from printer.")
        return parse_response_packet(hdr + rest)

    def get_printer_status(self) -> dict:
        with self._open_session() as s:
            m_resp = self._send_and_recv(s, CMD_MODEL_NAME)
            if m_resp["return_code"] != 0:
                raise RuntimeError(m_resp["return_label"])
            model_str = m_resp["payload"].decode("ascii", errors="ignore").strip("\x00 \r\n") or "SP-2"

            v_resp = self._send_and_recv(s, CMD_VERSION)
            fw = "v1.0"
            if len(v_resp["payload"]) >= 4:
                fw = f"v{v_resp['payload'][2]}.{v_resp['payload'][3]:02d}"

            sp_resp = self._send_and_recv(s, CMD_SPECIFICATIONS)
            max_w, max_h = 600, 800
            if len(sp_resp["payload"]) >= 4:
                max_w, max_h = struct.unpack(">HH", sp_resp["payload"][:4])

            c_resp = self._send_and_recv(s, CMD_PRINT_COUNT)
            total_prints = 0
            if len(c_resp["payload"]) >= 4:
                total_prints = struct.unpack(">I", c_resp["payload"][:4])[0]

            return {
                "model": model_str,
                "firmware": fw,
                "width": max_w,
                "height": max_h,
                "battery": m_resp["battery"],
                "film": m_resp["film"],
                "total_prints": total_prints,
            }

    def print_planar_rgb(
        self,
        planar_bytes: bytes,
        model_name: str = "SP-2",
        dry_run: bool = False,
        progress_cb: Optional[Callable[[float, str], None]] = None,
    ) -> dict:
        spec = MODELS.get(model_name.upper(), MODELS["SP-2"])
        seg_size = spec["segment_size"]
        num_segments = len(planar_bytes) // seg_size

        def notify(frac: float, msg: str):
            if progress_cb:
                progress_cb(frac, msg)

        # Phase 1: PrePrint 1..8
        notify(0.08, "Phase 1/5: Negotiating Pre-Print Handshake (1..8)...")
        with self._open_session() as s1:
            for idx in range(1, 9):
                r = self._send_and_recv(s1, CMD_PRE_PRINT, struct.pack(">I", idx))
                if r["return_code"] != 0:
                    raise RuntimeError(f"PrePrint {idx} rejected: {r['return_label']}")
        time.sleep(0.35)

        # Phase 2: Lock Printer
        notify(0.15, "Phase 2/5: Locking Instax SHARE Print Engine...")
        with self._open_session() as s2:
            r = self._send_and_recv(s2, CMD_PRINTER_LOCK, bytes([0x01, 0x00, 0x00, 0x00]))
            if r["return_code"] != 0:
                raise RuntimeError(f"PrinterLock rejected: {r['return_label']}")
        time.sleep(0.35)

        # Phase 3: Reset
        notify(0.22, "Phase 3/5: Resetting Printer Buffer...")
        with self._open_session() as s3:
            r = self._send_and_recv(s3, CMD_RESET)
            if r["return_code"] != 0:
                raise RuntimeError(f"Reset rejected: {r['return_label']}")
        time.sleep(0.35)

        # Phase 4: PrepImage + SendImage(0..N-1) + optional TriggerPrint
        with self._open_session() as s4:
            prep_payload = struct.pack(">BBI6x", 16, 0, len(planar_bytes))
            r = self._send_and_recv(s4, CMD_PREP_IMAGE, prep_payload)
            if r["return_code"] != 0:
                raise RuntimeError(f"PrepImage rejected: {r['return_label']}")

            for seg in range(num_segments):
                chunk = planar_bytes[seg * seg_size : (seg + 1) * seg_size]
                seg_payload = struct.pack(">I", seg) + chunk
                sr = self._send_and_recv(s4, CMD_SEND_IMAGE, seg_payload)
                if sr["return_code"] != 0:
                    raise RuntimeError(f"Segment {seg + 1}/{num_segments} failed: {sr['return_label']}")
                notify(
                    0.25 + (seg + 1) / num_segments * 0.60,
                    f"Phase 4/5: Transmitting Planar RGB Segment {seg + 1}/{num_segments}...",
                )

            if not dry_run:
                tr = self._send_and_recv(s4, CMD_TRIGGER_PRINT)
                if tr["return_code"] not in (0, 163, 164):
                    raise RuntimeError(f"TriggerPrint failed: {tr['return_label']}")
        time.sleep(0.35)

        # Phase 5: Status Poll or Dry Run Reset
        with self._open_session() as s5:
            if dry_run:
                self._send_and_recv(s5, CMD_RESET)
                info = self._send_and_recv(s5, CMD_MODEL_NAME)
                notify(1.0, f"Dry Run Verified! 100% of {len(planar_bytes) // 1000} KB Sent (0 Film Used)")
                return {"film": info["film"], "battery": info["battery"], "dry_run": True}
            else:
                notify(0.90, "Phase 5/5: Developing & Ejecting Instax Film...")
                self._send_and_recv(s5, CMD_LOCK_STATE)
                self._send_and_recv(s5, CMD_VERSION)
                info = self._send_and_recv(s5, CMD_MODEL_NAME)
                film, batt = info["film"], info["battery"]
                for _ in range(30):
                    poll = self._send_and_recv(s5, CMD_PRINT_STATUS)
                    film, batt = poll["film"], poll["battery"]
                    if poll["return_code"] == 0:
                        break
                    time.sleep(0.5)
                notify(1.0, f"Print Complete! ({film}/10 Film Remaining)")
                return {"film": film, "battery": batt, "dry_run": False}


def _normalize_legacy_model(raw: str) -> str:
    m = (raw or "SP-2").strip().upper()
    if "1" in m:
        return "SP-1"
    if "3" in m:
        return "SP-3"
    return "SP-2"


def main():
    parser = argparse.ArgumentParser(
        description="Legacy Instax Printer CLI — Wi-Fi Direct Tool for Fujifilm Instax SHARE SP-1, SP-2 & SP-3"
    )
    parser.add_argument("image", nargs="?", help="Path to image file to print")
    parser.add_argument("--ip", default="192.168.0.251", help="Printer IP address (default: 192.168.0.251)")
    parser.add_argument("--port", type=int, default=8080, help="Printer TCP port (default: 8080)")
    parser.add_argument("--pin", type=int, default=1111, help="Printer 4-digit PIN code (default: 1111)")
    parser.add_argument("--model", default="SP-2", help="Target model (SP-1, SP-2, SP-3 or sp1, sp2, sp3)")
    parser.add_argument("--status", action="store_true", help="Query printer status and exit")
    parser.add_argument("--dry-run", action="store_true", help="Verify Wi-Fi transfer with 0 film used")
    parser.add_argument("--simulate", action="store_true", help="Run against built-in local simulator (127.0.0.1:18080)")
    parser.add_argument("--fit", action="store_true", help="Fit image inside frame with borders (default: crop to fill)")
    parser.add_argument("--caption", default="", help="Optional bottom caption text")
    parser.add_argument("--qr", default="", help="Optional scannable QR code text/URL")
    args, _ = parser.parse_known_args()

    model_name = _normalize_legacy_model(args.model)

    sim = None
    host, port = args.ip, args.port
    if args.simulate:
        sim = VirtualInstaxShareServer(port=18080, model=model_name, pin=args.pin)
        sim.start()
        host, port = "127.0.0.1", 18080
        print(f"🟢 Started Virtual Instax SHARE {model_name} Simulator at {host}:{port}")

    client = LegacyInstaxClient(host=host, port=port, pin=args.pin)

    if args.status or not args.image:
        status = client.get_printer_status()
        print(f"Model:        {status['model']}")
        print(f"Firmware:     {status['firmware']}")
        print(f"Resolution:   {status['width']}x{status['height']}")
        print(f"Film Left:    {status['film']}/10")
        print(f"Battery:      {status['battery']}/4")
        print(f"Total Prints: {status['total_prints']}")
        return

    if not HAS_PIL:
        print("❌ Pillow (PIL) is required for image encoding: pip install pillow")
        sys.exit(1)

    img = Image.open(args.image)
    fit_mode = "fit" if args.fit else "crop"
    planar = encode_planar_rgb(img, model_name, fit_mode=fit_mode)
    result = client.print_planar_rgb(
        planar,
        model_name=model_name,
        dry_run=args.dry_run,
        progress_cb=lambda frac, msg: print(f"[{int(frac * 100):3d}%] {msg}"),
    )
    print(f"✅ Done! Film remaining: {result['film']}/10 | Battery: {result['battery']}/4")


if __name__ == "__main__":
    main()

