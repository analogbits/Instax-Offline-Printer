#!/usr/bin/env python3
"""
Legacy Instax Printer GUI (Windows & Linux) — Wi-Fi Direct Studio (SP-1 • SP-2 • SP-3)
======================================================================================
Complete offline desktop studio for Fujifilm Instax SHARE SP-1, SP-2, and SP-3 printers.
Features:
  - Wi-Fi Direct Network & Subnet Discovery Dropdown + One-Click Scan
  - Authentic 10-LED Film & Battery Telemetry (Unlit when offline; real hardware status when connected)
  - Built-in Virtual SP-1 / SP-2 / SP-3 Simulator (127.0.0.1:18080)
  - Dry Run (0-Film Verification) Mode
  - Multi-Photo Collage Studio with live Border Spacing slider (0..28 px)
  - Scannable QR Code Generator & Overlay (URL, Text, Phone, Email, Wi-Fi, Location)
  - Fujifilm SHARE Artistic Filters & Exposure Controls
  - Bit-Exact 90° Scanline Column-Major Planar RGB Encoder (600x800 Mini & 800x800 Square)
"""

import os
import platform
import socket
import subprocess
import sys
import threading
import time
import tkinter as tk
import math
import random
from tkinter import filedialog, messagebox, ttk

try:
    from PIL import Image, ImageDraw, ImageEnhance, ImageOps, ImageTk, ImageChops
except ImportError:
    raise SystemExit("Pillow is required. Install with: pip install pillow")

from legacy_instax_printer import (
    MODELS,
    LegacyInstaxClient,
    VirtualInstaxShareServer,
    encode_planar_rgb,
)


def apply_analog_fx(
    canvas: Image.Image,
    photo_box=None,
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
            from PIL import ImageFont
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


class LegacyInstaxPrinterGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Legacy Instax Printer — Wi-Fi Direct Studio (SP-1 • SP-2 • SP-3)")
        self.geometry("1200x760")
        self.minsize(1060, 680)
        self.is_mac = platform.system().lower() == "darwin"
        self.bg_root = "#ECECEC" if self.is_mac else "#18181B"
        self.bg_card = "#FAFAFA" if self.is_mac else "#222226"
        self.bg_top  = "#E4E4E7" if self.is_mac else "#27272A"
        self.fg_text = "#18181B" if self.is_mac else "#F4F4F5"
        self.fg_dim  = "#52525B" if self.is_mac else "#A1A1AA"

        self.configure(bg=self.bg_root)

        # State
        self.model_var = tk.StringVar(value="SP-2")
        self.wifi_choice_var = tk.StringVar(value="🎯 Default Instax SHARE (192.168.0.251:8080)")
        self.ip_var = tk.StringVar(value="192.168.0.251")
        self.port_var = tk.StringVar(value="8080")
        self.pin_var = tk.StringVar(value="1111")
        self.sim_var = tk.BooleanVar(value=False)
        self.dry_run_var = tk.BooleanVar(value=False)

        self.fit_mode_var = tk.StringVar(value="fill")
        self.filter_var = tk.StringVar(value="Normal")
        self.rotation_deg = 0

        self.collage_layout_var = tk.StringVar(value="Single")
        self.collage_spacing_var = tk.IntVar(value=8)
        self.collage_images = []

        self.qr_type_var = tk.StringVar(value="Off")
        self.qr_text_var = tk.StringVar(value="https://github.com/analogbits/Instax-Offline-Printer")
        self.caption_var = tk.StringVar(value="")
        self.date_stamp_var = tk.BooleanVar(value=False)

        # Analog Creative FX State
        self.warmth_var = tk.DoubleVar(value=0.0)
        self.vignette_var = tk.DoubleVar(value=0.0)
        self.leak_type_var = tk.StringVar(value="none")
        self.leak_placement_var = tk.StringVar(value="auto")
        self.leak_intensity_var = tk.DoubleVar(value=0.70)
        self.film_grain_var = tk.DoubleVar(value=0.0)
        self.analog_wear_var = tk.DoubleVar(value=0.0)
        self.vintage_date_var = tk.BooleanVar(value=False)
        self.vintage_date_text_var = tk.StringVar(value="")
        self.vintage_date_color_var = tk.StringVar(value="amber")
        self.vintage_date_placement_var = tk.StringVar(value="bottomRight")
        self.leak_auto_seed = 12345

        # Authentic Telemetry State (None when disconnected!)
        self.is_connected = False
        self.film_remaining = None
        self.battery_level = None
        self.status_var = tk.StringVar(value="Not Connected — Scan or select INSTAX-XXXXXXXX Wi-Fi from dropdown")
        self.led_header_var = tk.StringVar(value="Not Connected • —/10 • Batt —")
        self.led_dots = []

        self.sim_server = VirtualInstaxShareServer(port=18080, model="SP-2", pin=1111)
        self.primary_image = self._make_test_card("SP-2")
        self.rendered_image = None
        self.tk_preview = None

        self._build_ui()
        self.refresh_preview()
        self.scan_wifi_and_printers()

    def safe_after(self, fn):
        """Thread-safe UI callback that avoids RuntimeError if window is closed."""
        try:
            if self.winfo_exists():
                self.after(0, fn)
        except Exception:
            pass

    def _build_ui(self):
        # Top Wi-Fi Discovery & Connection Bar
        top = tk.Frame(self, bg=self.bg_top, padx=12, pady=8)
        top.pack(fill=tk.X)

        tk.Label(top, text="📡 Legacy Instax Printer", fg=self.fg_text, bg=self.bg_top, font=("Segoe UI", 11, "bold")).pack(side=tk.LEFT, padx=(0, 10))

        tk.Label(top, text="Wi-Fi / Printer:", fg=self.fg_dim, bg=self.bg_top).pack(side=tk.LEFT)
        self.wifi_cb = ttk.Combobox(top, textvariable=self.wifi_choice_var, width=32, state="readonly")
        self.wifi_cb.pack(side=tk.LEFT, padx=4)
        self.wifi_cb.bind("<<ComboboxSelected>>", lambda _e: self.on_wifi_choice_selected())

        tk.Button(top, text="Scan Wi-Fi", bg="#3F3F46", fg="white", relief=tk.FLAT, padx=8, command=self.scan_wifi_and_printers).pack(side=tk.LEFT, padx=4)

        tk.Label(top, text="Model:", fg=self.fg_dim, bg=self.bg_top).pack(side=tk.LEFT, padx=(8, 2))
        model_cb = ttk.Combobox(top, textvariable=self.model_var, values=["SP-1", "SP-2", "SP-3"], width=6, state="readonly")
        model_cb.pack(side=tk.LEFT, padx=4)
        model_cb.bind("<<ComboboxSelected>>", lambda _e: self.on_model_changed())

        tk.Label(top, text="IP:", fg=self.fg_dim, bg=self.bg_top).pack(side=tk.LEFT, padx=(6, 2))
        tk.Entry(top, textvariable=self.ip_var, width=13).pack(side=tk.LEFT, padx=2)

        tk.Label(top, text="PIN:", fg=self.fg_dim, bg=self.bg_top).pack(side=tk.LEFT, padx=(6, 2))
        tk.Entry(top, textvariable=self.pin_var, width=5).pack(side=tk.LEFT, padx=2)

        tk.Button(top, text="Connect", bg="#2563EB", fg="white", relief=tk.FLAT, padx=10, command=self.query_status).pack(side=tk.LEFT, padx=8)

        tk.Checkbutton(
            top,
            text="Simulator",
            variable=self.sim_var,
            bg=self.bg_top,
            fg=self.fg_text,
            selectcolor=self.bg_card,
            command=self.toggle_simulator,
        ).pack(side=tk.RIGHT, padx=4)

        tk.Checkbutton(
            top,
            text="Dry Run (0-Film)",
            variable=self.dry_run_var,
            bg=self.bg_top,
            fg="#B45309" if self.is_mac else "#FBBF24",
            selectcolor=self.bg_card,
        ).pack(side=tk.RIGHT, padx=4)

        # Main 3-Column Body
        body = tk.Frame(self, bg=self.bg_root)
        body.pack(fill=tk.BOTH, expand=True, padx=10, pady=8)

        # Left Panel (Authentic 10-LED Card + Photo Source)
        left = tk.Frame(body, bg=self.bg_card, width=245, padx=10, pady=10)
        left.pack(side=tk.LEFT, fill=tk.Y)
        left.pack_propagate(False)

        led_card = tk.Frame(left, bg=self.bg_root, padx=8, pady=8)
        led_card.pack(fill=tk.X, pady=(0, 12))
        tk.Label(led_card, textvariable=self.led_header_var, fg=self.fg_dim, bg=self.bg_root, font=("Segoe UI", 8, "bold")).pack(anchor="w")
        dots_row = tk.Frame(led_card, bg=self.bg_root, pady=4)
        dots_row.pack(fill=tk.X)
        self.led_dots = []
        for _ in range(10):
            lbl = tk.Label(dots_row, text="●", fg="#A1A1AA" if self.is_mac else "#3F3F46", bg=self.bg_root, font=("Segoe UI", 11))
            lbl.pack(side=tk.LEFT, padx=2)
            self.led_dots.append(lbl)

        tk.Label(left, text="PHOTO SOURCE", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 6))
        tk.Button(left, text="📂 Open Image File...", bg="#2563EB", fg="white", relief=tk.FLAT, pady=6, command=self.open_primary_image).pack(fill=tk.X, pady=3)
        tk.Button(left, text="✨ Generate Test Card", bg="#4B5563" if self.is_mac else "#3F3F46", fg="white", relief=tk.FLAT, pady=5, command=self.reset_test_card).pack(fill=tk.X, pady=3)
        tk.Button(left, text="🔄 Rotate 90°", bg="#4B5563" if self.is_mac else "#3F3F46", fg="white", relief=tk.FLAT, pady=5, command=self.rotate_image).pack(fill=tk.X, pady=3)

        tk.Label(left, text="\nWI-FI DIRECT GUIDE", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w")
        guide = (
            "1. Power on your Instax SHARE\n   SP-1, SP-2, or SP-3 printer.\n"
            "2. Click 'Scan Wi-Fi' and pick\n   'INSTAX-XXXXXXXX' from the\n   dropdown list.\n"
            "3. Default IP: 192.168.0.251\n   Port: 8080 • PIN: 1111"
        )
        tk.Label(left, text=guide, fg=self.fg_text, bg=self.bg_card, justify=tk.LEFT, font=("Segoe UI", 9)).pack(anchor="w", pady=6)

        # Right Inspector (Pack right column FIRST so center can expand)
        right = tk.Frame(body, bg=self.bg_card, width=320, padx=12, pady=10)
        right.pack(side=tk.RIGHT, fill=tk.Y)
        right.pack_propagate(False)

        # Center Preview Canvas (Pack center LAST to fill remaining space)
        center = tk.Frame(body, bg=self.bg_root, padx=14)
        center.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self.canvas_label = tk.Label(center, bg="#E4E4E7" if self.is_mac else "#27272A", bd=2, relief=tk.SOLID)
        self.canvas_label.pack(expand=True, pady=10)

        btn_bar = tk.Frame(center, bg=self.bg_root)
        btn_bar.pack(pady=8)
        tk.Button(
            btn_bar,
            text="🧪 Test Transfer (0-Film Dry Run)",
            bg="#D97706",
            fg="white",
            font=("Segoe UI", 10, "bold"),
            relief=tk.FLAT,
            padx=14,
            pady=7,
            command=lambda: self.start_print(force_dry_run=True),
        ).pack(side=tk.LEFT, padx=8)

        tk.Button(
            btn_bar,
            text="🖨️ Print Over Wi-Fi Direct",
            bg="#16A34A",
            fg="white",
            font=("Segoe UI", 11, "bold"),
            relief=tk.FLAT,
            padx=18,
            pady=7,
            command=lambda: self.start_print(force_dry_run=False),
        ).pack(side=tk.LEFT, padx=8)

        tk.Label(right, text="FRAMING & FILTERS", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w")
        ttk.Combobox(right, textvariable=self.fit_mode_var, values=["fill", "fit"], state="readonly").pack(fill=tk.X, pady=4)
        self.fit_mode_var.trace_add("write", lambda *_: self.refresh_preview())

        ttk.Combobox(
            right,
            textvariable=self.filter_var,
            values=["Normal", "Fujifilm Intelligence", "Monochrome", "Sepia", "Vivid Velvia"],
            state="readonly",
        ).pack(fill=tk.X, pady=4)
        self.filter_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="ANALOG CREATIVE FX", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(10, 2))

        # Warmth Scale
        tk.Label(right, text="Warmth Dial (-1.0..+1.0):", fg=self.fg_text, bg=self.bg_card).pack(anchor="w")
        tk.Scale(right, from_=-1.0, to=1.0, resolution=0.05, orient=tk.HORIZONTAL, variable=self.warmth_var, bg=self.bg_card, fg=self.fg_text, highlightthickness=0, command=lambda _v: self.refresh_preview()).pack(fill=tk.X)

        # Vignette Scale
        tk.Label(right, text="Lens Vignette Falloff:", fg=self.fg_text, bg=self.bg_card).pack(anchor="w")
        tk.Scale(right, from_=0.0, to=1.0, resolution=0.05, orient=tk.HORIZONTAL, variable=self.vignette_var, bg=self.bg_card, fg=self.fg_text, highlightthickness=0, command=lambda _v: self.refresh_preview()).pack(fill=tk.X)

        # Light Leak
        ttk.Combobox(right, textvariable=self.leak_type_var, values=["none", "burn", "sunburst", "sunset", "rainbow"], state="readonly").pack(fill=tk.X, pady=2)
        f_leak_p = tk.Frame(right, bg=self.bg_card)
        f_leak_p.pack(fill=tk.X, pady=2)
        cb_place = ttk.Combobox(f_leak_p, textvariable=self.leak_placement_var, values=["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"], state="readonly")
        cb_place.pack(side=tk.LEFT, fill=tk.X, expand=True)
        tk.Button(f_leak_p, text="🎲", width=3, bg=self.bg_card, fg=self.fg_text, command=self.roll_auto_leak).pack(side=tk.LEFT, padx=(4, 0))
        self.leak_placement_var.trace_add("write", self.on_leak_placement_selected)

        # Grain & Wear Scales
        tk.Label(right, text="Silver Halide Grain:", fg=self.fg_text, bg=self.bg_card).pack(anchor="w")
        tk.Scale(right, from_=0.0, to=1.0, resolution=0.05, orient=tk.HORIZONTAL, variable=self.film_grain_var, bg=self.bg_card, fg=self.fg_text, highlightthickness=0, command=lambda _v: self.refresh_preview()).pack(fill=tk.X)

        tk.Label(right, text="Analog Wear & Dust:", fg=self.fg_text, bg=self.bg_card).pack(anchor="w")
        tk.Scale(right, from_=0.0, to=1.0, resolution=0.05, orient=tk.HORIZONTAL, variable=self.analog_wear_var, bg=self.bg_card, fg=self.fg_text, highlightthickness=0, command=lambda _v: self.refresh_preview()).pack(fill=tk.X)

        # Date Stamp
        tk.Checkbutton(right, text="LED Date Stamp", variable=self.vintage_date_var, bg=self.bg_card, fg=self.fg_text, selectcolor=self.bg_root, command=self.refresh_preview).pack(anchor="w", pady=(4, 0))
        d_row = tk.Frame(right, bg=self.bg_card)
        d_row.pack(fill=tk.X, pady=2)
        tk.Entry(d_row, textvariable=self.vintage_date_text_var, width=12).pack(side=tk.LEFT, fill=tk.X, expand=True)
        self.vintage_date_text_var.trace_add("write", lambda *_: self.refresh_preview())
        ttk.Combobox(d_row, textvariable=self.vintage_date_color_var, values=["amber", "red", "green", "white"], width=7, state="readonly").pack(side=tk.LEFT, padx=2)
        self.vintage_date_color_var.trace_add("write", lambda *_: self.refresh_preview())

        fx_row = tk.Frame(right, bg=self.bg_card)
        fx_row.pack(fill=tk.X, pady=4)
        tk.Button(fx_row, text="🎲 Surprise Me!", bg="#2563EB", fg="white", relief=tk.FLAT, command=self.surprise_me_analog_fx).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        tk.Button(fx_row, text="Reset FX", bg="#4B5563" if self.is_mac else "#52525B", fg="white", relief=tk.FLAT, command=self.reset_analog_fx).pack(side=tk.LEFT)

        tk.Label(right, text="MULTI-PHOTO COLLAGE", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(10, 2))
        ttk.Combobox(
            right,
            textvariable=self.collage_layout_var,
            values=["Single", "2-Up Vertical", "2-Up Horizontal", "3-Photo Grid", "4-Photo 2x2 Grid", "6-Photo Grid"],
            state="readonly",
        ).pack(fill=tk.X, pady=4)
        self.collage_layout_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="Collage Border Spacing (px):", fg=self.fg_text, bg=self.bg_card).pack(anchor="w")
        tk.Scale(
            right,
            from_=0,
            to=28,
            orient=tk.HORIZONTAL,
            variable=self.collage_spacing_var,
            bg=self.bg_card,
            fg=self.fg_text,
            highlightthickness=0,
            command=lambda _v: self.on_spacing_changed(),
        ).pack(fill=tk.X)

        c_btns = tk.Frame(right, bg=self.bg_card)
        c_btns.pack(fill=tk.X, pady=4)
        tk.Button(c_btns, text="+ Add Collage Photos", bg="#2563EB", fg="white", relief=tk.FLAT, command=self.add_collage_photos).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 4))
        tk.Button(c_btns, text="Clear Slots", bg="#4B5563" if self.is_mac else "#52525B", fg="white", relief=tk.FLAT, command=self.clear_collage_photos).pack(side=tk.LEFT)

        tk.Label(right, text="QR CODE & CAPTION", fg=self.fg_dim, bg=self.bg_card, font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(12, 2))
        ttk.Combobox(
            right,
            textvariable=self.qr_type_var,
            values=["Off", "Website URL", "Custom Text", "Phone Number", "Wi-Fi Access"],
            state="readonly",
        ).pack(fill=tk.X, pady=3)
        self.qr_type_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Entry(right, textvariable=self.qr_text_var).pack(fill=tk.X, pady=3)
        self.qr_text_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="Bottom Caption:", fg=self.fg_text, bg=self.bg_card).pack(anchor="w", pady=(6, 0))
        tk.Entry(right, textvariable=self.caption_var).pack(fill=tk.X, pady=3)
        self.caption_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Checkbutton(
            right,
            text="Include Date Stamp",
            variable=self.date_stamp_var,
            bg=self.bg_card,
            fg=self.fg_text,
            selectcolor=self.bg_root,
            command=self.refresh_preview,
        ).pack(anchor="w")

        # Bottom Status Bar
        status_bar = tk.Frame(self, bg=self.bg_top, padx=12, pady=6)
        status_bar.pack(fill=tk.X, side=tk.BOTTOM)
        tk.Label(status_bar, textvariable=self.status_var, fg=self.fg_text, bg=self.bg_top, font=("Segoe UI", 9)).pack(side=tk.LEFT)

    def update_led_display(self):
        dot_off = "#A1A1AA" if self.is_mac else "#3F3F46"
        if self.is_connected and self.film_remaining is not None and self.battery_level is not None:
            self.led_header_var.set(f"{self.model_var.get()} FILM LEDs • {self.film_remaining}/10 Left • Batt {self.battery_level}/4")
            for idx, lbl in enumerate(self.led_dots):
                lbl.configure(fg="#16A34A" if idx < self.film_remaining else dot_off)
        else:
            self.led_header_var.set("Not Connected • —/10 • Batt —")
            for lbl in self.led_dots:
                lbl.configure(fg=dot_off)

    def scan_wifi_and_printers(self):
        def worker():
            choices = []
            sys_name = platform.system().lower()
            try:
                if "windows" in sys_name:
                    out = subprocess.check_output(["netsh", "wlan", "show", "networks"], text=True, errors="ignore", timeout=4)
                    for line in out.splitlines():
                        if "SSID" in line and ":" in line:
                            ssid = line.split(":", 1)[1].strip()
                            if ssid:
                                prefix = "📸 Join INSTAX Wi-Fi: " if "INSTAX" in ssid.upper() else "📶 Wi-Fi: "
                                choices.append(f"{prefix}{ssid}")
                elif "linux" in sys_name:
                    out = subprocess.check_output(["nmcli", "-t", "-f", "SSID", "dev", "wifi", "list"], text=True, errors="ignore", timeout=4)
                    for line in out.splitlines():
                        ssid = line.strip()
                        if ssid:
                            prefix = "📸 Join INSTAX Wi-Fi: " if "INSTAX" in ssid.upper() else "📶 Wi-Fi: "
                            choices.append(f"{prefix}{ssid}")
            except Exception:
                pass

            # Probe TCP 8080 on 192.168.0.251 & 192.168.0.1
            for ip in ("192.168.0.251", "192.168.0.1"):
                try:
                    with socket.create_connection((ip, 8080), timeout=0.45):
                        choices.insert(0, f"🟢 Discovered Printer ({ip}:8080)")
                except Exception:
                    pass

            choices.append("🎯 Default Instax SHARE (192.168.0.251:8080)")
            choices.append("🧪 Virtual SP-1/2/3 Simulator (127.0.0.1:18080)")

            def update_cb():
                self.wifi_cb["values"] = choices
                if choices:
                    self.wifi_choice_var.set(choices[0])

            self.safe_after(update_cb)

        threading.Thread(target=worker, daemon=True).start()

    def on_wifi_choice_selected(self):
        val = self.wifi_choice_var.get()
        if "Virtual SP" in val:
            self.sim_var.set(True)
            self.toggle_simulator()
        elif "Wi-Fi:" in val:
            ssid = val.split("Wi-Fi:", 1)[1].strip()
            self.sim_var.set(False)
            self.ip_var.set("192.168.0.251")
            self.port_var.set("8080")
            self.status_var.set(f"Joining Wi-Fi '{ssid}'...")
            threading.Thread(target=self._join_wifi_ssid, args=(ssid,), daemon=True).start()
        elif "(" in val and ":8080)" in val:
            ip = val.split("(", 1)[1].split(":8080)", 1)[0]
            self.sim_var.set(False)
            self.ip_var.set(ip)
            self.port_var.set("8080")
            self.query_status()

    def _join_wifi_ssid(self, ssid: str):
        sys_name = platform.system().lower()
        try:
            if "windows" in sys_name:
                subprocess.run(["netsh", "wlan", "connect", f"name={ssid}"], timeout=5)
            elif "linux" in sys_name:
                subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], timeout=8)
        except Exception:
            pass
        self.after(1000, self.query_status)

    def on_model_changed(self):
        m = self.model_var.get()
        self.sim_server.model = m
        self.refresh_preview()

    def toggle_simulator(self):
        if self.sim_var.get():
            self.sim_server.model = self.model_var.get()
            self.sim_server.start()
            self.ip_var.set("127.0.0.1")
            self.port_var.set("18080")
            self.query_status()
        else:
            self.ip_var.set("192.168.0.251")
            self.port_var.set("8080")
            self.is_connected = False
            self.film_remaining = None
            self.battery_level = None
            self.update_led_display()
            self.status_var.set("Not Connected — Switched to physical Instax SHARE Wi-Fi Direct (192.168.0.251:8080)")

    def on_spacing_changed(self):
        if self.collage_layout_var.get() == "Single" and self.collage_images:
            self._auto_select_collage_layout()
        self.refresh_preview()

    def _auto_select_collage_layout(self):
        total = 1 + len(self.collage_images)
        if total <= 1:
            self.collage_layout_var.set("Single")
        elif total == 2:
            self.collage_layout_var.set("2-Up Vertical")
        elif total == 3:
            self.collage_layout_var.set("3-Photo Grid")
        elif total == 4:
            self.collage_layout_var.set("4-Photo 2x2 Grid")
        else:
            self.collage_layout_var.set("6-Photo Grid")

    def open_primary_image(self):
        path = filedialog.askopenfilename(filetypes=[("Images", "*.png *.jpg *.jpeg *.bmp *.webp")])
        if path:
            self.primary_image = Image.open(path).convert("RGB")
            self.refresh_preview()

    def add_collage_photos(self):
        paths = filedialog.askopenfilenames(filetypes=[("Images", "*.png *.jpg *.jpeg *.bmp *.webp")])
        for p in paths:
            self.collage_images.append(Image.open(p).convert("RGB"))
        self._auto_select_collage_layout()
        self.refresh_preview()

    def clear_collage_photos(self):
        self.collage_images.clear()
        self.collage_layout_var.set("Single")
        self.refresh_preview()

    def reset_test_card(self):
        self.primary_image = self._make_test_card(self.model_var.get())
        self.refresh_preview()

    def rotate_image(self):
        self.rotation_deg = (self.rotation_deg + 90) % 360
        self.refresh_preview()

    @staticmethod
    def _make_test_card(model: str) -> Image.Image:
        spec = MODELS.get(model, MODELS["SP-2"])
        w, h = spec["width"], spec["height"]
        img = Image.new("RGB", (w, h), (34, 52, 92))
        draw = ImageDraw.Draw(img)
        for y in range(h):
            r = int(34 + (y / h) * 185)
            g = int(52 + (y / h) * 95)
            b = int(92 - (y / h) * 30)
            draw.line([(0, y), (w, y)], fill=(r, g, b))
        draw.ellipse((w * 0.18, h * 0.22, w * 0.82, h * 0.78), outline=(255, 255, 255), width=4)
        draw.text((w // 2 - 125, h // 2 - 18), f"INSTAX SHARE {model} ({w}x{h})", fill=(255, 255, 255))
        return img

    def _apply_filter(self, img: Image.Image) -> Image.Image:
        out = img.convert("RGB")
        if self.rotation_deg:
            out = out.rotate(-self.rotation_deg, expand=True)
        flt = self.filter_var.get()
        if flt == "Fujifilm Intelligence":
            out = ImageEnhance.Contrast(out).enhance(1.12)
            out = ImageEnhance.Color(out).enhance(1.15)
        elif flt == "Monochrome":
            out = ImageOps.grayscale(out).convert("RGB")
        elif flt == "Sepia":
            g = ImageOps.grayscale(out)
            out = ImageOps.colorize(g, "#2B1B0E", "#F5E1C0")
        elif flt == "Vivid Velvia":
            out = ImageEnhance.Color(out).enhance(1.4)
        return out

    def reset_analog_fx(self):
        self.warmth_var.set(0.0)
        self.vignette_var.set(0.0)
        self.leak_type_var.set("none")
        self.leak_placement_var.set("auto")
        self.leak_intensity_var.set(0.70)
        self.film_grain_var.set(0.0)
        self.analog_wear_var.set(0.0)
        self.vintage_date_var.set(False)
        self.vintage_date_text_var.set("")
        self.vintage_date_color_var.set("amber")
        self.vintage_date_placement_var.set("bottomRight")
        self.refresh_preview()

    def surprise_me_analog_fx(self):
        self.warmth_var.set(round(random.uniform(-0.3, 0.6), 2))
        self.vignette_var.set(round(random.uniform(0.25, 0.75), 2))
        self.leak_type_var.set(random.choice(["none", "burn", "sunburst", "sunset", "rainbow"]))
        self.leak_placement_var.set(random.choice(["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]))
        self.leak_intensity_var.set(round(random.uniform(0.45, 0.90), 2))
        self.film_grain_var.set(round(random.uniform(0.15, 0.55), 2))
        self.analog_wear_var.set(round(random.uniform(0.10, 0.45), 2))
        self.vintage_date_var.set(True)
        self.vintage_date_color_var.set(random.choice(["amber", "red", "green", "white"]))
        self.vintage_date_placement_var.set(random.choice(["bottomRight", "bottomLeft", "topRight", "topLeft"]))
        self.refresh_preview()

    def roll_auto_leak(self):
        import random
        self.leak_placement_var.set("auto")
        self.leak_auto_seed = random.randint(1, 1000000)
        self.refresh_preview()

    def on_leak_placement_selected(self, *_):
        import random
        if self.leak_placement_var.get() == "auto":
            self.leak_auto_seed = random.randint(1, 1000000)
        self.refresh_preview()

    def refresh_preview(self):
        spec = MODELS.get(self.model_var.get(), MODELS["SP-2"])
        w, h = spec["width"], spec["height"]
        canvas = Image.new("RGB", (w, h), (255, 255, 255))

        layout = self.collage_layout_var.get()
        rects = {
            "Single": [(0, 0, 1, 1)],
            "2-Up Vertical": [(0, 0, 0.5, 1), (0.5, 0, 0.5, 1)],
            "2-Up Horizontal": [(0, 0, 1, 0.5), (0, 0.5, 1, 0.5)],
            "3-Photo Grid": [(0, 0, 1, 0.5), (0, 0.5, 0.5, 0.5), (0.5, 0.5, 0.5, 0.5)],
            "4-Photo 2x2 Grid": [(0, 0, 0.5, 0.5), (0.5, 0, 0.5, 0.5), (0, 0.5, 0.5, 0.5), (0.5, 0.5, 0.5, 0.5)],
            "6-Photo Grid": [
                (0, 0, 0.5, 1 / 3),
                (0.5, 0, 0.5, 1 / 3),
                (0, 1 / 3, 0.5, 1 / 3),
                (0.5, 1 / 3, 0.5, 1 / 3),
                (0, 2 / 3, 0.5, 1 / 3),
                (0.5, 2 / 3, 0.5, 1 / 3),
            ],
        }.get(layout, [(0, 0, 1, 1)])

        photos = [self.primary_image] + self.collage_images
        spacing = self.collage_spacing_var.get() if len(rects) > 1 else 0

        for idx, (nx, ny, nw, nh) in enumerate(rects):
            if idx >= len(photos):
                break
            x0 = int(nx * w + spacing // 2)
            y0 = int(ny * h + spacing // 2)
            x1 = int((nx + nw) * w - spacing // 2)
            y1 = int((ny + nh) * h - spacing // 2)
            sw, sh = max(8, x1 - x0), max(8, y1 - y0)
            src = self._apply_filter(photos[idx])
            if self.fit_mode_var.get() == "fill":
                fitted = ImageOps.fit(src, (sw, sh), Image.Resampling.LANCZOS)
            else:
                fitted = ImageOps.pad(src, (sw, sh), color=(255, 255, 255))
            canvas.paste(fitted, (x0, y0))

        # Apply Analog Creative FX (PolaroidEngine)
        canvas = apply_analog_fx(
            canvas,
            warmth=self.warmth_var.get(),
            vignette=self.vignette_var.get(),
            light_leak=self.leak_type_var.get(),
            leak_placement=self.leak_placement_var.get(),
            leak_intensity=self.leak_intensity_var.get(),
            film_grain=self.film_grain_var.get(),
            analog_wear=self.analog_wear_var.get(),
            show_vintage_date=self.vintage_date_var.get(),
            vintage_date_text=self.vintage_date_text_var.get(),
            vintage_date_color=self.vintage_date_color_var.get(),
            vintage_date_placement=self.vintage_date_placement_var.get(),
            seed=self.leak_auto_seed,
        )

        draw = ImageDraw.Draw(canvas)
        cap = self.caption_var.get().strip()
        if self.date_stamp_var.get():
            stamp = time.strftime("%Y.%m.%d")
            cap = f"{cap}  •  {stamp}" if cap else stamp
        if cap:
            bar_h = int(h * 0.08)
            draw.rectangle([0, h - bar_h, w, h], fill=(255, 255, 255))
            draw.text((24, h - bar_h + bar_h // 3), cap, fill=(25, 25, 25))

        if self.qr_type_var.get() != "Off" and self.qr_text_var.get().strip():
            self._draw_matrix_qr_badge(canvas, self.qr_text_var.get().strip())

        self.rendered_image = canvas
        disp_h = 410
        disp_w = int(disp_h * (w / h))
        disp = canvas.resize((disp_w, disp_h), Image.Resampling.LANCZOS)
        self.tk_preview = ImageTk.PhotoImage(disp)
        self.canvas_label.configure(image=self.tk_preview)
        self.canvas_label.image = self.tk_preview

    @staticmethod
    def _draw_matrix_qr_badge(canvas: Image.Image, text: str):
        draw = ImageDraw.Draw(canvas)
        w, h = canvas.size
        side = int(min(w, h) * 0.18)
        bx, by = w - side - 24, h - side - 24
        draw.rectangle([bx - 8, by - 8, bx + side + 8, by + side + 8], fill=(255, 255, 255), outline=(0, 0, 0))
        cells = 21
        cell_w = max(2, side // cells)
        digest = text.encode("utf-8")
        for r in range(cells):
            for c in range(cells):
                in_finder = (r < 7 and c < 7) or (r < 7 and c >= cells - 7) or (r >= cells - 7 and c < 7)
                if in_finder:
                    on = r in (0, 6, cells - 7, cells - 1) or c in (0, 6, cells - 7, cells - 1) or (2 <= r % (cells - 7) <= 4 and 2 <= c % (cells - 7) <= 4)
                else:
                    b_val = digest[(r * cells + c) % len(digest)]
                    on = ((b_val >> ((r + c) % 8)) & 1) == 1
                if on:
                    x0, y0 = bx + c * cell_w, by + r * cell_w
                    draw.rectangle([x0, y0, x0 + cell_w - 1, y0 + cell_w - 1], fill=(0, 0, 0))

    def query_status(self):
        def worker():
            try:
                client = LegacyInstaxClient(
                    host=self.ip_var.get().strip(),
                    port=int(self.port_var.get().strip() or 8080),
                    pin=int(self.pin_var.get().strip() or 1111),
                )
                st = client.get_printer_status()

                def on_ok():
                    self.is_connected = True
                    self.film_remaining = st["film"]
                    self.battery_level = st["battery"]
                    self.update_led_display()
                    self.status_var.set(
                        f"✅ Connected to {st['model']} ({st['firmware']}) • {st['film']}/10 Film Left • Battery {st['battery']}/4 • Total Prints: {st['total_prints']}"
                    )

                self.safe_after(on_ok)
            except Exception as exc:
                def on_err():
                    self.is_connected = False
                    self.film_remaining = None
                    self.battery_level = None
                    self.update_led_display()
                    self.status_var.set(f"❌ Connection Error: {exc}")

                self.safe_after(on_err)

        threading.Thread(target=worker, daemon=True).start()

    def start_print(self, force_dry_run: bool = False):
        if self.rendered_image is None:
            return
        dry = True if force_dry_run else self.dry_run_var.get()
        model = self.model_var.get()
        planar = encode_planar_rgb(self.rendered_image, model)

        def worker():
            try:
                client = LegacyInstaxClient(
                    host=self.ip_var.get().strip(),
                    port=int(self.port_var.get().strip() or 8080),
                    pin=int(self.pin_var.get().strip() or 1111),
                )
                res = client.print_planar_rgb(
                    planar,
                    model_name=model,
                    dry_run=dry,
                    progress_cb=lambda frac, msg: self.safe_after(lambda: self.status_var.set(f"[{int(frac * 100)}%] {msg}")),
                )

                def on_done():
                    self.is_connected = True
                    self.film_remaining = res["film"]
                    self.battery_level = res["battery"]
                    self.update_led_display()
                    if dry:
                        messagebox.showinfo("Dry Run Verified (0 Film Used)", f"All {len(planar) // 1000} KB verified by {model}! Film remaining: {res['film']}/10")

                self.safe_after(on_done)
            except Exception as exc:
                self.safe_after(lambda: self.status_var.set(f"❌ Print Error: {exc}"))

        threading.Thread(target=worker, daemon=True).start()


if __name__ == "__main__":
    app = LegacyInstaxPrinterGUI()
    app.mainloop()
