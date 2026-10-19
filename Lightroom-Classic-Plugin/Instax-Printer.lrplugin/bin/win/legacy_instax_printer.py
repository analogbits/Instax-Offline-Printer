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
import math
import os
import random
import socket
import struct
import sys
import threading
import time
from typing import Callable, Optional, Tuple

try:
    from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps
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


STICKER_MAP = {
    "party_popper": "🎉",
    "birthday_cake": "🎂",
    "sparkles": "✨",
    "cheers": "🥂",
    "balloon": "🎈",
    "gift": "🎁",
    "camera": "📸",
    "airplane": "✈️",
    "palm_tree": "🌴",
    "tent": "⛺️",
    "mountain": "⛰️",
    "sun": "☀️",
    "wave": "🌊",
    "heart": "❤️",
    "sparkle_heart": "💖",
    "two_hearts": "💕",
    "love_letter": "💌",
    "rose": "🌹",
    "bouquet": "💐",
    "paw": "🐾",
    "puppy": "🐶",
    "kitten": "🐱",
    "cherry_blossom": "🌸",
    "coffee": "☕️",
    "four_leaf_clover": "🍀",
    "cassette": "📼",
    "sunglasses": "🕶️",
    "peace": "✌️",
    "lightning": "⚡️",
    "music": "🎵",
    "fire": "🔥",
    # Hand-Drawn Love & Romance Doodles
    "love_script": "💖",
    "i_love_you": "❤️",
    "forever_heart": "♾️",
    "sketchy_heart": "✏️",
    "winged_heart": "🪽",
    "love_envelope": "💌",
    "shining_heart": "🌟",
    "heart_balloons": "🎈",
    "heart_arrow": "💘",
    "heart_hands": "🫶",
    "looping_heart": "➰",
    # Celebrations & Holidays Doodles
    "birthday_cake_doodle": "🎂",
    "birthday_bunting": "🚩",
    "happy_holidays_gold": "✨",
    "season_greetings": "🌿",
    "xmas_tree": "🎄",
    "holly_berries": "🍒",
    "christmas_stockings": "🧦",
    "halloween_ghost": "👻",
    "jack_o_lantern": "🎃",
    "flying_bats": "🦇",
    "summer_flipflops": "🩴",
    "seashells": "🐚",
    "cherry_blossoms": "🌸",
    "mimosa": "🌾",
}


def draw_decorative_frame(canvas: Image.Image, style: str) -> Image.Image:
    if not style or style == "none":
        return canvas
    w, h = canvas.size
    draw = ImageDraw.Draw(canvas)

    if style == "classic_white":
        bx = int(w * 0.05)
        bt = int(h * 0.05)
        bb = int(h * 0.14)
        draw.rectangle([0, 0, w, bt], fill=(248, 250, 252))
        draw.rectangle([0, 0, bx, h], fill=(248, 250, 252))
        draw.rectangle([w - bx, 0, w, h], fill=(248, 250, 252))
        draw.rectangle([0, h - bb, w, h], fill=(248, 250, 252))
        draw.rectangle([bx, bt, w - bx, h - bb], outline=(200, 205, 215), width=1)
    elif style == "obsidian_black":
        bx = int(w * 0.05)
        bt = int(h * 0.05)
        bb = int(h * 0.14)
        draw.rectangle([0, 0, w, bt], fill=(17, 24, 39))
        draw.rectangle([0, 0, bx, h], fill=(17, 24, 39))
        draw.rectangle([w - bx, 0, w, h], fill=(17, 24, 39))
        draw.rectangle([0, h - bb, w, h], fill=(17, 24, 39))
        draw.rectangle([bx, bt, w - bx, h - bb], outline=(55, 65, 81), width=1)
    elif style == "rainbow_gradient":
        bw = int(min(w, h) * 0.065)
        colors = [
            (239, 68, 68),
            (249, 115, 22),
            (234, 179, 8),
            (34, 197, 94),
            (6, 182, 212),
            (139, 92, 246),
            (236, 72, 153),
        ]
        n = len(colors)
        step_x = w // n
        for idx, col in enumerate(colors):
            x0 = idx * step_x
            x1 = w if idx == n - 1 else (idx + 1) * step_x
            draw.rectangle([x0, 0, x1, bw], fill=col)
            draw.rectangle([x0, h - bw, x1, h], fill=col)
        step_y = h // n
        for idx, col in enumerate(colors):
            y0 = idx * step_y
            y1 = h if idx == n - 1 else (idx + 1) * step_y
            draw.rectangle([0, y0, bw, y1], fill=col)
            draw.rectangle([w - bw, y0, w, y1], fill=col)
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(255, 255, 255), width=1)
    elif style == "sunset_ombre":
        bw = int(min(w, h) * 0.065)
        top_col = (244, 63, 94)
        mid_col = (251, 146, 60)
        bot_col = (99, 102, 241)
        for y in range(h):
            t = y / max(1, h)
            if t < 0.5:
                sub_t = t / 0.5
                c = tuple(int(top_col[i] + sub_t * (mid_col[i] - top_col[i])) for i in range(3))
            else:
                sub_t = (t - 0.5) / 0.5
                c = tuple(int(mid_col[i] + sub_t * (bot_col[i] - mid_col[i])) for i in range(3))
            draw.line([(0, y), (bw, y)], fill=c)
            draw.line([(w - bw, y), (w, y)], fill=c)
        draw.rectangle([0, 0, w, bw], fill=top_col)
        draw.rectangle([0, h - bw, w, h], fill=bot_col)
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(255, 255, 255), width=1)
    elif style == "sprocket_35mm":
        bw = int(min(w, h) * 0.08)
        draw.rectangle([0, 0, bw, h], fill=(10, 10, 10))
        draw.rectangle([w - bw, 0, w, h], fill=(10, 10, 10))
        hole_w = int(bw * 0.45)
        hole_h = int(bw * 0.65)
        step = hole_h + int(bw * 0.4)
        y = int(bw * 0.3)
        while y + hole_h < h:
            x_l = (bw - hole_w) // 2
            draw.rectangle([x_l, y, x_l + hole_w, y + hole_h], fill=(229, 231, 235))
            x_r = w - bw + (bw - hole_w) // 2
            draw.rectangle([x_r, y, x_r + hole_w, y + hole_h], fill=(229, 231, 235))
            y += step
    elif style in ("gold_metallic", "metallic_gold"):
        bw = int(min(w, h) * 0.065)
        draw.rectangle([0, 0, w, bw], fill=(217, 119, 6))
        draw.rectangle([0, 0, bw, h], fill=(180, 83, 9))
        draw.rectangle([w - bw, 0, w, h], fill=(254, 240, 138))
        draw.rectangle([0, h - bw, w, h], fill=(146, 64, 14))
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(255, 255, 255), width=1)
    elif style == "rose_gold":
        bw = int(min(w, h) * 0.065)
        draw.rectangle([0, 0, w, bw], fill=(251, 113, 133))
        draw.rectangle([0, 0, bw, h], fill=(159, 18, 57))
        draw.rectangle([w - bw, 0, w, h], fill=(251, 207, 232))
        draw.rectangle([0, h - bw, w, h], fill=(136, 19, 55))
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(255, 255, 255), width=1)
    elif style in ("pastel_pop", "candy_pastel"):
        bw = int(min(w, h) * 0.065)
        draw.rectangle([0, 0, w, bw], fill=(186, 230, 253))
        draw.rectangle([0, 0, bw, h], fill=(251, 207, 232))
        draw.rectangle([w - bw, 0, w, h], fill=(187, 247, 208))
        draw.rectangle([0, h - bw, w, h], fill=(254, 240, 138))
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(255, 255, 255), width=1)
    elif style == "postage_stamp":
        bw = int(min(w, h) * 0.05)
        draw.rectangle([0, 0, w, bw], fill=(254, 254, 254))
        draw.rectangle([0, 0, bw, h], fill=(254, 254, 254))
        draw.rectangle([w - bw, 0, w, h], fill=(254, 254, 254))
        draw.rectangle([0, h - bw, w, h], fill=(254, 254, 254))
        r = int(bw * 0.45)
        d = int(r * 2.8)
        x = d // 2
        while x < w:
            draw.ellipse([x - r, -r, x + r, r], fill=(30, 30, 30))
            draw.ellipse([x - r, h - r, x + r, h + r], fill=(30, 30, 30))
            x += d
        y = d // 2
        while y < h:
            draw.ellipse([-r, y - r, r, y + r], fill=(30, 30, 30))
            draw.ellipse([w - r, y - r, w + r, y + r], fill=(30, 30, 30))
            y += d
    elif style == "baroque_filigree":
        bw = int(min(w, h) * 0.07)
        draw.rectangle([0, 0, w, bw], fill=(253, 242, 248))
        draw.rectangle([0, 0, bw, h], fill=(253, 242, 248))
        draw.rectangle([w - bw, 0, w, h], fill=(253, 242, 248))
        draw.rectangle([0, h - bw, w, h], fill=(253, 242, 248))
        draw.ellipse([bw, bw, w - bw, h - bw], outline=(190, 24, 93), width=2)
        # Corner flourishes
        for cx, cy in [(bw, bw), (w - bw, bw), (bw, h - bw), (w - bw, h - bw)]:
            draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], outline=(190, 24, 93), width=2)
    elif style == "wedding_corners":
        pad = int(min(w, h) * 0.05)
        fl_len = 50
        draw.line([(pad, pad), (pad + fl_len, pad)], fill=(74, 122, 95), width=2)
        draw.line([(pad, pad), (pad, pad + fl_len)], fill=(74, 122, 95), width=2)
        draw.line([(w - pad, pad), (w - pad - fl_len, pad)], fill=(74, 122, 95), width=2)
        draw.line([(w - pad, pad), (w - pad, pad + fl_len)], fill=(74, 122, 95), width=2)
        draw.line([(pad, h - pad), (pad + fl_len, h - pad)], fill=(74, 122, 95), width=2)
        draw.line([(pad, h - pad), (pad, pad - fl_len)], fill=(74, 122, 95), width=2) if False else None
        draw.line([(pad, h - pad), (pad, h - pad - fl_len)], fill=(74, 122, 95), width=2)
        draw.line([(w - pad, h - pad), (w - pad - fl_len, h - pad)], fill=(74, 122, 95), width=2)
        draw.line([(w - pad, h - pad), (w - pad, h - pad - fl_len)], fill=(74, 122, 95), width=2)
        for cx, cy in [(pad, pad), (w - pad, pad), (pad, h - pad), (w - pad, h - pad)]:
            draw.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(251, 113, 133))
            draw.ellipse([cx + 6, cy - 4, cx + 12, cy + 2], fill=(134, 239, 172))
    elif style == "stained_glass":
        bw = int(min(w, h) * 0.065)
        seg_w = int(min(w, h) * 0.08)
        gem_colors = [(239, 68, 68), (59, 130, 246), (234, 179, 8), (34, 197, 94), (168, 85, 247)]
        c_idx = 0
        x = 0
        while x < w:
            draw.rectangle([x, 0, x + seg_w, bw], fill=gem_colors[c_idx % len(gem_colors)])
            c_idx += 1
            draw.rectangle([x, h - bw, x + seg_w, h], fill=gem_colors[c_idx % len(gem_colors)])
            c_idx += 1
            x += seg_w
        y = bw
        while y < h - bw:
            draw.rectangle([0, y, bw, y + seg_w], fill=gem_colors[c_idx % len(gem_colors)])
            c_idx += 1
            draw.rectangle([w - bw, y, w, y + seg_w], fill=gem_colors[c_idx % len(gem_colors)])
            c_idx += 1
            y += seg_w
        draw.rectangle([0, 0, w, h], outline=(24, 24, 27), width=3)
        draw.rectangle([bw, bw, w - bw, h - bw], outline=(24, 24, 27), width=3)
    elif style == "bokeh_sparkles":
        orbs = [
            (0.12, 0.08, 24, (254, 240, 138, 110)),
            (0.28, 0.05, 18, (251, 207, 232, 95)),
            (0.72, 0.07, 26, (221, 214, 254, 105)),
            (0.88, 0.12, 20, (254, 240, 138, 120)),
            (0.05, 0.35, 16, (251, 207, 232, 85)),
            (0.95, 0.42, 22, (254, 240, 138, 95)),
            (0.08, 0.82, 28, (221, 214, 254, 110)),
            (0.22, 0.94, 18, (254, 240, 138, 105)),
            (0.78, 0.92, 25, (251, 207, 232, 115)),
            (0.92, 0.85, 20, (254, 240, 138, 110)),
        ]
        ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        odraw = ImageDraw.Draw(ov)
        for ox, oy, r, col in orbs:
            odraw.ellipse([int(ox * w) - r, int(oy * h) - r, int(ox * w) + r, int(oy * h) + r], fill=col)
        # Sparkles
        for sx, sy in [(int(w * 0.18), int(h * 0.06)), (int(w * 0.82), int(h * 0.09)), (int(w * 0.07), int(h * 0.65)), (int(w * 0.93), int(h * 0.60)), (int(w * 0.50), int(h * 0.95))]:
            odraw.line([(sx - 7, sy), (sx + 7, sy)], fill=(255, 255, 255, 240), width=2)
            odraw.line([(sx, sy - 7), (sx, sy + 7)], fill=(255, 255, 255, 240), width=2)
        canvas_rgba = canvas.convert("RGBA")
        canvas_rgba.alpha_composite(ov)
        return canvas_rgba.convert("RGB")
    elif style == "fireworks_celebration":
        for cx, cy in [(60, 60), (w - 70, 70), (80, h - 80), (w - 65, h - 75)]:
            for i in range(12):
                import math
                ang = (i / 12) * math.pi * 2
                length = 35 + (i % 3) * 15
                ex = int(cx + math.cos(ang) * length)
                ey = int(cy + math.sin(ang) * length)
                col = [(251, 191, 36), (248, 113, 113), (96, 165, 250), (52, 211, 153)][i % 4]
                draw.line([(cx, cy), (ex, ey)], fill=col, width=2)
                draw.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=col)
            draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255))
    elif style == "twin_hearts_garland":
        gy = int(h * 0.04)
        draw.line([(20, gy), (w - 20, gy)], fill=(255, 255, 255), width=2)
        cols = [(244, 63, 94), (251, 113, 133), (253, 164, 175), (225, 29, 72)]
        for i in range(7):
            t = (i + 0.5) / 7.0
            hx = int(20 + t * (w - 40))
            hy = gy + 16 + (i % 2) * 10
            draw.line([(hx, gy), (hx, hy)], fill=(255, 255, 255), width=1)
            draw.ellipse([hx - 7, hy - 7, hx + 7, hy + 7], fill=cols[i % len(cols)])
    elif style == "holiday_garland":
        gy = int(h * 0.04)
        draw.line([(10, gy), (w - 10, gy)], fill=(21, 128, 61), width=10)
        bx = 30
        while bx < w - 20:
            draw.ellipse([bx - 4, gy - 4, bx + 4, gy + 4], fill=(220, 38, 38))
            draw.ellipse([bx + 4, gy - 1, bx + 10, gy + 5], fill=(220, 38, 38))
            bx += 50
        draw.ellipse([w // 2 - 7, gy - 7, w // 2 + 7, gy + 7], fill=(185, 28, 28))
    elif style == "botanical_foliage":
        cols = [(234, 88, 12), (202, 138, 4), (180, 83, 9), (185, 28, 28)]
        margin = int(min(w, h) * 0.04)
        lx = margin + 15
        i = 0
        while lx < w - margin:
            draw.ellipse([lx - 8, margin - 4, lx + 8, margin + 4], fill=cols[i % len(cols)])
            draw.ellipse([lx - 8, h - margin - 4, lx + 8, h - margin + 4], fill=cols[(i + 1) % len(cols)])
            lx += 32
            i += 1

    return canvas


def draw_sticker_overlay(
    canvas: Image.Image,
    sticker: str = "none",
    sticker_image: Optional[Image.Image] = None,
    position: str = "bottomRight",
    scale: float = 0.25,
    opacity: float = 1.0,
    rotation: float = 0.0,
    pos_x: float = 0.65,
    pos_y: float = 0.65,
) -> Image.Image:
    has_custom = sticker_image is not None
    has_emoji = sticker in STICKER_MAP
    if not has_custom and not has_emoji:
        return canvas

    w, h = canvas.size
    target_dim = max(16, int(min(w, h) * scale))
    margin = int(min(w, h) * 0.06)

    if position == "custom":
        cx = int(w / 2 + pos_x * (w / 2 - target_dim / 2))
        cy = int(h / 2 + pos_y * (h / 2 - target_dim / 2))
    elif position == "topLeft":
        cx = margin + target_dim // 2
        cy = margin + target_dim // 2
    elif position == "topRight":
        cx = w - margin - target_dim // 2
        cy = margin + target_dim // 2
    elif position == "bottomLeft":
        cx = margin + target_dim // 2
        cy = h - margin - target_dim // 2
    elif position == "bottomRight":
        cx = w - margin - target_dim // 2
        cy = h - margin - target_dim // 2
    elif position == "center":
        cx = w // 2
        cy = h // 2
    elif position == "topCenter":
        cx = w // 2
        cy = margin + target_dim // 2
    elif position == "bottomCenter":
        cx = w // 2
        cy = h - margin - target_dim // 2
    else:
        cx = w - margin - target_dim // 2
        cy = h - margin - target_dim // 2

    if has_custom:
        img_rgba = sticker_image.convert("RGBA")
        aspect = img_rgba.width / max(1, img_rgba.height)
        if aspect > 1.0:
            sw = target_dim
            sh = max(1, int(target_dim / aspect))
        else:
            sh = target_dim
            sw = max(1, int(target_dim * aspect))
        sticker_elem = img_rgba.resize((sw, sh), Image.LANCZOS)
    else:
        emoji_char = STICKER_MAP[sticker]
        sticker_elem = Image.new("RGBA", (target_dim, target_dim), (0, 0, 0, 0))
        d_elem = ImageDraw.Draw(sticker_elem)
        font = None
        for font_candidate in [
            "/System/Library/Fonts/Apple Color Emoji.ttc",
            "C:\\Windows\\Fonts\\seguiemj.ttf",
            "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf",
            "/Library/Fonts/Apple Color Emoji.ttc",
        ]:
            if os.path.isfile(font_candidate):
                try:
                    font = ImageFont.truetype(font_candidate, int(target_dim * 0.75))
                    break
                except Exception:
                    pass
        if font is None:
            font = ImageFont.load_default()
        d_elem.text((target_dim // 2, target_dim // 2), emoji_char, font=font, anchor="mm", fill=(255, 255, 255, 255))

    if opacity < 1.0:
        r, g, b, a = sticker_elem.split()
        a = a.point(lambda v: int(v * max(0.05, min(1.0, opacity))))
        sticker_elem = Image.merge("RGBA", (r, g, b, a))

    if rotation != 0.0:
        sticker_elem = sticker_elem.rotate(-rotation, expand=True, resample=Image.BICUBIC)

    paste_x = cx - sticker_elem.width // 2
    paste_y = cy - sticker_elem.height // 2
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(sticker_elem, (paste_x, paste_y))
    return canvas_rgba.convert("RGB")


def draw_custom_banner(
    canvas: Image.Image,
    text: str = "",
    style: str = "none",
    icon: str = "none",
    bg_color: str = "#e11d48",
    text_color: str = "#ffffff",
    pos_x: float = 0.0,
    pos_y: float = 0.68,
    scale: float = 1.0,
    rotation: float = 0.0,
) -> Image.Image:
    if not text.strip() or not style or style == "none":
        return canvas

    icon_map = {
        "heart": "❤️", "sparkles": "✨", "party": "🎉", "star": "⭐",
        "camera": "📸", "cake": "🎂", "flower": "🌸", "ring": "💍"
    }
    icon_str = icon_map.get(icon, "")
    full_text = f"{icon_str} {text.strip()}" if icon_str else text.strip()

    w, h = canvas.size
    cx = int(w / 2 + pos_x * (w / 2 - 50))
    cy = int(h / 2 + pos_y * (h / 2 - 50))

    def hex_to_rgb(hex_str: str, default=(225, 29, 72)):
        hex_clean = hex_str.lstrip("#")
        if len(hex_clean) == 6:
            try:
                return tuple(int(hex_clean[i:i+2], 16) for i in (0, 2, 4))
            except Exception:
                pass
        return default

    bg_rgb = hex_to_rgb(bg_color, (225, 29, 72))
    tx_rgb = hex_to_rgb(text_color, (255, 255, 255))

    font = None
    font_size = max(12, int(20 * scale))
    for font_candidate in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "C:\\Windows\\Fonts\\arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]:
        if os.path.isfile(font_candidate):
            try:
                font = ImageFont.truetype(font_candidate, font_size)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    dummy_draw = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = dummy_draw.textbbox((0, 0), full_text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    rw = max(130, tw + 46)
    rh = max(36, th + 20)

    banner_img = Image.new("RGBA", (rw + 80, rh + 40), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(banner_img)
    bx = banner_img.width // 2
    by = banner_img.height // 2

    if style == "ribbon":
        tail_w = 34
        tail_h = 34
        bdraw.polygon([
            (bx - rw // 2 + 4, by - rh // 2 + 6),
            (bx - rw // 2 - tail_w, by - rh // 2 + 6),
            (bx - rw // 2 - tail_w + 12, by - rh // 2 + 6 + tail_h // 2),
            (bx - rw // 2 - tail_w, by - rh // 2 + 6 + tail_h),
            (bx - rw // 2 + 4, by - rh // 2 + 6 + tail_h),
        ], fill=bg_rgb)
        bdraw.polygon([
            (bx + rw // 2 - 4, by - rh // 2 + 6),
            (bx + rw // 2 + tail_w, by - rh // 2 + 6),
            (bx + rw // 2 + tail_w - 12, by - rh // 2 + 6 + tail_h // 2),
            (bx + rw // 2 + tail_w, by - rh // 2 + 6 + tail_h),
            (bx + rw // 2 - 4, by - rh // 2 + 6 + tail_h),
        ], fill=bg_rgb)
        bdraw.rectangle([bx - rw // 2, by - rh // 2, bx + rw // 2, by + rh // 2], fill=bg_rgb)
        bdraw.rectangle([bx - rw // 2 + 2, by - rh // 2 + 2, bx + rw // 2 - 2, by + rh // 2 - 2], outline=(255, 255, 255, 90), width=1)
        bdraw.text((bx, by), full_text, font=font, anchor="mm", fill=tx_rgb)

    elif style == "calligraphy":
        bdraw.rounded_rectangle([bx - rw // 2, by - rh // 2, bx + rw // 2, by + rh // 2], radius=8, fill=bg_rgb)
        bdraw.text((bx, by), full_text, font=font, anchor="mm", fill=tx_rgb)
        bdraw.line([(bx - tw // 2, by + th // 2 + 4), (bx + tw // 2, by + th // 2 + 4)], fill=tx_rgb, width=2)

    elif style == "pill":
        bdraw.rounded_rectangle([bx - rw // 2, by - rh // 2, bx + rw // 2, by + rh // 2], radius=rh // 2, fill=bg_rgb, outline=(255, 255, 255, 140), width=2)
        bdraw.text((bx, by), full_text, font=font, anchor="mm", fill=tx_rgb)

    elif style == "tag":
        tag_w = rw + 10
        tag_h = rh
        bdraw.polygon([
            (bx - tag_w // 2 + 14, by - tag_h // 2),
            (bx + tag_w // 2 - 4, by - tag_h // 2),
            (bx + tag_w // 2 - 4, by + tag_h // 2),
            (bx - tag_w // 2 + 14, by + tag_h // 2),
            (bx - tag_w // 2, by),
        ], fill=bg_rgb)
        bdraw.ellipse([bx - tag_w // 2 + 6, by - 4, bx - tag_w // 2 + 14, by + 4], fill=(217, 119, 6))
        bdraw.ellipse([bx - tag_w // 2 + 8, by - 2, bx - tag_w // 2 + 12, by + 2], fill=(30, 30, 30))
        bdraw.text((bx + 6, by), full_text, font=font, anchor="mm", fill=tx_rgb)

    elif style == "stamp":
        bdraw.rectangle([bx - rw // 2, by - rh // 2, bx + rw // 2, by + rh // 2], outline=bg_rgb, width=3)
        bdraw.rectangle([bx - rw // 2 + 4, by - rh // 2 + 4, bx + rw // 2 - 4, by + rh // 2 - 4], outline=bg_rgb, width=1)
        bdraw.text((bx, by), full_text.upper(), font=font, anchor="mm", fill=bg_rgb)

    elif style == "garland":
        words = full_text.split()
        if not words:
            words = [full_text]
        flag_w = max(34, (tw + 20) // max(1, len(words)))
        total_w = flag_w * len(words)
        bdraw.line([(bx - total_w // 2, by - 10), (bx + total_w // 2, by - 10)], fill=(255, 255, 255, 180), width=2)
        for idx, wrd in enumerate(words):
            fx = bx - total_w // 2 + idx * flag_w + flag_w // 2
            bdraw.polygon([
                (fx - flag_w // 2 + 2, by - 10),
                (fx + flag_w // 2 - 2, by - 10),
                (fx, by + 18),
            ], fill=bg_rgb)
            bdraw.text((fx, by), wrd, font=font, anchor="mm", fill=tx_rgb)

    if rotation != 0.0:
        banner_img = banner_img.rotate(-rotation, expand=True, resample=Image.BICUBIC)

    paste_x = cx - banner_img.width // 2
    paste_y = cy - banner_img.height // 2
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(banner_img, (paste_x, paste_y))
    return canvas_rgba.convert("RGB")


def encode_planar_rgb(
    pil_image: "Image.Image",
    model_name: str = "SP-2",
    hw_width: Optional[int] = None,
    hw_height: Optional[int] = None,
    fit_mode: str = "crop",
    frame_style: str = "none",
    sticker: str = "none",
    sticker_image: Optional["Image.Image"] = None,
    sticker_pos: str = "topRight",
    sticker_scale: float = 1.0,
    sticker_opacity: float = 1.0,
    sticker_rot: float = 0.0,
    sticker_pos_x: float = 0.65,
    sticker_pos_y: float = 0.65,
    banner_text: str = "",
    banner_style: str = "none",
    banner_icon: str = "none",
    banner_bg_color: str = "#e11d48",
    banner_text_color: str = "#ffffff",
    banner_pos_x: float = 0.0,
    banner_pos_y: float = 0.68,
    banner_scale: float = 1.0,
    banner_rotation: float = 0.0,
) -> bytes:
    spec = MODELS.get(model_name.upper(), MODELS["SP-2"])
    portrait_w = hw_width or spec["width"]
    portrait_h = hw_height or spec["height"]
    img = pil_image.convert("RGB")

    if fit_mode == "fit":
        img.thumbnail((portrait_w, portrait_h), Image.Resampling.LANCZOS)
        framed = Image.new("RGB", (portrait_w, portrait_h), (255, 255, 255))
        ox = (portrait_w - img.width) // 2
        oy = (portrait_h - img.height) // 2
        framed.paste(img, (ox, oy))
        img = framed
    else:
        iw, ih = img.size
        scale = max(portrait_w / iw, portrait_h / ih)
        new_w, new_h = int(iw * scale), int(ih * scale)
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        left = (new_w - portrait_w) // 2
        top = (new_h - portrait_h) // 2
        img = img.crop((left, top, left + portrait_w, top + portrait_h))

    if frame_style and frame_style != "none":
        img = draw_decorative_frame(img, frame_style)

    if (sticker and sticker != "none") or sticker_image is not None:
        img = draw_sticker_overlay(
            img,
            sticker=sticker,
            sticker_image=sticker_image,
            position=sticker_pos,
            scale=sticker_scale,
            opacity=sticker_opacity,
            rotation=sticker_rot,
            pos_x=sticker_pos_x,
            pos_y=sticker_pos_y,
        )

    if banner_text and banner_style and banner_style != "none":
        img = draw_custom_banner(
            img,
            text=banner_text,
            style=banner_style,
            icon=banner_icon,
            bg_color=banner_bg_color,
            text_color=banner_text_color,
            pos_x=banner_pos_x,
            pos_y=banner_pos_y,
            scale=banner_scale,
            rotation=banner_rotation,
        )

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
                return {"ok": True, "film": info["film"], "battery": info["battery"], "dry_run": True}
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
                return {"ok": True, "film": film, "battery": batt, "dry_run": False}


def _normalize_legacy_model(raw: str) -> str:
    m = (raw or "SP-2").strip().upper()
    if "1" in m:
        return "SP-1"
    if "3" in m:
        return "SP-3"
    return "SP-2"


def get_connected_wifi_ssid() -> str:
    """Get the currently connected Wi-Fi SSID on macOS, Windows, or Linux."""
    import platform, subprocess
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
    import platform, subprocess
    networks = []
    seen = set()
    sys_name = platform.system().lower()

    if "darwin" in sys_name:
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
    connected_ssid = get_connected_wifi_ssid()
    all_networks = scan_all_nearby_wifi()
    instax_networks = [n for n in all_networks if n["is_instax"]]

    hardware_printer_found = probe_tcp_printer("192.168.0.251", 8080, timeout=0.6)
    alt_gw_found = probe_tcp_printer("192.168.0.1", 8080, timeout=0.4)
    sim_found = probe_tcp_printer("127.0.0.1", sim_port, timeout=0.2)

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
        "connected_ssid": connected_ssid,
        "networks_count": len(all_networks),
        "all_networks": all_networks,
        "instax_networks": instax_networks,
        "hardware_printer_reachable": hardware_printer_found,
        "simulator_reachable": sim_found,
        "items": items,
    }


def scan_wifi_and_printers(sim_port: int = 18080) -> list:
    """Quick helper returning dropdown list of items."""
    diag = run_full_wifi_diagnostics(sim_port=sim_port)
    return diag.get("items", [])


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
    parser.add_argument("--serve", action="store_true", help="Launch Local Web Studio Bridge (127.0.0.1:8089)")
    parser.add_argument("--fit", action="store_true", help="Fit image inside frame with borders (default: crop to fill)")
    parser.add_argument("--caption", default="", help="Optional bottom caption text")
    parser.add_argument("--qr", default="", help="Optional scannable QR code text/URL")
    parser.add_argument("--frame-style", choices=["none", "classic_white", "obsidian_black", "rainbow_gradient", "sunset_ombre", "sprocket_35mm", "gold_metallic", "metallic_gold", "rose_gold", "pastel_pop", "candy_pastel", "postage_stamp", "baroque_filigree", "wedding_corners", "stained_glass", "bokeh_sparkles", "fireworks_celebration", "twin_hearts_garland", "holiday_garland", "botanical_foliage"], default="none", help="Decorative film frame style")
    parser.add_argument("--sticker", choices=["none"] + list(STICKER_MAP.keys()), default="none", help="Sticker emoji overlay")
    parser.add_argument("--sticker-image", default="", help="Path to custom image/logo overlay PNG/JPG")
    parser.add_argument("--sticker-pos", choices=["topRight", "topLeft", "bottomRight", "bottomLeft", "center", "topCenter", "bottomCenter", "custom"], default="topRight")
    parser.add_argument("--sticker-x", type=float, default=0.65, help="Sticker horizontal offset (-1.0 to 1.0)")
    parser.add_argument("--sticker-y", type=float, default=0.65, help="Sticker vertical offset (-1.0 to 1.0)")
    parser.add_argument("--sticker-scale", type=float, default=1.0, help="Sticker scale multiplier (0.2 to 2.5)")
    parser.add_argument("--sticker-opacity", type=float, default=1.0, help="Sticker opacity (0.1 to 1.0)")
    parser.add_argument("--sticker-rot", type=float, default=0.0, help="Sticker rotation angle in degrees")
    parser.add_argument("--banner-text", default="", help="Custom banner message")
    parser.add_argument("--banner-style", choices=["none", "ribbon", "calligraphy", "pill", "tag", "stamp", "garland"], default="none")
    parser.add_argument("--banner-icon", choices=["none", "heart", "sparkles", "party", "star", "camera", "cake", "flower", "ring"], default="none")
    parser.add_argument("--banner-color", default="#e11d48", help="Banner background color hex (e.g. #e11d48)")
    parser.add_argument("--banner-text-color", default="#ffffff", help="Banner text color hex (e.g. #ffffff)")
    parser.add_argument("--banner-x", type=float, default=0.0, help="Banner X position (-1.0 to 1.0)")
    parser.add_argument("--banner-y", type=float, default=0.68, help="Banner Y position (-1.0 to 1.0)")
    parser.add_argument("--banner-scale", type=float, default=1.0, help="Banner scale multiplier")
    parser.add_argument("--banner-rot", type=float, default=0.0, help="Banner rotation degrees")
    args, _ = parser.parse_known_args()

    if getattr(args, "serve", False):
        bridge_candidates = [
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "legacy_web_bridge.py"),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Web-WiFi-Offline", "legacy_web_bridge.py"),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "Web-WiFi-Offline", "legacy_web_bridge.py"),
        ]
        for cand in bridge_candidates:
            if os.path.exists(cand):
                subprocess.run([sys.executable, cand])
                return
        print("❌ Could not find legacy_web_bridge.py")
        return

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
    sticker_img_obj = None
    if getattr(args, "sticker_image", None):
        try:
            sticker_img_obj = Image.open(args.sticker_image)
        except Exception as e:
            print(f"Warning: could not open sticker image '{args.sticker_image}': {e}", file=sys.stderr)

    planar = encode_planar_rgb(
        img,
        model_name,
        fit_mode=fit_mode,
        frame_style=getattr(args, "frame_style", "none"),
        sticker=getattr(args, "sticker", "none"),
        sticker_image=sticker_img_obj,
        sticker_pos=getattr(args, "sticker_pos", "topRight"),
        sticker_scale=getattr(args, "sticker_scale", 1.0),
        sticker_opacity=getattr(args, "sticker_opacity", 1.0),
        sticker_rot=getattr(args, "sticker_rot", 0.0),
        sticker_pos_x=getattr(args, "sticker_x", 0.65),
        sticker_pos_y=getattr(args, "sticker_y", 0.65),
        banner_text=getattr(args, "banner_text", ""),
        banner_style=getattr(args, "banner_style", "none"),
        banner_icon=getattr(args, "banner_icon", "none"),
        banner_bg_color=getattr(args, "banner_color", "#e11d48"),
        banner_text_color=getattr(args, "banner_text_color", "#ffffff"),
        banner_pos_x=getattr(args, "banner_x", 0.0),
        banner_pos_y=getattr(args, "banner_y", 0.68),
        banner_scale=getattr(args, "banner_scale", 1.0),
        banner_rotation=getattr(args, "banner_rot", 0.0),
    )
    result = client.print_planar_rgb(
        planar,
        model_name=model_name,
        dry_run=args.dry_run,
        progress_cb=lambda frac, msg: print(f"[{int(frac * 100):3d}%] {msg}"),
    )
    print(f"✅ Done! Film remaining: {result['film']}/10 | Battery: {result['battery']}/4")


if __name__ == "__main__":
    main()

