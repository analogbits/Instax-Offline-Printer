#!/usr/bin/env python3
"""
Instax Cross-Platform Printer Engine & CLI (macOS, Windows, Linux)
Reverse-engineered Bluetooth Low Energy implementation for:
  - Instax SQUARE Link (800x800)
  - Instax Link WIDE (1260x840)
  - Instax Mini Link (600x800)

Requirements:
  pip install bleak pillow
"""

import sys
import os
import io
import time
import struct
import asyncio
import argparse
from typing import Optional, Tuple, List, Callable
from PIL import Image, ImageOps, ImageEnhance

# BLE GATT Service and Characteristic UUIDs
SERVICE_UUID = "70954782-2d83-473d-9e5f-81e1d02d5273"
WRITE_CHAR_UUID = "70954783-2d83-473d-9e5f-81e1d02d5273"
NOTIFY_CHAR_UUID = "70954784-2d83-473d-9e5f-81e1d02d5273"

DEFAULT_DEVICE_NAME = "INSTAX-50271289"

# SIDs
SID_DEVICE_INFO = (0x00, 0x01)
SID_SUPPORT_INFO = (0x00, 0x02)
SID_PRINT_START = (0x10, 0x00)
SID_PRINT_DATA = (0x10, 0x01)
SID_PRINT_END = (0x10, 0x02)
SID_PRINT_CANCEL = (0x10, 0x03)
SID_PRINT_EXEC = (0x10, 0x80)
SID_LED_PATTERN = (0x30, 0x01)

SID_NAMES = {
    (0x00, 0x00): "SupportFunctionAndVersionInfo",
    (0x00, 0x01): "DeviceInfoService",
    (0x00, 0x02): "SupportFunctionInfo",
    (0x10, 0x00): "PrintImageDownloadStart",
    (0x10, 0x01): "PrintImageDownloadData",
    (0x10, 0x02): "PrintImageDownloadEnd",
    (0x10, 0x03): "PrintImageDownloadCancel",
    (0x10, 0x80): "PrintImage",
    (0x30, 0x01): "LedPatternSettings",
}

class InstaxPacket:
    @staticmethod
    def build(sid: Tuple[int, int], payload: bytes = b"") -> bytes:
        total_len = 7 + len(payload)
        hdr = bytes([0x41, 0x62, (total_len >> 8) & 0xFF, total_len & 0xFF, sid[0], sid[1]])
        body = hdr + payload
        chk = (255 - (sum(body) & 0xFF)) & 0xFF
        return body + bytes([chk])

    @staticmethod
    def parse(data: bytes):
        if len(data) < 8:
            return None
        if data[0] != 0x61 or data[1] != 0x42:
            return None
        length = (data[2] << 8) | data[3]
        if len(data) < length:
            return None
        sid = (data[4], data[5])
        res_code = data[6]
        payload = data[7:length-1] if length > 8 else b""
        return {"sid": sid, "res_code": res_code, "payload": payload, "raw": data[:length]}

class InstaxPrinterStatus:
    def __init__(self):
        self.device_name = ""
        self.width = 800
        self.height = 800
        self.chunk_size = 1808
        self.max_jpeg_size = 60 * 1024
        self.battery_level = 4
        self.battery_percent = 100
        self.is_charging = False
        self.film_remaining = 10
        self.is_cover_open = False
        self.total_prints = 0
        self.supports_3d_lut = False
        self.wait_seconds = 12
        self.model_number = ""

class InstaxBLE:
    def __init__(self, log_callback: Optional[Callable[[str], None]] = None):
        self.client = None
        self.log_callback = log_callback
        self.rx_buffer = bytearray()
        self.response_future: Optional[asyncio.Future] = None
        self.pending_sid: Optional[Tuple[int, int]] = None

    def log(self, msg: str):
        if self.log_callback:
            self.log_callback(msg)
        else:
            print(msg)

    async def scan(self, timeout: float = 4.0) -> List[dict]:
        from bleak import BleakScanner
        self.log(f"Scanning for nearby Instax printers ({timeout}s)...")
        devices = await BleakScanner.discover(timeout=timeout)
        instax_devs = []
        for d in devices:
            name = d.name or ""
            uuids = [str(u).lower() for u in (d.metadata.get("uuids") or [])]
            if name.upper().startswith("INSTAX") or SERVICE_UUID.lower() in uuids:
                instax_devs.append({"name": name or "INSTAX Printer", "address": d.address, "rssi": d.rssi, "device": d})
        instax_devs.sort(key=lambda x: x["rssi"] if x["rssi"] is not None else -100, reverse=True)
        return instax_devs

    async def connect(self, target: str = DEFAULT_DEVICE_NAME, timeout: float = 8.0):
        from bleak import BleakClient, BleakScanner
        self.log(f"Searching for printer matching '{target}'...")
        device = None
        target_upper = target.strip().upper()

        devs = await BleakScanner.discover(timeout=timeout)
        for d in devs:
            name = (d.name or "").upper()
            addr = d.address.upper()
            if target_upper in name or target_upper == addr or (target_upper == "INSTAX" and name.startswith("INSTAX")):
                device = d
                break

        if not device:
            raise ConnectionError(f"Could not find Instax printer matching '{target}'. Make sure it is powered ON and disconnected from your phone.")

        self.log(f"Connecting to {device.name} ({device.address})...")
        self.client = BleakClient(device)
        await self.client.connect()
        self.log("Connected! Starting notifications on NOTIFY characteristic...")

        await self.client.start_notify(NOTIFY_CHAR_UUID, self._on_notify)
        await asyncio.sleep(0.3)

    def _on_notify(self, sender, data: bytearray):
        self.rx_buffer.extend(data)
        while len(self.rx_buffer) >= 4:
            if self.rx_buffer[0] != 0x61 or self.rx_buffer[1] != 0x42:
                idx = self.rx_buffer.find(b"\x61\x42")
                if idx >= 0:
                    del self.rx_buffer[:idx]
                else:
                    self.rx_buffer.clear()
                    return
            if len(self.rx_buffer) < 4:
                return
            pkt_len = (self.rx_buffer[2] << 8) | self.rx_buffer[3]
            if pkt_len < 7 or pkt_len > 4096:
                del self.rx_buffer[:2]
                continue
            if len(self.rx_buffer) < pkt_len:
                return
            pkt_data = bytes(self.rx_buffer[:pkt_len])
            del self.rx_buffer[:pkt_len]

            parsed = InstaxPacket.parse(pkt_data)
            if parsed:
                sid_name = SID_NAMES.get(parsed["sid"], f"SID{parsed['sid']}")
                hex_sample = " ".join(f"{b:02X}" for b in parsed["payload"][:16])
                self.log(f"[RX] <- {sid_name} [Code: 0x{parsed['res_code']:02X}] ({len(parsed['payload'])}B) [{hex_sample}]")
                if self.response_future and not self.response_future.done():
                    if self.pending_sid is None or parsed["sid"] == self.pending_sid:
                        self.response_future.set_result(parsed)

    async def send_command(self, sid: Tuple[int, int], payload: bytes = b"", timeout: float = 12.0) -> dict:
        if not self.client or not self.client.is_connected:
            raise ConnectionError("Printer is not connected.")

        packet = InstaxPacket.build(sid, payload)
        sid_name = SID_NAMES.get(sid, f"SID{sid}")
        hex_sample = " ".join(f"{b:02X}" for b in packet[:16])
        self.log(f"[TX] -> {sid_name} ({len(packet)}B) [{hex_sample}]")

        loop = asyncio.get_running_loop()
        self.pending_sid = sid
        self.response_future = loop.create_future()

        # Send in MTU slices (withoutResponse)
        mtu = max(20, self.client.mtu_size - 3) if hasattr(self.client, "mtu_size") and self.client.mtu_size else 182
        for offset in range(0, len(packet), mtu):
            chunk = packet[offset:offset+mtu]
            await self.client.write_gatt_char(WRITE_CHAR_UUID, chunk, response=False)
            await asyncio.sleep(0.006)

        return await asyncio.wait_for(self.response_future, timeout=timeout)

    async def fetch_status(self) -> InstaxPrinterStatus:
        st = InstaxPrinterStatus()

        # Model Info
        try:
            r = await self.send_command(SID_DEVICE_INFO, b"\x01", timeout=4.0)
            if r["res_code"] == 0 and len(r["payload"]) > 1:
                st.model_number = r["payload"][1:].decode("ascii", errors="ignore").strip()
        except Exception:
            pass

        # Image Function Info
        r = await self.send_command(SID_SUPPORT_INFO, b"\x00", timeout=5.0)
        p = r["payload"]
        if r["res_code"] == 0 and len(p) >= 7:
            w = (p[1] << 8) | p[2]
            h = (p[3] << 8) | p[4]
            if w > 0 and h > 0:
                st.width = w
                st.height = h
            pkt_sz = (p[5] << 8) | p[6]
            if 128 <= pkt_sz <= 4096:
                st.chunk_size = pkt_sz
            st.supports_3d_lut = ((p[6] >> 3) & 0x01) == 1
            if len(p) >= 11:
                max_j = (p[7] << 24) | (p[8] << 16) | (p[9] << 8) | p[10]
                if 10000 <= max_j <= 500000:
                    st.max_jpeg_size = max_j

        # Battery Info
        r = await self.send_command(SID_SUPPORT_INFO, b"\x01", timeout=5.0)
        p = r["payload"]
        if r["res_code"] == 0 and len(p) >= 2:
            st.battery_level = p[1] & 0x07
            st.is_charging = ((p[1] >> 3) & 0x01) == 1
            if len(p) >= 3:
                pct = p[2]
                st.battery_percent = 100 if pct > 94 else pct

        # Printer State Info
        r = await self.send_command(SID_SUPPORT_INFO, b"\x02", timeout=5.0)
        p = r["payload"]
        if r["res_code"] == 0 and len(p) >= 2:
            st.film_remaining = p[1] & 0x0F
            if len(p) >= 3:
                st.is_cover_open = (p[2] & 0x01) == 1
            if len(p) >= 5:
                st.wait_seconds = p[4] + 3

        # History
        try:
            r = await self.send_command(SID_SUPPORT_INFO, b"\x03", timeout=4.0)
            p = r["payload"]
            if r["res_code"] == 0 and len(p) >= 5:
                st.total_prints = (p[1] << 24) | (p[2] << 16) | (p[3] << 8) | p[4]
        except Exception:
            pass

        self.log(f"[STATUS] Hardware: Battery={st.battery_percent}%, Film={st.film_remaining}/10, Res={st.width}x{st.height}, Cover={'OPEN' if st.is_cover_open else 'Closed'}")
        return st

    async def flash_rainbow_led(self):
        payload = bytes([
            0x00, 0x06, 0x0F, 0x00,
            0x00, 0x00, 0xFF,
            0x00, 0x7F, 0xFF,
            0x00, 0xFF, 0xFF,
            0x00, 0xFF, 0x00,
            0xFF, 0x00, 0x00,
            0xFF, 0x00, 0x8B
        ])
        await self.send_command(SID_LED_PATTERN, payload)
        await asyncio.sleep(1.4)
        await self.stop_led()

    async def stop_led(self):
        stop_payload = bytes([0x00, 0x01, 0x05, 0x00, 0x00, 0x00, 0x00])
        await self.send_command(SID_LED_PATTERN, stop_payload)

    async def print_jpeg(self, jpeg_data: bytes, mode: str = "rich", progress_cb: Optional[Callable[[str, float], None]] = None) -> InstaxPrinterStatus:
        if progress_cb: progress_cb("Checking printer status...", 0.04)
        st = await self.fetch_status()

        if st.is_cover_open:
            raise RuntimeError("Printer film cover is open. Please close the back compartment.")
        if st.film_remaining <= 0:
            raise RuntimeError("No film remaining (0/10) in printer cartridge.")
        if st.battery_percent < 6 and not st.is_charging:
            raise RuntimeError(f"Battery is too low ({st.battery_percent}%) to print.")

        opt_byte = 0x08 if (mode == "natural" and st.supports_3d_lut) else 0x00
        frame_sz = st.chunk_size if st.chunk_size > 0 else 1808

        # Pad to boundary
        padded = bytearray(jpeg_data)
        rem = len(padded) % frame_sz
        if rem != 0:
            padded.extend(b"\x00" * (frame_sz - rem))

        if progress_cb: progress_cb("Starting image download...", 0.08)
        tot_sz = len(padded)
        start_payload = bytes([0x02, opt_byte, 0x00, 0x00, (tot_sz >> 24) & 0xFF, (tot_sz >> 16) & 0xFF, (tot_sz >> 8) & 0xFF, tot_sz & 0xFF])
        r = await self.send_command(SID_PRINT_START, start_payload)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_START rejected: code 0x{r['res_code']:02X}")

        tot_frames = len(padded) // frame_sz
        try:
            for seq in range(tot_frames):
                chunk = padded[seq * frame_sz : (seq + 1) * frame_sz]
                payload = bytes([(seq >> 24) & 0xFF, (seq >> 16) & 0xFF, (seq >> 8) & 0xFF, seq & 0xFF]) + chunk
                pct = 0.10 + (seq + 1) / tot_frames * 0.75
                if progress_cb: progress_cb(f"Uploading chunk {seq+1}/{tot_frames}...", pct)
                res = await self.send_command(SID_PRINT_DATA, payload, timeout=15.0)
                if res["res_code"] != 0:
                    raise RuntimeError(f"Chunk {seq+1} rejected with code 0x{res['res_code']:02X}")
        except Exception as e:
            try: await self.send_command(SID_PRINT_CANCEL, b"")
            except Exception: pass
            raise e

        if progress_cb: progress_cb("Finalizing image transfer...", 0.88)
        r = await self.send_command(SID_PRINT_END, b"", timeout=10.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_END rejected: code 0x{r['res_code']:02X}")

        if progress_cb: progress_cb("Triggering physical exposure & film ejection...", 0.93)
        r = await self.send_command(SID_PRINT_EXEC, b"", timeout=15.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_EXEC rejected: code 0x{r['res_code']:02X}")

        wait_s = st.wait_seconds
        if r["payload"] and r["payload"][0] > 0:
            wait_s = r["payload"][0] + 3

        if progress_cb: progress_cb(f"Ejecting film ({wait_s}s)...", 0.97)
        await asyncio.sleep(min(wait_s, 15))

        updated_st = await self.fetch_status()
        if progress_cb: progress_cb(f"Print complete! Remaining film: {updated_st.film_remaining}/10", 1.0)
        return updated_st

    async def disconnect(self):
        if self.client and self.client.is_connected:
            await self.client.disconnect()
        self.client = None

def render_image(
    src_path: str,
    target_width: int = 800,
    target_height: int = 800,
    fit_mode: str = "crop",
    bg_color: Tuple[int, int, int] = (255, 255, 255),
    rotation: int = 0,
    zoom: float = 1.0,
    pan_x: float = 0.0,
    pan_y: float = 0.0,
    max_bytes: int = 60 * 1024
) -> bytes:
    with Image.open(src_path) as raw:
        img = ImageOps.exif_transpose(raw).convert("RGB")

    if rotation != 0:
        img = img.rotate(-rotation, expand=True, resample=Image.BICUBIC)

    if fit_mode == "stretch":
        resized = img.resize((target_width, target_height), Image.LANCZOS)
    elif fit_mode == "fit":
        canvas = Image.new("RGB", (target_width, target_height), bg_color)
        img_aspect = img.width / img.height
        tgt_aspect = target_width / target_height
        if img_aspect > tgt_aspect:
            w = target_width
            h = int(w / img_aspect)
        else:
            h = target_height
            w = int(h * img_aspect)
        w = max(1, int(w * zoom))
        h = max(1, int(h * zoom))
        sc = img.resize((w, h), Image.LANCZOS)
        x = (target_width - w) // 2 + int(pan_x * (target_width / 2))
        y = (target_height - h) // 2 + int(pan_y * (target_height / 2))
        canvas.paste(sc, (x, y))
        resized = canvas
    else: # crop
        canvas = Image.new("RGB", (target_width, target_height), bg_color)
        img_aspect = img.width / img.height
        tgt_aspect = target_width / target_height
        if img_aspect > tgt_aspect:
            h = target_height
            w = int(h * img_aspect)
        else:
            w = target_width
            h = int(w / img_aspect)
        w = max(1, int(w * zoom))
        h = max(1, int(h * zoom))
        sc = img.resize((w, h), Image.LANCZOS)
        x = (target_width - w) // 2 + int(pan_x * (target_width / 2))
        y = (target_height - h) // 2 + int(pan_y * (target_height / 2))
        canvas.paste(sc, (x, y))
        resized = canvas

    # JPEG Compression Search
    quality = 94
    while quality >= 15:
        buf = io.BytesIO()
        resized.save(buf, format="JPEG", quality=quality, progressive=False)
        data = buf.getvalue()
        if len(data) <= max_bytes or quality <= 16:
            return data
        quality -= 4
    return data

# CLI
async def main_cli():
    parser = argparse.ArgumentParser(description="Instax Cross-Platform Bluetooth Printer CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # scan
    p_scan = subparsers.add_parser("scan", help="Scan for nearby Instax printers")
    p_scan.add_argument("--timeout", type=float, default=4.0)

    # status
    p_status = subparsers.add_parser("status", help="Query printer hardware status")
    p_status.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)

    # led
    p_led = subparsers.add_parser("led", help="Control LED pattern")
    p_led.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)
    p_led.add_argument("--off", action="store_true", help="Stop LED pattern")

    # print
    p_print = subparsers.add_parser("print", help="Print one or more images")
    p_print.add_argument("images", nargs="+")
    p_print.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)
    p_print.add_argument("--mode", choices=["rich", "natural"], default="rich")
    p_print.add_argument("--fit", choices=["crop", "fit", "stretch"], default="crop")
    p_print.add_argument("--width", type=int, default=800)
    p_print.add_argument("--height", type=int, default=800)

    args = parser.parse_args()
    ble = InstaxBLE()

    try:
        if args.command == "scan":
            devs = await ble.scan(args.timeout)
            print(f"Discovered {len(devs)} printer(s):")
            for d in devs:
                print(f"  • {d['name']} ({d['address']}) - RSSI: {d['rssi']} dBm")

        elif args.command == "status":
            await ble.connect(args.device)
            st = await ble.fetch_status()
            print(f"\nPrinter Status: {args.device}")
            print(f"  • Model: {st.model_number}")
            print(f"  • Film Remaining: {st.film_remaining}/10")
            print(f"  • Battery: {st.battery_percent}% ({'Charging' if st.is_charging else 'Discharging'})")
            print(f"  • Resolution: {st.width} x {st.height} px")
            print(f"  • Compartment Door: {'OPEN ⚠️' if st.is_cover_open else 'Closed ✓'}")
            print(f"  • Total Lifetime Prints: {st.total_prints}")
            await ble.disconnect()

        elif args.command == "led":
            await ble.connect(args.device)
            if args.off:
                print("Stopping LED pattern...")
                await ble.stop_led()
            else:
                print("Flashing rainbow pattern...")
                await ble.flash_rainbow_led()
            await ble.disconnect()
            print("Done!")

        elif args.command == "print":
            await ble.connect(args.device)
            st = await ble.fetch_status()
            w = st.width if st.width > 0 else args.width
            h = st.height if st.height > 0 else args.height
            max_b = st.max_jpeg_size if st.max_jpeg_size > 0 else 60*1024

            for idx, img_path in enumerate(args.images):
                print(f"\n[{idx+1}/{len(args.images)}] Processing {img_path} for {w}x{h} px...")
                jpeg = render_image(img_path, target_width=w, target_height=h, fit_mode=args.fit, max_bytes=max_b)
                print(f"  Compressed JPEG: {len(jpeg)/1024:.1f} KB")

                def progress(stage, pct):
                    bar = "█" * int(pct * 25) + "░" * (25 - int(pct * 25))
                    print(f"\r  [{bar}] {int(pct*100):3d}% — {stage}", end="", flush=True)

                res = await ble.print_jpeg(jpeg, mode=args.mode, progress_cb=progress)
                print(f"\n  ✓ Print complete! Film remaining: {res.film_remaining}/10")
                if idx + 1 < len(args.images):
                    print("  Waiting 3s before next print...")
                    await asyncio.sleep(3)

            await ble.disconnect()
            print("\n🎉 Bulk print complete!")

    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main_cli())
