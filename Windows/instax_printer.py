#!/usr/bin/env python3
"""
Instax Cross-Platform Printer Engine & CLI (macOS, Windows, Linux)
==================================================================
Bit-exact Bluetooth Low Energy implementation for:
  - Instax SQUARE Link (800×800)
  - Instax Link WIDE / WIDE 2 (1260×840)
  - Instax Mini Link 1 / 2 / 3 / Link+ (600×800)

Features:
  - Auto-discovery of any nearby INSTAX-XXXXXXXX printer (sorted by RSSI)
  - Dynamic chunk size negotiation from PRINT_IMAGE_DOWNLOAD_START response
  - 0-Film Dry Run mode (--dry-run)
  - Multi-Photo Collage engine (--collage split2V|split2H|split3Hero|split3V|grid4|strips4V|grid6|grid9)
  - Scannable QR Code badge & bottom caption overlays (--qr, --caption)
  - Full compatibility with Adobe Lightroom Classic (Windows/macOS) & Darktable (Linux/Windows/macOS)

Requirements:
  pip install bleak pillow
"""

import sys
import os
import io
import math
import time
import struct
import random
import asyncio
import argparse
import subprocess
from typing import Optional, Tuple, List, Callable

try:
    from PIL import Image, ImageOps, ImageEnhance, ImageDraw, ImageFont, ImageChops
except ImportError:
    print("📦 First-run setup: Installing required Python packages (pillow, bleak)...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "pillow", "bleak", "qrcode"])
        from PIL import Image, ImageOps, ImageEnhance, ImageDraw, ImageFont, ImageChops
    except Exception:
        print("❌ Missing Python dependency 'Pillow'. Please run: pip install bleak pillow qrcode")
        sys.exit(1)

# BLE GATT Service and Characteristic UUIDs
SERVICE_UUID = "70954782-2d83-473d-9e5f-81e1d02d5273"
WRITE_CHAR_UUID = "70954783-2d83-473d-9e5f-81e1d02d5273"
NOTIFY_CHAR_UUID = "70954784-2d83-473d-9e5f-81e1d02d5273"

DEFAULT_DEVICE_NAME = "INSTAX-"

# SIDs
SID_VERSION_INFO = (0x00, 0x00)
SID_DEVICE_INFO = (0x00, 0x01)
SID_SUPPORT_INFO = (0x00, 0x02)
SID_SHUTDOWN = (0x01, 0x00)
SID_RESET = (0x01, 0x01)
SID_PRINT_START = (0x10, 0x00)
SID_PRINT_DATA = (0x10, 0x01)
SID_PRINT_END = (0x10, 0x02)
SID_PRINT_CANCEL = (0x10, 0x03)
SID_PRINT_EXEC = (0x10, 0x80)
SID_REJECT_COVER = (0x10, 0x81)
SID_LED_PATTERN = (0x30, 0x01)

SID_NAMES = {
    (0x00, 0x00): "SupportFunctionAndVersionInfo",
    (0x00, 0x01): "DeviceInfoService",
    (0x00, 0x02): "SupportFunctionInfo",
    (0x01, 0x01): "Reset",
    (0x10, 0x00): "PrintImageDownloadStart",
    (0x10, 0x01): "PrintImageDownloadData",
    (0x10, 0x02): "PrintImageDownloadEnd",
    (0x10, 0x03): "PrintImageDownloadCancel",
    (0x10, 0x80): "PrintImage",
    (0x10, 0x81): "RejectFilmCover",
    (0x30, 0x01): "LedPatternSettings",
}


def parse_hex_color(hex_str: str) -> Tuple[int, int, int]:
    s = (hex_str or "#FFFFFF").strip().lstrip("#")
    if len(s) == 6:
        try:
            return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
        except ValueError:
            pass
    return (255, 255, 255)


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
        payload = data[7:length - 1] if length > 8 else b""
        return {"sid": sid, "res_code": res_code, "payload": payload, "raw": data[:length]}


class InstaxPrinterStatus:
    def __init__(self):
        self.device_name = ""
        self.width = 800
        self.height = 800
        self.chunk_size = 1808
        self.max_jpeg_size = 60 * 1024
        self.battery_level = 0
        self.battery_percent = 0
        self.is_charging = False
        self.film_remaining = 0
        self.is_cover_open = False
        self.is_busy = False
        self.has_error = False
        self.total_prints = 0
        self.supports_3d_lut = False
        self.wait_seconds = 15
        self.model_number = ""


class InstaxBLE:
    def __init__(self, log_callback: Optional[Callable[[str], None]] = None):
        self.client = None
        self.log_callback = log_callback
        self.rx_buffer = bytearray()
        self.response_future: Optional[asyncio.Future] = None
        self.pending_sid: Optional[Tuple[int, int]] = None
        self.connected_name: str = ""

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
            rssi = getattr(d, "rssi", None)
            uuids = []
            if hasattr(d, "metadata") and isinstance(d.metadata, dict):
                uuids = [str(u).lower() for u in (d.metadata.get("uuids") or [])]
            if name.upper().startswith("INSTAX") or SERVICE_UUID.lower() in uuids:
                instax_devs.append({
                    "name": name or "INSTAX Printer",
                    "address": d.address,
                    "rssi": rssi if rssi is not None else -70,
                    "device": d,
                })
        instax_devs.sort(key=lambda x: x["rssi"], reverse=True)
        return instax_devs

    async def connect(self, target: str = DEFAULT_DEVICE_NAME, timeout: float = 8.0):
        from bleak import BleakClient
        target_clean = (target or DEFAULT_DEVICE_NAME).strip()
        target_upper = target_clean.upper()
        self.log(f"Searching for Instax printer matching '{target_clean}'...")

        instax_devs = await self.scan(timeout=timeout)
        matched = None
        for item in instax_devs:
            name_u = item["name"].upper()
            addr_u = item["address"].upper()
            if (
                target_upper in ("", "AUTO", "INSTAX", "INSTAX-")
                or name_u.startswith(target_upper)
                or target_upper in name_u
                or addr_u == target_upper
            ):
                matched = item["device"]
                self.connected_name = item["name"]
                break

        if not matched and instax_devs:
            matched = instax_devs[0]["device"]
            self.connected_name = instax_devs[0]["name"]

        if not matched:
            raise ConnectionError(
                f"Could not find Instax printer matching '{target_clean}'. "
                "Make sure your printer is powered ON and Bluetooth is turned OFF on your phone/tablet."
            )

        self.log(f"Connecting to {self.connected_name} ({matched.address})...")
        self.client = BleakClient(matched)
        await self.client.connect()
        self.log("Connected! Enabling GATT notifications...")
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
                if self.response_future and not self.response_future.done():
                    if self.pending_sid is None or parsed["sid"] == self.pending_sid:
                        self.response_future.set_result(parsed)

    async def send_command(self, sid: Tuple[int, int], payload: bytes = b"", timeout: float = 12.0) -> dict:
        if not self.client or not self.client.is_connected:
            raise ConnectionError("Printer is not connected.")

        packet = InstaxPacket.build(sid, payload)
        loop = asyncio.get_running_loop()
        self.pending_sid = sid
        self.response_future = loop.create_future()

        mtu = max(20, self.client.mtu_size - 3) if hasattr(self.client, "mtu_size") and self.client.mtu_size else 182
        for offset in range(0, len(packet), mtu):
            chunk = packet[offset:offset + mtu]
            await self.client.write_gatt_char(WRITE_CHAR_UUID, chunk, response=False)
            await asyncio.sleep(0.006)

        return await asyncio.wait_for(self.response_future, timeout=timeout)

    async def fetch_status(self) -> InstaxPrinterStatus:
        st = InstaxPrinterStatus()
        st.device_name = self.connected_name or DEFAULT_DEVICE_NAME

        try:
            r = await self.send_command(SID_DEVICE_INFO, b"\x01", timeout=4.0)
            if r["res_code"] == 0 and len(r["payload"]) > 1:
                st.model_number = r["payload"][1:].decode("ascii", errors="ignore").strip()
        except Exception:
            pass

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

        r = await self.send_command(SID_SUPPORT_INFO, b"\x01", timeout=5.0)
        p = r["payload"]
        if r["res_code"] == 0 and len(p) >= 2:
            st.battery_level = min(4, p[1] & 0x07)
            st.is_charging = ((p[1] >> 3) & 0x01) == 1
            if len(p) >= 3:
                pct = p[2]
                st.battery_percent = 100 if pct > 94 else pct

        r = await self.send_command(SID_SUPPORT_INFO, b"\x02", timeout=5.0)
        p = r["payload"]
        if r["res_code"] == 0 and len(p) >= 2:
            st.film_remaining = p[1] & 0x0F
            if len(p) >= 3:
                st.is_cover_open = (p[2] & 0x01) == 1
                st.is_busy = ((p[2] >> 1) & 0x01) == 1
                st.has_error = ((p[2] >> 2) & 0x01) == 1
            if len(p) >= 5:
                st.wait_seconds = p[4] + 3

        try:
            r = await self.send_command(SID_SUPPORT_INFO, b"\x03", timeout=4.0)
            p = r["payload"]
            if r["res_code"] == 0 and len(p) >= 5:
                st.total_prints = (p[1] << 24) | (p[2] << 16) | (p[3] << 8) | p[4]
        except Exception:
            pass

        self.log(
            f"[STATUS] {st.device_name} ({st.model_number or 'Instax Link'}): "
            f"Battery={st.battery_percent}% (Lvl {st.battery_level}/4), "
            f"Film={st.film_remaining}/10, Res={st.width}x{st.height}"
        )
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

    async def eject_film_cover(self):
        r = await self.send_command(SID_REJECT_COVER, b"", timeout=15.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"REJECT_FILM_COVER failed: code 0x{r['res_code']:02X}")
        await asyncio.sleep(8.0)

    async def print_jpeg(
        self,
        jpeg_data: bytes,
        mode: str = "rich",
        dry_run: bool = False,
        progress_cb: Optional[Callable[[str, float], None]] = None
    ) -> InstaxPrinterStatus:
        if progress_cb:
            progress_cb("Checking printer status...", 0.04)
        st = await self.fetch_status()

        if st.is_cover_open:
            raise RuntimeError("Printer film cover is open. Please close the back compartment.")
        if not dry_run and st.film_remaining <= 0:
            raise RuntimeError("No film remaining (0/10) in printer cartridge.")
        if st.battery_percent < 6 and st.battery_level == 0 and not st.is_charging:
            raise RuntimeError(f"Battery is too low ({st.battery_percent}%) to print.")

        total_bytes = len(jpeg_data)
        opt_byte = 0x08 if (mode == "natural" and st.supports_3d_lut) else 0x00
        frame_sz = st.chunk_size if st.chunk_size > 0 else 1808

        if progress_cb:
            progress_cb(f"Starting image download ({total_bytes // 1024} KB)...", 0.08)

        start_payload = struct.pack(">BBBB I", 0x02, opt_byte, 0x00, 0x00, total_bytes)
        r = await self.send_command(SID_PRINT_START, start_payload, timeout=12.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_IMAGE_DOWNLOAD_START rejected: code 0x{r['res_code']:02X}")

        # Read printer's negotiated packet length from response payload[0:4] if present
        if len(r["payload"]) >= 4:
            reported = struct.unpack(">I", r["payload"][:4])[0]
            if 128 <= reported <= 4096:
                frame_sz = reported

        tot_frames = (total_bytes + frame_sz - 1) // frame_sz
        try:
            for seq in range(tot_frames):
                start_idx = seq * frame_sz
                end_idx = min(start_idx + frame_sz, total_bytes)
                chunk = bytearray(jpeg_data[start_idx:end_idx])
                if len(chunk) < frame_sz:
                    chunk.extend(b"\x00" * (frame_sz - len(chunk)))

                payload = struct.pack(">I", seq) + bytes(chunk)
                pct = 0.10 + ((seq + 1) / tot_frames) * 0.75
                if progress_cb:
                    tag = "[Dry Run] " if dry_run else ""
                    progress_cb(f"{tag}Uploading packet {seq + 1}/{tot_frames}...", pct)
                res = await self.send_command(SID_PRINT_DATA, payload, timeout=15.0)
                if res["res_code"] != 0:
                    raise RuntimeError(f"Packet {seq + 1}/{tot_frames} rejected: code 0x{res['res_code']:02X}")
        except Exception as e:
            try:
                await self.send_command(SID_PRINT_CANCEL, b"", timeout=3.0)
            except Exception:
                pass
            raise e

        if progress_cb:
            progress_cb("Finalizing image transfer...", 0.88)
        r = await self.send_command(SID_PRINT_END, b"", timeout=10.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_IMAGE_DOWNLOAD_END rejected: code 0x{r['res_code']:02X}")

        await asyncio.sleep(0.3)

        if dry_run:
            self.log(f"[DRY-RUN] ✅ All {tot_frames} packets verified by printer ASIC in RAM! Canceling before motor trigger (0 film used).")
            if progress_cb:
                progress_cb("Dry run verified! 100% data delivered (0 film used).", 1.0)
            try:
                await self.send_command(SID_PRINT_CANCEL, b"", timeout=4.0)
            except Exception:
                pass
            await asyncio.sleep(0.5)
            return await self.fetch_status()

        if progress_cb:
            progress_cb("Triggering physical exposure & film ejection...", 0.93)
        r = await self.send_command(SID_PRINT_EXEC, b"", timeout=15.0)
        if r["res_code"] != 0:
            raise RuntimeError(f"PRINT_IMAGE rejected: code 0x{r['res_code']:02X}")

        wait_s = st.wait_seconds
        if r["payload"] and r["payload"][0] > 0:
            wait_s = r["payload"][0] + 3

        if progress_cb:
            progress_cb(f"Ejecting film ({wait_s}s)...", 0.97)
        await asyncio.sleep(max(wait_s, 15))

        updated_st = await self.fetch_status()
        if progress_cb:
            progress_cb(f"Print complete! Remaining film: {updated_st.film_remaining}/10", 1.0)
        return updated_st

    async def disconnect(self):
        if self.client and self.client.is_connected:
            await self.client.disconnect()
        self.client = None


def _draw_qr_and_caption(canvas: Image.Image, qr_text: str = "", caption_text: str = ""):
    draw = ImageDraw.Draw(canvas)
    w, h = canvas.size

    if caption_text and caption_text.strip():
        txt = caption_text.strip()
        bar_h = max(28, int(h * 0.065))
        draw.rectangle([16, h - bar_h - 14, w - 16, h - 14], fill=(20, 20, 24))
        font = ImageFont.load_default()
        draw.text((w // 2 - len(txt) * 3, h - bar_h // 2 - 18), txt, fill=(255, 255, 255), font=font)

    if qr_text and qr_text.strip():
        payload = qr_text.strip()
        side = int(min(w, h) * 0.18)
        bx = w - side - 22
        by = h - side - 22
        draw.rectangle([bx - 8, by - 8, bx + side + 8, by + side + 8], fill=(255, 255, 255), outline=(40, 40, 40))
        cells = 21
        cw = max(2, side // cells)
        for r in range(cells):
            for c in range(cells):
                finder = (r < 7 and c < 7) or (r < 7 and c >= cells - 7) or (r >= cells - 7 and c < 7)
                on = False
                if finder:
                    on = (
                        r in (0, 6, cells - 7, cells - 1)
                        or c in (0, 6, cells - 7, cells - 1)
                        or (2 <= (r % (cells - 7)) <= 4 and 2 <= (c % (cells - 7)) <= 4)
                    )
                else:
                    ch = ord(payload[(r * cells + c) % len(payload)])
                    on = ((ch >> ((r + c) % 7)) & 1) == 1
                if on:
                    x0 = bx + c * cw
                    y0 = by + r * cw
                    draw.rectangle([x0, y0, x0 + cw - 1, y0 + cw - 1], fill=(0, 0, 0))


def _fit_single_pil(
    img: Image.Image,
    target_width: int,
    target_height: int,
    fit_mode: str = "crop",
    bg_color: Tuple[int, int, int] = (255, 255, 255),
    zoom: float = 1.0,
    pan_x: float = 0.0,
    pan_y: float = 0.0,
) -> Image.Image:
    if fit_mode == "stretch":
        return img.resize((target_width, target_height), Image.LANCZOS)
    canvas = Image.new("RGB", (target_width, target_height), bg_color)
    img_aspect = img.width / max(1, img.height)
    tgt_aspect = target_width / max(1, target_height)
    if fit_mode == "fit":
        if img_aspect > tgt_aspect:
            w = target_width
            h = int(w / img_aspect)
        else:
            h = target_height
            w = int(h * img_aspect)
    else:  # crop
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
    return canvas


def _compress_pil_to_jpeg(canvas: Image.Image, max_bytes: int = 60 * 1024) -> bytes:
    quality = 94
    data = b""
    while quality >= 15:
        buf = io.BytesIO()
        canvas.save(buf, format="JPEG", quality=quality, progressive=False)
        data = buf.getvalue()
        if len(data) <= max_bytes or quality <= 16:
            return data
        quality -= 4
    return data


def apply_analog_fx(
    canvas: Image.Image,
    photo_box: Optional[Tuple[int, int, int, int]] = None,
    warmth: float = 0.0,
    vignette: float = 0.0,
    light_leak: str = "none",
    leak_placement: str = "auto",
    leak_intensity: float = 0.70,
    film_grain: float = 0.0,
    analog_wear: float = 0.0,
    show_vintage_date: bool = False,
    vintage_date_text: str = "",
    vintage_date_color: str = "amber",
    vintage_date_placement: str = "bottomRight",
    seed: int = 12345
) -> Image.Image:
    """Apply Analog Creative FX (PolaroidEngine) to a PIL Image."""
    W, H = canvas.size
    if photo_box is None:
        px, py, pw, ph = 0, 0, W, H
    else:
        px, py, pw, ph = photo_box

    region = canvas.crop((px, py, px + pw, py + ph)).convert("RGB")

    # 1. Analog Warmth Dial
    if abs(warmth) >= 0.01:
        tint_rgb = (255, 175, 45) if warmth > 0 else (45, 135, 255)
        tint_layer = Image.new("RGB", (pw, ph), tint_rgb)
        alpha = min(0.45, abs(warmth) * 0.35)
        region = Image.blend(region, tint_layer, alpha)
        if warmth > 0.4:
            warm_mult = Image.new("RGB", (pw, ph), (255, 240, 210))
            region = ImageChops.multiply(region, warm_mult)

    # 2. Lens Vignette Falloff
    if vignette > 0.01:
        mw, mh = 128, 128
        mask = Image.new("L", (mw, mh))
        cx, cy = mw / 2.0, mh / 2.0
        max_r = math.hypot(mw, mh) / 2.0
        pix = mask.load()
        for my in range(mh):
            for mx in range(mw):
                dist = math.hypot(mx - cx, my - cy)
                norm = max(0.0, min(1.0, (dist - max_r * 0.32) / (max_r * 0.68)))
                pix[mx, my] = int(norm * vignette * 225)
        mask_full = mask.resize((pw, ph), Image.BILINEAR)
        black_layer = Image.new("RGB", (pw, ph), (0, 0, 0))
        region.paste(black_layer, (0, 0), mask_full)

    # 3. Analog Light Leaks
    if light_leak and light_leak != "none" and leak_intensity > 0.01:
        p = leak_placement or "auto"
        if p == "auto":
            placements = ["left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]
            if seed and seed != 12345:
                p = placements[abs(seed) % len(placements)]
            else:
                p = random.choice(placements)

        if light_leak == "sunburst":
            c1, c2, c3 = (255, 250, 215), (255, 175, 45), (240, 70, 38)
        elif light_leak == "sunset":
            c1, c2, c3 = (255, 115, 45), (255, 190, 75), (190, 38, 115)
        else:
            c1, c2, c3 = (255, 45, 15), (255, 140, 30), (205, 20, 90)

        scale_c = lambda col, factor: tuple(int(v * factor * leak_intensity) for v in col)
        c1_s = scale_c(c1, 1.0)
        c2_s = scale_c(c2, 0.75)
        c3_s = scale_c(c3, 0.35)

        gw, gh = 64, 64
        g_img = Image.new("RGB", (gw, gh), (0, 0, 0))
        g_pix = g_img.load()

        if p == "left":
            for x in range(gw):
                t = x / float(gw * 0.45) if x < gw * 0.45 else 1.0
                if t < 0.35:
                    f = t / 0.35
                    col = tuple(int(c1_s[i] * (1.0 - f) + c2_s[i] * f) for i in range(3))
                elif t < 0.70:
                    f = (t - 0.35) / 0.35
                    col = tuple(int(c2_s[i] * (1.0 - f) + c3_s[i] * f) for i in range(3))
                elif t < 1.0:
                    f = (t - 0.70) / 0.30
                    col = tuple(int(c3_s[i] * (1.0 - f)) for i in range(3))
                else:
                    col = (0, 0, 0)
                for y in range(gh):
                    g_pix[x, y] = col
        elif p == "right":
            for x in range(gw):
                inv_x = gw - 1 - x
                t = inv_x / float(gw * 0.45) if inv_x < gw * 0.45 else 1.0
                if t < 0.35:
                    f = t / 0.35
                    col = tuple(int(c1_s[i] * (1.0 - f) + c2_s[i] * f) for i in range(3))
                elif t < 0.70:
                    f = (t - 0.35) / 0.35
                    col = tuple(int(c2_s[i] * (1.0 - f) + c3_s[i] * f) for i in range(3))
                elif t < 1.0:
                    f = (t - 0.70) / 0.30
                    col = tuple(int(c3_s[i] * (1.0 - f)) for i in range(3))
                else:
                    col = (0, 0, 0)
                for y in range(gh):
                    g_pix[x, y] = col
        else:
            cx = gw if "Right" in p else 0
            cy = gh if "bottom" in p.lower() else 0
            max_d = math.hypot(gw, gh) * 0.85
            for y in range(gh):
                for x in range(gw):
                    d = math.hypot(x - cx, y - cy) / max_d
                    if d < 0.35:
                        f = d / 0.35
                        col = tuple(int(c1_s[i] * (1.0 - f) + c2_s[i] * f) for i in range(3))
                    elif d < 0.70:
                        f = (d - 0.35) / 0.35
                        col = tuple(int(c2_s[i] * (1.0 - f) + c3_s[i] * f) for i in range(3))
                    elif d < 1.0:
                        f = (d - 0.70) / 0.30
                        col = tuple(int(c3_s[i] * (1.0 - f)) for i in range(3))
                    else:
                        col = (0, 0, 0)
                    g_pix[x, y] = col

        leak_layer = g_img.resize((pw, ph), Image.BILINEAR)

        if light_leak == "rainbow":
            r_draw = ImageDraw.Draw(leak_layer)
            rainbow = [(255, 64, 64), (255, 153, 38), (255, 230, 51), (64, 217, 115), (51, 153, 242), (166, 77, 217)]
            stripe_w = pw * 0.08
            for i, col in enumerate(rainbow):
                rx = pw - (6 - i) * stripe_w
                col_scaled = tuple(int(v * 0.65 * leak_intensity) for v in col)
                r_draw.rectangle([rx, 0, rx + stripe_w * 1.4, ph], fill=col_scaled)

        region = ImageChops.screen(region, leak_layer)

    # 4. Tactile Film Grain
    if film_grain > 0.01:
        gw, gh = min(256, max(64, pw // 2)), min(256, max(64, ph // 2))
        rng = random.Random(seed)
        noise_bytes = bytearray(rng.getrandbits(8) for _ in range(gw * gh))
        noise_img = Image.frombytes("L", (gw, gh), bytes(noise_bytes)).resize((pw, ph), Image.NEAREST).convert("RGB")
        try:
            overlayed = ImageChops.overlay(region, noise_img)
            region = Image.blend(region, overlayed, min(0.65, film_grain * 0.75))
        except Exception:
            region = Image.blend(region, noise_img, min(0.20, film_grain * 0.20))

    # 5. Analog Wear, Scratches & Dust
    if analog_wear > 0.01:
        rng = random.Random(seed + 101)
        wear_draw = ImageDraw.Draw(region)
        dust_count = 10 + int(analog_wear * 32)
        for _ in range(dust_count):
            rx = rng.uniform(0, pw)
            ry = rng.uniform(0, ph)
            is_white = (rng.random() < 0.33)
            col = (245, 245, 247) if is_white else (38, 30, 25)
            wtype = rng.randint(0, 2)
            if wtype == 0:
                length = rng.uniform(5.0, 18.0)
                angle = rng.uniform(0, math.pi * 2)
                wear_draw.line([(rx, ry), (rx + math.cos(angle) * length, ry + math.sin(angle) * length)], fill=col, width=1)
            elif wtype == 1:
                length = rng.uniform(8.0, 26.0)
                angle = rng.uniform(0, math.pi)
                wear_draw.line([(rx, ry), (rx + math.cos(angle) * length, ry + math.sin(angle) * length)], fill=col, width=1)
            else:
                r = rng.uniform(0.8, 2.0)
                wear_draw.ellipse([(rx - r, ry - r), (rx + r, ry + r)], fill=col)

        if analog_wear > 0.12:
            pod_bottom = (rng.randint(0, 1) == 0)
            mark_h = int(ph * (0.08 + analog_wear * 0.12))
            mark_img = Image.new("RGB", (pw, mark_h), (0, 0, 0))
            m_pix = mark_img.load()
            for y in range(mark_h):
                f = (mark_h - y) / float(mark_h) if pod_bottom else y / float(mark_h)
                c_val = int(f * 85 * analog_wear)
                c_amber = (c_val, int(c_val * 0.7), int(c_val * 0.35))
                for x in range(pw):
                    m_pix[x, y] = c_amber
            dest_y = ph - mark_h if pod_bottom else 0
            sub = region.crop((0, dest_y, pw, dest_y + mark_h))
            screened = ImageChops.screen(sub, mark_img)
            region.paste(screened, (0, dest_y))

    # 6. Vintage Glowing LED Date Stamp
    if show_vintage_date:
        stamp = (vintage_date_text or "").strip()
        if not stamp:
            stamp = time.strftime("'%y %m %d")

        col_map = {
            "red": ((255, 37, 37), (255, 90, 90)),
            "green": ((0, 230, 118), (80, 255, 160)),
            "white": ((245, 245, 247), (255, 255, 255)),
            "amber": ((255, 140, 0), (255, 185, 60))
        }
        primary_col, glow_col = col_map.get(vintage_date_color, col_map["amber"])

        font_size = max(14, int(pw * 0.042))
        try:
            font = ImageFont.load_default()
        except Exception:
            font = None

        date_draw = ImageDraw.Draw(region)
        pad_x = int(pw * 0.04)
        pad_y = int(ph * 0.04)
        try:
            bbox = date_draw.textbbox((0, 0), stamp, font=font)
            text_w = bbox[2] - bbox[0]
            text_h = bbox[3] - bbox[1]
        except Exception:
            text_w = len(stamp) * (font_size * 0.6)
            text_h = font_size

        if vintage_date_placement == "bottomLeft":
            sx, sy = pad_x, ph - pad_y - text_h
        elif vintage_date_placement == "topRight":
            sx, sy = pw - pad_x - text_w, pad_y
        elif vintage_date_placement == "topLeft":
            sx, sy = pad_x, pad_y
        else:
            sx, sy = pw - pad_x - text_w, ph - pad_y - text_h

        for ox in [-2, -1, 0, 1, 2]:
            for oy in [-2, -1, 0, 1, 2]:
                if ox != 0 or oy != 0:
                    date_draw.text((sx + ox, sy + oy), stamp, fill=glow_col, font=font)
        date_draw.text((sx, sy), stamp, fill=primary_col, font=font)

    canvas.paste(region, (px, py))
    return canvas


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
    qr_text: str = "",
    caption_text: str = "",
    max_bytes: int = 60 * 1024,
    warmth: float = 0.0,
    vignette: float = 0.0,
    light_leak: str = "none",
    leak_placement: str = "auto",
    leak_intensity: float = 0.70,
    film_grain: float = 0.0,
    analog_wear: float = 0.0,
    show_vintage_date: bool = False,
    vintage_date_text: str = "",
    vintage_date_color: str = "amber",
    vintage_date_placement: str = "bottomRight",
) -> bytes:
    with Image.open(src_path) as raw:
        img = ImageOps.exif_transpose(raw).convert("RGB")

    if rotation != 0:
        img = img.rotate(-rotation, expand=True, resample=Image.BICUBIC)

    canvas = _fit_single_pil(img, target_width, target_height, fit_mode, bg_color, zoom, pan_x, pan_y)
    canvas = apply_analog_fx(
        canvas,
        warmth=warmth,
        vignette=vignette,
        light_leak=light_leak,
        leak_placement=leak_placement,
        leak_intensity=leak_intensity,
        film_grain=film_grain,
        analog_wear=analog_wear,
        show_vintage_date=show_vintage_date,
        vintage_date_text=vintage_date_text,
        vintage_date_color=vintage_date_color,
        vintage_date_placement=vintage_date_placement,
    )
    _draw_qr_and_caption(canvas, qr_text=qr_text, caption_text=caption_text)
    return _compress_pil_to_jpeg(canvas, max_bytes=max_bytes)


def render_collage(
    src_paths: List[str],
    layout: str = "split2V",
    spacing: int = 16,
    target_width: int = 800,
    target_height: int = 800,
    fit_mode: str = "crop",
    bg_color: Tuple[int, int, int] = (255, 255, 255),
    qr_text: str = "",
    caption_text: str = "",
    max_bytes: int = 60 * 1024,
    warmth: float = 0.0,
    vignette: float = 0.0,
    light_leak: str = "none",
    leak_placement: str = "auto",
    leak_intensity: float = 0.70,
    film_grain: float = 0.0,
    analog_wear: float = 0.0,
    show_vintage_date: bool = False,
    vintage_date_text: str = "",
    vintage_date_color: str = "amber",
    vintage_date_placement: str = "bottomRight",
) -> bytes:
    canvas = Image.new("RGB", (target_width, target_height), bg_color)
    W, H = float(target_width), float(target_height)
    m = float(max(0, spacing))
    s = float(max(0, spacing))

    slots = []
    if layout == "split2V":
        cw = (W - 2 * m - s) / 2
        ch = H - 2 * m
        slots = [(m, m, cw, ch), (m + cw + s, m, cw, ch)]
    elif layout == "split2H":
        cw = W - 2 * m
        ch = (H - 2 * m - s) / 2
        slots = [(m, m, cw, ch), (m, m + ch + s, cw, ch)]
    elif layout == "split3Hero":
        cw = (W - 2 * m - s) / 2
        ch = (H - 2 * m - s) / 2
        slots = [(m, m, cw, H - 2 * m), (m + cw + s, m, cw, ch), (m + cw + s, m + ch + s, cw, ch)]
    elif layout == "split3V":
        cw = (W - 2 * m - 2 * s) / 3
        ch = H - 2 * m
        slots = [(m + i * (cw + s), m, cw, ch) for i in range(3)]
    elif layout == "strips4V":
        cw = (W - 2 * m - 3 * s) / 4
        ch = H - 2 * m
        slots = [(m + i * (cw + s), m, cw, ch) for i in range(4)]
    elif layout == "grid6":
        cw = (W - 2 * m - 2 * s) / 3
        ch = (H - 2 * m - s) / 2
        for r in range(2):
            for c in range(3):
                slots.append((m + c * (cw + s), m + r * (ch + s), cw, ch))
    elif layout == "grid9":
        cw = (W - 2 * m - 2 * s) / 3
        ch = (H - 2 * m - 2 * s) / 3
        for r in range(3):
            for c in range(3):
                slots.append((m + c * (cw + s), m + r * (ch + s), cw, ch))
    else:  # grid4 default
        cw = (W - 2 * m - s) / 2
        ch = (H - 2 * m - s) / 2
        for r in range(2):
            for c in range(2):
                slots.append((m + c * (cw + s), m + r * (ch + s), cw, ch))

    imgs = []
    for p in src_paths:
        with Image.open(p) as raw:
            imgs.append(ImageOps.exif_transpose(raw).convert("RGB"))

    for idx, (sx, sy, sw, sh) in enumerate(slots):
        iw = max(4, int(round(sw)))
        ih = max(4, int(round(sh)))
        tile = _fit_single_pil(imgs[idx % len(imgs)], iw, ih, fit_mode, bg_color)
        canvas.paste(tile, (int(round(sx)), int(round(sy))))

    canvas = apply_analog_fx(
        canvas,
        warmth=warmth,
        vignette=vignette,
        light_leak=light_leak,
        leak_placement=leak_placement,
        leak_intensity=leak_intensity,
        film_grain=film_grain,
        analog_wear=analog_wear,
        show_vintage_date=show_vintage_date,
        vintage_date_text=vintage_date_text,
        vintage_date_color=vintage_date_color,
        vintage_date_placement=vintage_date_placement,
    )

    _draw_qr_and_caption(canvas, qr_text=qr_text, caption_text=caption_text)
    return _compress_pil_to_jpeg(canvas, max_bytes=max_bytes)


async def main_cli():
    if "--serve" in sys.argv or (len(sys.argv) > 1 and sys.argv[1] == "serve"):
        bridge_script = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "Web-Bluetooth-Offline", "instax_wifi_bridge.py")
        )
        if os.path.isfile(bridge_script):
            extra_args = [a for a in sys.argv[1:] if a not in ("--serve", "serve")]
            os.execv(sys.executable, [sys.executable, bridge_script] + extra_args)

    parser = argparse.ArgumentParser(description="Instax Cross-Platform Bluetooth Printer CLI (macOS, Windows, Linux)")
    parser.add_argument("--serve", action="store_true", help="Start Local Wi-Fi Bluetooth Bridge for iPhone/iPad Safari")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # serve
    p_serve = subparsers.add_parser("serve", help="Start Local Wi-Fi Bluetooth Bridge for iPhone/iPad/Mac Safari")
    p_serve.add_argument("--port", type=int, default=8765)

    # scan
    p_scan = subparsers.add_parser("scan", help="Scan for nearby Instax printers")
    p_scan.add_argument("--timeout", "-t", type=float, default=4.0)

    # status
    p_status = subparsers.add_parser("status", help="Query printer hardware status")
    p_status.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)

    # led
    p_led = subparsers.add_parser("led", help="Control LED pattern")
    p_led.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)
    p_led.add_argument("--off", action="store_true", help="Stop LED pattern")

    # eject-cover
    p_eject = subparsers.add_parser("eject-cover", help="Eject protective dark slide")
    p_eject.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)

    # preview
    p_prev = subparsers.add_parser("preview", help="Render preview JPEG locally without printer")
    p_prev.add_argument("images", nargs="+")
    p_prev.add_argument("-o", "--output", default="instax_preview.jpg")
    p_prev.add_argument("--model", default="square")
    p_prev.add_argument("--mode", default="rich")
    p_prev.add_argument("--fit", default="crop")
    p_prev.add_argument("--bg", default="#FFFFFF")
    p_prev.add_argument("--collage", default=None)
    p_prev.add_argument("--collage-spacing", type=int, default=16)
    p_prev.add_argument("--qr", default="")
    p_prev.add_argument("--caption", default="")

    # print
    p_print = subparsers.add_parser("print", help="Print one or more images (or collage)")
    p_print.add_argument("images", nargs="+")
    p_print.add_argument("--device", "-d", default=DEFAULT_DEVICE_NAME)
    p_print.add_argument("--model", default="auto")
    p_print.add_argument("--mode", choices=["rich", "natural"], default="rich")
    p_print.add_argument("--fit", choices=["crop", "fit", "stretch"], default="crop")
    p_print.add_argument("--bg", default="#FFFFFF")
    p_print.add_argument("--dry-run", action="store_true", help="Verify full transfer with 0 film used")
    p_print.add_argument("--collage", default=None)
    p_print.add_argument("--collage-spacing", type=int, default=16)
    p_print.add_argument("--qr", default="")
    p_print.add_argument("--caption", default="")
    p_print.add_argument("--width", type=int, default=0)
    p_print.add_argument("--height", type=int, default=0)

    for p in (p_prev, p_print):
        p.add_argument("--warmth", type=float, default=0.0, help="Analog warmth (-1.0 to 1.0)")
        p.add_argument("--vignette", type=float, default=0.0, help="Lens vignette falloff (0.0 to 1.0)")
        p.add_argument("--light-leak", choices=["none", "burn", "sunburst", "sunset", "rainbow"], default="none", help="Light leak type")
        p.add_argument("--leak-placement", choices=["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"], default="auto")
        p.add_argument("--leak-intensity", type=float, default=0.70, help="Light leak intensity (0.0 to 1.0)")
        p.add_argument("--grain", type=float, default=0.0, help="Silver halide film grain (0.0 to 1.0)")
        p.add_argument("--wear", type=float, default=0.0, help="Analog wear, dust & scratches (0.0 to 1.0)")
        p.add_argument("--date", default="", help="Vintage LED date stamp text, e.g. \"'98 10 24\"")
        p.add_argument("--date-color", choices=["amber", "red", "green", "white"], default="amber")
        p.add_argument("--date-placement", choices=["bottomRight", "bottomLeft", "topRight", "topLeft"], default="bottomRight")

    args = parser.parse_args()

    analog_kwargs = {
        "warmth": getattr(args, "warmth", 0.0),
        "vignette": getattr(args, "vignette", 0.0),
        "light_leak": getattr(args, "light_leak", "none"),
        "leak_placement": getattr(args, "leak_placement", "auto"),
        "leak_intensity": getattr(args, "leak_intensity", 0.70),
        "film_grain": getattr(args, "grain", 0.0),
        "analog_wear": getattr(args, "wear", 0.0),
        "show_vintage_date": bool(getattr(args, "date", "").strip()),
        "vintage_date_text": getattr(args, "date", ""),
        "vintage_date_color": getattr(args, "date_color", "amber"),
        "vintage_date_placement": getattr(args, "date_placement", "bottomRight"),
    }

    if args.command == "preview":
        m = (args.model or "square").lower()
        if m == "wide":
            w, h, max_b = 1260, 840, 200 * 1024
        elif m == "mini":
            w, h, max_b = 600, 800, 54 * 1024
        else:
            w, h, max_b = 800, 800, 60 * 1024
        bg = parse_hex_color(args.bg)
        if args.collage and args.collage != "single":
            data = render_collage(
                args.images, layout=args.collage, spacing=args.collage_spacing,
                target_width=w, target_height=h, fit_mode=args.fit, bg_color=bg,
                qr_text=args.qr, caption_text=args.caption, max_bytes=max_b,
                **analog_kwargs
            )
        else:
            data = render_image(
                args.images[0], target_width=w, target_height=h,
                fit_mode=args.fit, bg_color=bg, qr_text=args.qr,
                caption_text=args.caption, max_bytes=max_b,
                **analog_kwargs
            )
        with open(args.output, "wb") as f:
            f.write(data)
        print(f"Saved {w}x{h} preview ({len(data) / 1024:.1f} KB) to: {args.output}")
        return

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
            print(f"\nPrinter Status: {st.device_name}")
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
                await ble.stop_led()
            else:
                await ble.flash_rainbow_led()
            await ble.disconnect()

        elif args.command == "eject-cover":
            await ble.connect(args.device)
            await ble.eject_film_cover()
            await ble.disconnect()

        elif args.command == "print":
            await ble.connect(args.device)
            st = await ble.fetch_status()
            m = (args.model or "auto").lower()
            if m == "wide":
                w, h, max_b = 1260, 840, 200 * 1024
            elif m == "mini":
                w, h, max_b = 600, 800, 54 * 1024
            elif m == "square":
                w, h, max_b = 800, 800, 60 * 1024
            else:
                w = st.width if st.width > 0 else (args.width or 800)
                h = st.height if st.height > 0 else (args.height or 800)
                max_b = st.max_jpeg_size if st.max_jpeg_size > 0 else 60 * 1024

            bg = parse_hex_color(args.bg)

            if args.collage and args.collage != "single":
                jpeg = render_collage(
                    args.images, layout=args.collage, spacing=args.collage_spacing,
                    target_width=w, target_height=h, fit_mode=args.fit, bg_color=bg,
                    qr_text=args.qr, caption_text=args.caption, max_bytes=max_b,
                    **analog_kwargs
                )
                jobs = [("Collage", jpeg)]
            else:
                jobs = []
                for p in args.images:
                    jpeg = render_image(
                        p, target_width=w, target_height=h, fit_mode=args.fit,
                        bg_color=bg, qr_text=args.qr, caption_text=args.caption, max_bytes=max_b,
                        **analog_kwargs
                    )
                    jobs.append((p, jpeg))

            for idx, (label, jpeg) in enumerate(jobs):
                print(f"\n[{idx + 1}/{len(jobs)}] {'[DRY RUN] ' if args.dry_run else ''}Sending {label} ({len(jpeg) / 1024:.1f} KB)...")
                res = await ble.print_jpeg(jpeg, mode=args.mode, dry_run=args.dry_run)
                print(f"  ✓ Complete! Film remaining: {res.film_remaining}/10")
                if idx + 1 < len(jobs):
                    await asyncio.sleep(3)

            await ble.disconnect()
            print("\n🎉 Done!")

    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main_cli())
