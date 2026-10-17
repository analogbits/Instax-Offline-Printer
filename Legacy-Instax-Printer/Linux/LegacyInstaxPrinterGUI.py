#!/usr/bin/env python3
"""
Legacy Instax Printer GUI (Windows & Linux) — Wi-Fi Direct Studio (SP-1 • SP-2 • SP-3)
======================================================================================
Complete offline desktop studio for Fujifilm Instax SHARE SP-1, SP-2, and SP-3 printers.
Features:
  - Wi-Fi Direct TCP Connection Bar (192.168.0.251:8080, PIN 1111)
  - Built-in Virtual SP-1 / SP-2 / SP-3 Simulator (127.0.0.1:18080)
  - Dry Run (0-Film Verification) Mode
  - Multi-Photo Collage Studio with live Border Spacing slider (0..28 px)
  - Scannable QR Code Generator & Overlay (URL, Text, Phone, Email, Wi-Fi, Location)
  - Fujifilm SHARE Artistic Filters & Exposure Controls
  - Exact Column-Major Planar RGB Encoder (600x800 Mini & 800x800 Square)
"""

import os
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

try:
    from PIL import Image, ImageDraw, ImageEnhance, ImageOps, ImageTk
except ImportError:
    raise SystemExit("Pillow is required. Install with: pip install pillow")

from legacy_instax_printer import (
    MODELS,
    LegacyInstaxClient,
    VirtualInstaxShareServer,
    encode_planar_rgb,
)


class LegacyInstaxPrinterGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Legacy Instax Printer — Wi-Fi Direct Studio (SP-1 • SP-2 • SP-3)")
        self.geometry("1160x760")
        self.minsize(1040, 680)
        self.configure(bg="#18181B")

        # State
        self.model_var = tk.StringVar(value="SP-2")
        self.ip_var = tk.StringVar(value="192.168.0.251")
        self.port_var = tk.StringVar(value="8080")
        self.pin_var = tk.StringVar(value="1111")
        self.sim_var = tk.BooleanVar(value=False)
        self.dry_run_var = tk.BooleanVar(value=False)

        self.fit_mode_var = tk.StringVar(value="fill")
        self.matte_var = tk.StringVar(value="#FFFFFF")
        self.filter_var = tk.StringVar(value="Normal")
        self.brightness_var = tk.DoubleVar(value=1.0)
        self.contrast_var = tk.DoubleVar(value=1.0)
        self.saturation_var = tk.DoubleVar(value=1.0)
        self.rotation_deg = 0

        self.collage_layout_var = tk.StringVar(value="Single")
        self.collage_spacing_var = tk.IntVar(value=8)
        self.collage_images = []

        self.qr_type_var = tk.StringVar(value="Off")
        self.qr_text_var = tk.StringVar(value="https://github.com/analogbits/Instax-Offline-Printer")
        self.qr_corner_var = tk.StringVar(value="Bottom Right")
        self.caption_var = tk.StringVar(value="")
        self.date_stamp_var = tk.BooleanVar(value=False)

        self.status_var = tk.StringVar(value="Ready — Join 'INSTAX-XXXXXXXX' Wi-Fi (192.168.0.251:8080, PIN 1111)")
        self.film_remaining = 10
        self.battery_level = 4

        self.sim_server = VirtualInstaxShareServer(port=18080, model="SP-2", pin=1111)
        self.primary_image = self._make_test_card("SP-2")
        self.rendered_image = None
        self.tk_preview = None

        self._build_ui()
        self.refresh_preview()

    def _build_ui(self):
        # Top Wi-Fi Bar
        top = tk.Frame(self, bg="#27272A", padx=12, pady=8)
        top.pack(fill=tk.X)

        tk.Label(top, text="📡 Legacy Instax Printer", fg="#F4F4F5", bg="#27272A", font=("Segoe UI", 12, "bold")).pack(side=tk.LEFT, padx=(0, 12))

        tk.Label(top, text="Model:", fg="#A1A1AA", bg="#27272A").pack(side=tk.LEFT)
        model_cb = ttk.Combobox(top, textvariable=self.model_var, values=["SP-1", "SP-2", "SP-3"], width=7, state="readonly")
        model_cb.pack(side=tk.LEFT, padx=6)
        model_cb.bind("<<ComboboxSelected>>", lambda _e: self.on_model_changed())

        tk.Label(top, text="IP:", fg="#A1A1AA", bg="#27272A").pack(side=tk.LEFT, padx=(8, 2))
        tk.Entry(top, textvariable=self.ip_var, width=14).pack(side=tk.LEFT, padx=2)

        tk.Label(top, text="Port:", fg="#A1A1AA", bg="#27272A").pack(side=tk.LEFT, padx=(6, 2))
        tk.Entry(top, textvariable=self.port_var, width=6).pack(side=tk.LEFT, padx=2)

        tk.Label(top, text="PIN:", fg="#A1A1AA", bg="#27272A").pack(side=tk.LEFT, padx=(6, 2))
        tk.Entry(top, textvariable=self.pin_var, width=6).pack(side=tk.LEFT, padx=2)

        tk.Button(top, text="Connect / Status", bg="#2563EB", fg="white", relief=tk.FLAT, padx=10, command=self.query_status).pack(side=tk.LEFT, padx=10)

        tk.Checkbutton(
            top,
            text="Virtual SP Simulator (127.0.0.1)",
            variable=self.sim_var,
            bg="#27272A",
            fg="#E4E4E7",
            selectcolor="#18181B",
            command=self.toggle_simulator,
        ).pack(side=tk.RIGHT, padx=6)

        tk.Checkbutton(
            top,
            text="Dry Run (0-Film Test)",
            variable=self.dry_run_var,
            bg="#27272A",
            fg="#FBBF24",
            selectcolor="#18181B",
        ).pack(side=tk.RIGHT, padx=6)

        # Main 3-Column Body
        body = tk.Frame(self, bg="#18181B")
        body.pack(fill=tk.BOTH, expand=True, padx=10, pady=8)

        # Left Panel
        left = tk.Frame(body, bg="#222226", width=230, padx=10, pady=10)
        left.pack(side=tk.LEFT, fill=tk.Y)
        left.pack_propagate(False)

        tk.Label(left, text="PHOTO SOURCE", fg="#A1A1AA", bg="#222226", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 6))
        tk.Button(left, text="📂 Open Image File...", bg="#3B82F6", fg="white", relief=tk.FLAT, pady=6, command=self.open_primary_image).pack(fill=tk.X, pady=3)
        tk.Button(left, text="✨ Generate Test Card", bg="#3F3F46", fg="white", relief=tk.FLAT, pady=5, command=self.reset_test_card).pack(fill=tk.X, pady=3)
        tk.Button(left, text="🔄 Rotate 90°", bg="#3F3F46", fg="white", relief=tk.FLAT, pady=5, command=self.rotate_image).pack(fill=tk.X, pady=3)

        tk.Label(left, text="\nWI-FI DIRECT GUIDE", fg="#A1A1AA", bg="#222226", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        guide = (
            "1. Power on your Instax SHARE\n   SP-1, SP-2, or SP-3 printer.\n"
            "2. Connect Wi-Fi to\n   'INSTAX-XXXXXXXX'.\n"
            "3. Default IP: 192.168.0.251\n   Port: 8080 • PIN: 1111\n"
            "4. Use Dry Run to verify full\n   data transfer with 0 film!"
        )
        tk.Label(left, text=guide, fg="#D4D4D8", bg="#222226", justify=tk.LEFT, font=("Segoe UI", 9)).pack(anchor="w", pady=6)

        # Center Preview Canvas
        center = tk.Frame(body, bg="#18181B", padx=14)
        center.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self.canvas_label = tk.Label(center, bg="#F5F5F0", bd=12, relief=tk.FLAT)
        self.canvas_label.pack(expand=True, pady=10)

        btn_bar = tk.Frame(center, bg="#18181B")
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

        # Right Inspector
        right = tk.Frame(body, bg="#222226", width=320, padx=12, pady=10)
        right.pack(side=tk.RIGHT, fill=tk.Y)
        right.pack_propagate(False)

        tk.Label(right, text="FRAMING & FILTERS", fg="#A1A1AA", bg="#222226", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        ttk.Combobox(right, textvariable=self.fit_mode_var, values=["fill", "fit"], state="readonly").pack(fill=tk.X, pady=4)
        self.fit_mode_var.trace_add("write", lambda *_: self.refresh_preview())

        ttk.Combobox(
            right,
            textvariable=self.filter_var,
            values=["Normal", "Fujifilm Intelligence", "Monochrome", "Sepia", "Vivid Velvia"],
            state="readonly",
        ).pack(fill=tk.X, pady=4)
        self.filter_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="MULTI-PHOTO COLLAGE", fg="#A1A1AA", bg="#222226", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(10, 2))
        ttk.Combobox(
            right,
            textvariable=self.collage_layout_var,
            values=["Single", "2-Up Vertical", "2-Up Horizontal", "3-Photo Grid", "4-Photo 2x2 Grid", "6-Photo Grid"],
            state="readonly",
        ).pack(fill=tk.X, pady=4)
        self.collage_layout_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="Collage Border Spacing (px):", fg="#D4D4D8", bg="#222226").pack(anchor="w")
        tk.Scale(
            right,
            from_=0,
            to=28,
            orient=tk.HORIZONTAL,
            variable=self.collage_spacing_var,
            bg="#222226",
            fg="white",
            highlightthickness=0,
            command=lambda _v: self.on_spacing_changed(),
        ).pack(fill=tk.X)

        c_btns = tk.Frame(right, bg="#222226")
        c_btns.pack(fill=tk.X, pady=4)
        tk.Button(c_btns, text="+ Add Collage Photos", bg="#3B82F6", fg="white", relief=tk.FLAT, command=self.add_collage_photos).pack(side=tk.LEFT, expand=True, fill=tk.X, padx=(0, 4))
        tk.Button(c_btns, text="Clear Slots", bg="#52525B", fg="white", relief=tk.FLAT, command=self.clear_collage_photos).pack(side=tk.LEFT)

        tk.Label(right, text="QR CODE & CAPTION", fg="#A1A1AA", bg="#222226", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(12, 2))
        ttk.Combobox(
            right,
            textvariable=self.qr_type_var,
            values=["Off", "Website URL", "Custom Text", "Phone Number", "Wi-Fi Access"],
            state="readonly",
        ).pack(fill=tk.X, pady=3)
        self.qr_type_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Entry(right, textvariable=self.qr_text_var).pack(fill=tk.X, pady=3)
        self.qr_text_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Label(right, text="Bottom Caption:", fg="#D4D4D8", bg="#222226").pack(anchor="w", pady=(6, 0))
        tk.Entry(right, textvariable=self.caption_var).pack(fill=tk.X, pady=3)
        self.caption_var.trace_add("write", lambda *_: self.refresh_preview())

        tk.Checkbutton(
            right,
            text="Include Date Stamp",
            variable=self.date_stamp_var,
            bg="#222226",
            fg="#D4D4D8",
            selectcolor="#18181B",
            command=self.refresh_preview,
        ).pack(anchor="w")

        # Bottom Status Bar
        status_bar = tk.Frame(self, bg="#27272A", padx=12, pady=6)
        status_bar.pack(fill=tk.X, side=tk.BOTTOM)
        tk.Label(status_bar, textvariable=self.status_var, fg="#E4E4E7", bg="#27272A", font=("Segoe UI", 9)).pack(side=tk.LEFT)

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
            self.status_var.set(f"🟢 Virtual Instax SHARE {self.model_var.get()} Simulator active at 127.0.0.1:18080")
        else:
            self.ip_var.set("192.168.0.251")
            self.port_var.set("8080")
            self.status_var.set("Switched to physical Instax SHARE Wi-Fi Direct (192.168.0.251:8080)")

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
                self.after(
                    0,
                    lambda: self.status_var.set(
                        f"✅ Connected to {st['model']} ({st['firmware']}) • {st['film']}/10 Film Left • Battery {st['battery']}/4 • Total Prints: {st['total_prints']}"
                    ),
                )
            except Exception as exc:
                self.after(0, lambda: self.status_var.set(f"❌ Connection Error: {exc}"))

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
                    progress_cb=lambda frac, msg: self.after(0, lambda: self.status_var.set(f"[{int(frac * 100)}%] {msg}")),
                )
                if dry:
                    self.after(0, lambda: messagebox.showinfo("Dry Run Verified (0 Film Used)", f"All {len(planar) // 1000} KB verified by {model}! Film remaining: {res['film']}/10"))
            except Exception as exc:
                self.after(0, lambda: self.status_var.set(f"❌ Print Error: {exc}"))

        threading.Thread(target=worker, daemon=True).start()


if __name__ == "__main__":
    app = LegacyInstaxPrinterGUI()
    app.mainloop()
