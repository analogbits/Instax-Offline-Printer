#!/usr/bin/env python3
"""
Instax Cross-Platform Desktop GUI (Windows & Linux)
Complete standalone application for Instax SQUARE Link, Link WIDE, and Mini Link.
"""

import os
import sys
import time
import threading
import asyncio
from typing import List, Optional
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, colorchooser
from PIL import Image, ImageTk, ImageOps, ImageEnhance

# Import core engine
try:
    from instax_printer import (
        InstaxBLE, render_image, DEFAULT_DEVICE_NAME, apply_analog_fx,
        STICKER_MAP, draw_decorative_frame, draw_sticker_overlay, draw_custom_banner
    )
except ImportError:
    from .instax_printer import (
        InstaxBLE, render_image, DEFAULT_DEVICE_NAME, apply_analog_fx,
        STICKER_MAP, draw_decorative_frame, draw_sticker_overlay, draw_custom_banner
    )

FRAME_OPTIONS = [
    ("none", "None (Standard Borderless)"),
    ("classic_white", "Classic White Film Border"),
    ("obsidian_black", "Obsidian Black Matte"),
    ("rainbow_gradient", "Rainbow Spectrum Gradient"),
    ("sunset_ombre", "Sunset Ombre (Rose/Orange/Indigo)"),
    ("sprocket_35mm", "35mm Vintage Film Sprockets"),
    ("gold_metallic", "Metallic Gold Foil"),
    ("rose_gold", "Rose Gold Shimmer"),
    ("pastel_pop", "Pastel Candy Geometric"),
    ("postage_stamp", "Scalloped Postage Stamp"),
    ("baroque_filigree", "Baroque Filigree Lace Oval"),
    ("wedding_corners", "Wedding Botanical Floral Corners"),
    ("stained_glass", "Leaded Stained Glass Mosaic"),
    ("bokeh_sparkles", "Glowing Golden Bokeh & Sparkles"),
    ("fireworks_celebration", "Night Sky Fireworks Burst"),
    ("twin_hearts_garland", "Hanging Twin Hearts Garland"),
    ("holiday_garland", "Festive Pine & Berry Garland"),
    ("botanical_foliage", "Autumn Botanical Leaves Border"),
]

BANNER_STYLE_OPTIONS = [
    ("none", "None (No Banner)"),
    ("ribbon", "🎀 3D Folded Ribbon"),
    ("calligraphy", "✒️ Calligraphy Brush"),
    ("pill", "💊 Frosted Pill Badge"),
    ("tag", "🏷️ Vintage Luggage Tag"),
    ("stamp", "📮 Postal Rubber Stamp"),
    ("garland", "🚩 Triangle Bunting Garland"),
]

BANNER_ICON_OPTIONS = [
    ("none", "None"),
    ("heart", "❤️ Heart"),
    ("sparkles", "✨ Sparkles"),
    ("party", "🎉 Party"),
    ("star", "⭐ Star"),
    ("camera", "📸 Camera"),
    ("cake", "🎂 Cake"),
    ("flower", "🌸 Flower"),
    ("ring", "💍 Ring"),
]

FILM_PRESET_OPTIONS = [
    ("default", "Default / Base (No Effects)"),
    ("none", "Custom / Manual (Unsaved)"),
    ("polaroid_sx70", "Polaroid SX-70 (1972 Warm Chemistry)"),
    ("polaroid_600", "Polaroid 600 (Classic 80s/90s Pop)"),
    ("polaroid_itype", "Polaroid I-Type / Modern Color"),
    ("polaroid_spectra", "Polaroid Spectra / Image System"),
    ("vintage_70s", "1970s Golden Vintage"),
    ("retro_80s", "1980s Retro Flash Pop"),
    ("pns_90s", "1990s Point & Shoot / Disposable"),
    ("mono_silver", "1960s Monochrome Silver Halide"),
    ("instax_rich", "🌈 instax-Rich (Vibrant High Contrast)"),
    ("instax_natural", "📷 instax-Natural (3D-LUT Fuji Emulation)"),
    ("instax_mono", "Instax Monochrome (B&W Street Film)"),
    ("instax_sepia", "Instax Warm Sepia (Nostalgic Tea Wash)"),
]

FILM_PRESETS = {
    "default": {
        "print_mode": "none", "filter": "none", "brightness": 0.00, "contrast": 1.00,
        "saturation": 1.00, "warmth": 0.00, "vignette": 0.00, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.00,
        "analog_wear": 0.00, "show_date": False, "date_color": "amber",
    },
    "polaroid_sx70": {
        "print_mode": "natural", "filter": "vintage", "brightness": 0.04, "contrast": 0.92,
        "saturation": 1.10, "warmth": 0.35, "vignette": 0.30, "light_leak": "sunburst",
        "leak_placement": "topRight", "leak_intensity": 0.35, "film_grain": 0.25,
        "analog_wear": 0.10, "show_date": False, "date_color": "amber",
    },
    "polaroid_600": {
        "print_mode": "rich", "filter": "none", "brightness": 0.02, "contrast": 1.20,
        "saturation": 1.25, "warmth": 0.15, "vignette": 0.45, "light_leak": "burn",
        "leak_placement": "left", "leak_intensity": 0.40, "film_grain": 0.35,
        "analog_wear": 0.15, "show_date": False, "date_color": "amber",
    },
    "polaroid_itype": {
        "print_mode": "rich", "filter": "none", "brightness": 0.00, "contrast": 1.10,
        "saturation": 1.15, "warmth": 0.05, "vignette": 0.20, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.15,
        "analog_wear": 0.00, "show_date": False, "date_color": "amber",
    },
    "polaroid_spectra": {
        "print_mode": "natural", "filter": "none", "brightness": 0.03, "contrast": 1.05,
        "saturation": 1.10, "warmth": 0.25, "vignette": 0.35, "light_leak": "sunset",
        "leak_placement": "right", "leak_intensity": 0.30, "film_grain": 0.20,
        "analog_wear": 0.05, "show_date": False, "date_color": "amber",
    },
    "vintage_70s": {
        "print_mode": "natural", "filter": "vintage", "brightness": 0.06, "contrast": 0.88,
        "saturation": 0.90, "warmth": 0.55, "vignette": 0.50, "light_leak": "sunburst",
        "leak_placement": "topRight", "leak_intensity": 0.60, "film_grain": 0.45,
        "analog_wear": 0.30, "show_date": False, "date_color": "amber",
    },
    "retro_80s": {
        "print_mode": "rich", "filter": "vivid", "brightness": 0.05, "contrast": 1.30,
        "saturation": 1.40, "warmth": -0.10, "vignette": 0.40, "light_leak": "rainbow",
        "leak_placement": "diagonal", "leak_intensity": 0.50, "film_grain": 0.40,
        "analog_wear": 0.15, "show_date": True, "date_color": "red",
    },
    "pns_90s": {
        "print_mode": "rich", "filter": "none", "brightness": 0.02, "contrast": 1.18,
        "saturation": 1.15, "warmth": 0.15, "vignette": 0.55, "light_leak": "burn",
        "leak_placement": "right", "leak_intensity": 0.35, "film_grain": 0.35,
        "analog_wear": 0.10, "show_date": True, "date_color": "amber",
    },
    "mono_silver": {
        "print_mode": "natural", "filter": "monochrome", "brightness": 0.00, "contrast": 1.35,
        "saturation": 0.00, "warmth": 0.00, "vignette": 0.40, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.60,
        "analog_wear": 0.20, "show_date": False, "date_color": "white",
    },
    "instax_rich": {
        "print_mode": "rich", "filter": "none", "brightness": 0.00, "contrast": 1.00,
        "saturation": 1.00, "warmth": 0.00, "vignette": 0.00, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.00,
        "analog_wear": 0.00, "show_date": False, "date_color": "amber",
    },
    "instax_natural": {
        "print_mode": "natural", "filter": "none", "brightness": 0.00, "contrast": 1.00,
        "saturation": 1.00, "warmth": 0.00, "vignette": 0.00, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.00,
        "analog_wear": 0.00, "show_date": False, "date_color": "amber",
    },
    "instax_mono": {
        "print_mode": "rich", "filter": "monochrome", "brightness": 0.00, "contrast": 1.15,
        "saturation": 0.00, "warmth": 0.00, "vignette": 0.15, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.25,
        "analog_wear": 0.00, "show_date": False, "date_color": "amber",
    },
    "instax_sepia": {
        "print_mode": "natural", "filter": "sepia", "brightness": 0.02, "contrast": 1.05,
        "saturation": 0.70, "warmth": 0.40, "vignette": 0.25, "light_leak": "none",
        "leak_placement": "auto", "leak_intensity": 0.70, "film_grain": 0.20,
        "analog_wear": 0.05, "show_date": False, "date_color": "amber",
    },
}

class InstaxDesktopApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Instax Offline Printer (Windows & Linux)")
        self.geometry("1120x760")
        self.minsize(980, 680)

        # Style configuration
        self.style = ttk.Style()
        try:
            self.style.theme_use("clam")
        except Exception:
            pass

        # State
        self.ble = InstaxBLE(log_callback=self.on_log)
        self.loop = asyncio.new_event_loop()
        self.ble_thread = threading.Thread(target=self._run_async_loop, daemon=True)
        self.ble_thread.start()

        self.target_device = tk.StringVar(value=DEFAULT_DEVICE_NAME)
        self.discovered_printers: List[dict] = []
        self.is_connected = False
        self.connected_name = ""
        self.is_printing = False

        # Model resolution (square: 800x800, wide: 1260x840, mini: 600x800)
        self.selected_model = tk.StringVar(value="SQUARE")
        self.model_configs = {
            "SQUARE": {"width": 800, "height": 800, "preview_w": 380, "preview_h": 380, "name": "Instax SQUARE Link"},
            "WIDE": {"width": 1260, "height": 840, "preview_w": 460, "preview_h": 307, "name": "Instax Link WIDE / WIDE 2"},
            "MINI": {"width": 600, "height": 800, "preview_w": 300, "preview_h": 400, "name": "Instax Mini Link (1/2/3/Link+)"}
        }

        # Hardware readings
        self.film_remaining = tk.StringVar(value="Film: --/10")
        self.battery_info = tk.StringVar(value="Battery: --%")

        # Image state
        self.source_image: Optional[Image.Image] = None
        self.source_image_name = "Sample Card"
        self.fit_mode = tk.StringVar(value="crop")
        self.bg_color = "#FFFFFF"
        self.zoom = tk.DoubleVar(value=1.0)
        self.pan_x = tk.DoubleVar(value=0.0)
        self.pan_y = tk.DoubleVar(value=0.0)
        self.rotation = tk.IntVar(value=0)
        self.print_mode = tk.StringVar(value="none")
        self.brightness = tk.DoubleVar(value=0.0)
        self.contrast = tk.DoubleVar(value=1.0)
        self.saturation = tk.DoubleVar(value=1.0)
        self.filter_preset = tk.StringVar(value="none")

        # Analog Creative FX State (Ported from PolaroidEngine)
        self.warmth = tk.DoubleVar(value=0.0)
        self.vignette = tk.DoubleVar(value=0.0)
        self.light_leak = tk.StringVar(value="none")
        self.leak_placement = tk.StringVar(value="auto")
        self.leak_intensity = tk.DoubleVar(value=0.70)
        self.film_grain = tk.DoubleVar(value=0.0)
        self.analog_wear = tk.DoubleVar(value=0.0)
        self.show_vintage_date = tk.BooleanVar(value=False)
        self.vintage_date_text = tk.StringVar(value="")
        self.vintage_date_color = tk.StringVar(value="amber")
        self.vintage_date_placement = tk.StringVar(value="bottomRight")
        self.leak_auto_seed = 12345

        # Stickers & Decorative Frames State
        self.frame_style = tk.StringVar(value="none")
        self.sticker = tk.StringVar(value="none")
        self.custom_sticker_path = tk.StringVar(value="")
        self.custom_sticker_img: Optional[Image.Image] = None
        self.sticker_position = tk.StringVar(value="topRight")
        self.sticker_scale = tk.DoubleVar(value=0.25)
        self.sticker_opacity = tk.DoubleVar(value=1.0)
        self.sticker_rotation = tk.DoubleVar(value=0.0)
        self.sticker_pos_x = tk.DoubleVar(value=0.65)
        self.sticker_pos_y = tk.DoubleVar(value=0.65)
        self.drag_focus_mode = tk.StringVar(value="auto")

        # Custom Banner Maker State
        self.banner_text = tk.StringVar(value="")
        self.banner_style = tk.StringVar(value="none")
        self.banner_icon = tk.StringVar(value="none")
        self.banner_color = tk.StringVar(value="#e11d48")
        self.banner_text_color = tk.StringVar(value="#ffffff")
        self.banner_pos_x = tk.DoubleVar(value=0.0)
        self.banner_pos_y = tk.DoubleVar(value=0.68)
        self.banner_scale = tk.DoubleVar(value=1.0)
        self.banner_rotation = tk.DoubleVar(value=0.0)

        # Film Preset Emulation State
        self.film_preset_var = tk.StringVar(value="Default / Base (No Effects)")
        self._is_applying_preset = False

        # Drag tracking
        self.drag_start_x = 0
        self.drag_start_y = 0
        self.drag_target = "pan"

        # Queue
        self.queue: List[dict] = []
        self.selected_queue_idx = -1

        # Logs
        self.log_entries: List[str] = []

        self._build_ui()
        self._load_sample_image()

    def _run_async_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    def run_coro(self, coro):
        return asyncio.run_coroutine_threadsafe(coro, self.loop)

    def on_log(self, msg: str):
        self.log_entries.append(msg)
        if hasattr(self, "log_text") and self.log_text:
            self.after(0, self._append_log_text, msg)

    def _append_log_text(self, msg: str):
        if hasattr(self, "log_text"):
            self.log_text.insert(tk.END, msg + "\n")
            self.log_text.see(tk.END)

    def _build_ui(self):
        # 1. Top Header Bar
        top_bar = ttk.Frame(self, padding=8)
        top_bar.pack(side=tk.TOP, fill=tk.X)

        self.lbl_status_icon = ttk.Label(top_bar, text="●", font=("Arial", 16), foreground="gray")
        self.lbl_status_icon.pack(side=tk.LEFT, padx=(4, 6))

        ttk.Label(top_bar, text="Printer:", font=("Arial", 10, "bold")).pack(side=tk.LEFT, padx=(0, 4))
        self.cb_printers = ttk.Combobox(top_bar, textvariable=self.target_device, width=18)
        self.cb_printers["values"] = [DEFAULT_DEVICE_NAME]
        self.cb_printers.pack(side=tk.LEFT, padx=4)

        btn_scan = ttk.Button(top_bar, text="Scan", command=self.action_scan)
        btn_scan.pack(side=tk.LEFT, padx=2)

        self.btn_connect = ttk.Button(top_bar, text="Connect", command=self.action_toggle_connect)
        self.btn_connect.pack(side=tk.LEFT, padx=4)

        btn_refresh = ttk.Button(top_bar, text="Status", command=self.action_refresh_status)
        btn_refresh.pack(side=tk.LEFT, padx=2)

        ttk.Separator(top_bar, orient=tk.VERTICAL).pack(side=tk.LEFT, fill=tk.Y, padx=8)

        ttk.Label(top_bar, text="Format:").pack(side=tk.LEFT, padx=(0, 4))
        for m in ["SQUARE", "WIDE", "MINI"]:
            rb = ttk.Radiobutton(top_bar, text=m, value=m, variable=self.selected_model, command=self.update_preview)
            rb.pack(side=tk.LEFT, padx=2)

        ttk.Separator(top_bar, orient=tk.VERTICAL).pack(side=tk.LEFT, fill=tk.Y, padx=8)

        btn_flash = ttk.Button(top_bar, text="Flash LED", command=self.action_flash_led)
        btn_flash.pack(side=tk.LEFT, padx=2)

        btn_stop_led = ttk.Button(top_bar, text="Stop LED", command=self.action_stop_led)
        btn_stop_led.pack(side=tk.LEFT, padx=2)

        # Right side indicators
        lbl_film = ttk.Label(top_bar, textvariable=self.film_remaining, font=("Arial", 10, "bold"), foreground="#007ACC")
        lbl_film.pack(side=tk.RIGHT, padx=6)
        lbl_batt = ttk.Label(top_bar, textvariable=self.battery_info, font=("Arial", 10))
        lbl_batt.pack(side=tk.RIGHT, padx=6)

        ttk.Separator(self, orient=tk.HORIZONTAL).pack(side=tk.TOP, fill=tk.X)

        # 2. Middle: Left Preview / Right Controls
        middle_paned = ttk.PanedWindow(self, orient=tk.HORIZONTAL)
        middle_paned.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        # Left Preview Frame
        preview_container = ttk.Frame(middle_paned, padding=10)
        middle_paned.add(preview_container, weight=3)

        self.canvas = tk.Canvas(preview_container, bg="#1E1E1E", highlightthickness=1, highlightbackground="#444")
        self.canvas.pack(fill=tk.BOTH, expand=True)
        self.canvas.bind("<ButtonPress-1>", self._on_canvas_press)
        self.canvas.bind("<B1-Motion>", self._on_canvas_drag)

        # Drag Focus Mode Control Bar
        drag_bar = ttk.Frame(preview_container, padding=2)
        drag_bar.pack(side=tk.BOTTOM, fill=tk.X)
        ttk.Label(drag_bar, text="Drag Target:", font=("TkDefaultFont", 8, "bold")).pack(side=tk.LEFT, padx=4)
        for val, txt in [("auto", "🎯 Auto"), ("pan", "🖼️ Photo"), ("sticker", "🎨 Sticker"), ("banner", "🎀 Banner")]:
            ttk.Radiobutton(drag_bar, text=txt, variable=self.drag_focus_mode, value=val).pack(side=tk.LEFT, padx=3)

        # Quick Preview Action Buttons
        prev_btn_bar = ttk.Frame(preview_container, padding=6)
        prev_btn_bar.pack(side=tk.BOTTOM, fill=tk.X)

        btn_open = ttk.Button(prev_btn_bar, text="Add Photos...", command=self.action_open_files)
        btn_open.pack(side=tk.LEFT, padx=4)

        btn_rot_ccw = ttk.Button(prev_btn_bar, text="Rotate ↺", command=lambda: self.action_rotate(-90))
        btn_rot_ccw.pack(side=tk.LEFT, padx=2)

        btn_rot_cw = ttk.Button(prev_btn_bar, text="Rotate ↻", command=lambda: self.action_rotate(90))
        btn_rot_cw.pack(side=tk.LEFT, padx=2)

        btn_reset = ttk.Button(prev_btn_bar, text="Center & Reset", command=self.action_reset_adjustments)
        btn_reset.pack(side=tk.LEFT, padx=4)

        self.lbl_info = ttk.Label(prev_btn_bar, text="Drag to pan photo inside canvas", foreground="gray")
        self.lbl_info.pack(side=tk.RIGHT, padx=6)

        # Right Controls Sidebar
        sidebar = ttk.Notebook(middle_paned)
        middle_paned.add(sidebar, weight=1)

        # Tab 1: Framing
        tab_framing = ttk.Frame(sidebar, padding=12)
        sidebar.add(tab_framing, text="Framing")

        ttk.Label(tab_framing, text="Fit Mode:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 4))
        for mode, txt in [("crop", "Fill (Crop)"), ("fit", "Fit (Letterbox)"), ("stretch", "Stretch")]:
            ttk.Radiobutton(tab_framing, text=txt, value=mode, variable=self.fit_mode, command=self.update_preview).pack(anchor=tk.W)

        btn_color = ttk.Button(tab_framing, text="Letterbox Color...", command=self.action_choose_bg_color)
        btn_color.pack(anchor=tk.W, pady=6)

        ttk.Label(tab_framing, text="Zoom:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        s_zoom = ttk.Scale(tab_framing, from_=0.5, to=2.5, variable=self.zoom, command=lambda e: self.update_preview())
        s_zoom.pack(fill=tk.X)

        ttk.Label(tab_framing, text="Horizontal Pan:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        s_panx = ttk.Scale(tab_framing, from_=-1.0, to=1.0, variable=self.pan_x, command=lambda e: self.update_preview())
        s_panx.pack(fill=tk.X)

        ttk.Label(tab_framing, text="Vertical Pan:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        s_pany = ttk.Scale(tab_framing, from_=-1.0, to=1.0, variable=self.pan_y, command=lambda e: self.update_preview())
        s_pany.pack(fill=tk.X)

        # Tab 2: Color & Modes
        tab_color = ttk.Frame(sidebar, padding=12)
        sidebar.add(tab_color, text="Color & Film")

        ttk.Label(tab_color, text="Film Preset Emulation:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 2))
        cb_preset_col = ttk.Combobox(tab_color, textvariable=self.film_preset_var, values=[t for _, t in FILM_PRESET_OPTIONS], state="readonly")
        cb_preset_col.bind("<<ComboboxSelected>>", self.on_film_preset_changed)
        cb_preset_col.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(tab_color, text="Print Mode:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 4))
        ttk.Radiobutton(tab_color, text="Standard / Neutral (No Profile)", value="none", variable=self.print_mode, command=self.on_control_adjusted).pack(anchor=tk.W)
        ttk.Radiobutton(tab_color, text="instax-Rich Mode (Vibrant Pop)", value="rich", variable=self.print_mode, command=self.on_control_adjusted).pack(anchor=tk.W)
        ttk.Radiobutton(tab_color, text="instax-Natural (Classic 3D-LUT)", value="natural", variable=self.print_mode, command=self.on_control_adjusted).pack(anchor=tk.W)

        ttk.Label(tab_color, text="Filter Preset:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(10, 4))
        cb_filt = ttk.Combobox(tab_color, textvariable=self.filter_preset, values=["none", "monochrome", "sepia", "vintage", "vivid"])
        cb_filt.bind("<<ComboboxSelected>>", lambda e: self.on_control_adjusted())
        cb_filt.pack(fill=tk.X)

        ttk.Label(tab_color, text="Brightness:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=-0.5, to=0.5, variable=self.brightness, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_color, text="Contrast:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=0.5, to=1.5, variable=self.contrast, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_color, text="Saturation:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=0.0, to=2.0, variable=self.saturation, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        # Tab 3: Analog FX
        tab_analog = ttk.Frame(sidebar, padding=12)
        sidebar.add(tab_analog, text="Analog FX")

        ttk.Label(tab_analog, text="Film Preset Emulation:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 2))
        cb_preset_ana = ttk.Combobox(tab_analog, textvariable=self.film_preset_var, values=[t for _, t in FILM_PRESET_OPTIONS], state="readonly")
        cb_preset_ana.bind("<<ComboboxSelected>>", self.on_film_preset_changed)
        cb_preset_ana.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(tab_analog, text="Warmth Dial (-1.0 to +1.0):", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 2))
        ttk.Scale(tab_analog, from_=-1.0, to=1.0, variable=self.warmth, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_analog, text="Lens Vignette Falloff:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_analog, from_=0.0, to=1.0, variable=self.vignette, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_analog, text="Light Leak Type:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        cb_leak = ttk.Combobox(tab_analog, textvariable=self.light_leak, values=["none", "burn", "sunburst", "sunset", "rainbow"], state="readonly")
        cb_leak.bind("<<ComboboxSelected>>", lambda e: self.on_control_adjusted())
        cb_leak.pack(fill=tk.X)

        ttk.Label(tab_analog, text="Leak Placement:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(6, 2))
        f_place = ttk.Frame(tab_analog)
        f_place.pack(fill=tk.X)
        cb_place = ttk.Combobox(f_place, textvariable=self.leak_placement, values=["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"], state="readonly")
        cb_place.bind("<<ComboboxSelected>>", lambda e: (self.on_leak_placement_selected(e), self.on_control_adjusted()))
        cb_place.pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(f_place, text="🎲", width=3, command=lambda: (self.roll_auto_leak(), self.on_control_adjusted())).pack(side=tk.LEFT, padx=(4, 0))

        ttk.Label(tab_analog, text="Leak Intensity:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(6, 2))
        ttk.Scale(tab_analog, from_=0.1, to=1.0, variable=self.leak_intensity, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_analog, text="Silver Halide Grain:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_analog, from_=0.0, to=1.0, variable=self.film_grain, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Label(tab_analog, text="Analog Wear & Dust:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_analog, from_=0.0, to=1.0, variable=self.analog_wear, command=lambda e: self.on_control_adjusted()).pack(fill=tk.X)

        ttk.Checkbutton(tab_analog, text="Glowing LED Date Stamp", variable=self.show_vintage_date, command=self.on_control_adjusted).pack(anchor=tk.W, pady=(10, 4))
        date_sub = ttk.Frame(tab_analog)
        date_sub.pack(fill=tk.X)
        ttk.Label(date_sub, text="Text:").pack(side=tk.LEFT)
        e_date = ttk.Entry(date_sub, textvariable=self.vintage_date_text, width=12)
        e_date.bind("<KeyRelease>", lambda e: self.on_control_adjusted())
        e_date.pack(side=tk.LEFT, padx=4)
        cb_date_c = ttk.Combobox(date_sub, textvariable=self.vintage_date_color, values=["amber", "red", "green", "white"], width=7, state="readonly")
        cb_date_c.bind("<<ComboboxSelected>>", lambda e: self.on_control_adjusted())
        cb_date_c.pack(side=tk.LEFT, padx=2)

        fx_btns = ttk.Frame(tab_analog)
        fx_btns.pack(fill=tk.X, pady=(12, 0))
        ttk.Button(fx_btns, text="🎲 Surprise Me!", command=self.action_surprise_me_analog_fx).pack(side=tk.LEFT)
        ttk.Button(fx_btns, text="Reset FX", command=self.action_reset_analog_fx).pack(side=tk.RIGHT)

        # Tab 4: Stickers & Borders
        tab_decor_outer = ttk.Frame(sidebar)
        sidebar.add(tab_decor_outer, text="Stickers & Borders")
        decor_canvas = tk.Canvas(tab_decor_outer, highlightthickness=0)
        decor_scroll = ttk.Scrollbar(tab_decor_outer, orient="vertical", command=decor_canvas.yview)
        tab_decor = ttk.Frame(decor_canvas, padding=10)
        tab_decor.bind("<Configure>", lambda e: decor_canvas.configure(scrollregion=decor_canvas.bbox("all")))
        decor_canvas.create_window((0, 0), window=tab_decor, anchor="nw")
        decor_canvas.configure(yscrollcommand=decor_scroll.set)
        decor_canvas.pack(side="left", fill="both", expand=True)
        decor_scroll.pack(side="right", fill="y")

        ttk.Label(tab_decor, text="Decorative Film Frame:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 2))
        self.cb_frames = ttk.Combobox(
            tab_decor,
            values=[t for _, t in FRAME_OPTIONS],
            state="readonly"
        )
        self.cb_frames.set(FRAME_OPTIONS[0][1])
        def _on_frame_sel(e):
            sel_idx = self.cb_frames.current()
            if 0 <= sel_idx < len(FRAME_OPTIONS):
                self.frame_style.set(FRAME_OPTIONS[sel_idx][0])
                self.update_preview()
        self.cb_frames.bind("<<ComboboxSelected>>", _on_frame_sel)
        self.cb_frames.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(tab_decor, text="Emoji & Doodle Sticker:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(4, 2))
        self.sticker_list = [("none", "None (No Sticker)")] + [(k, f"{STICKER_MAP[k]}  {k.replace('_', ' ').title()}") for k in STICKER_MAP.keys()]
        self.cb_stickers = ttk.Combobox(
            tab_decor,
            values=[t for _, t in self.sticker_list],
            state="readonly"
        )
        self.cb_stickers.set("None (No Sticker)")
        def _on_sticker_sel(e):
            sel_idx = self.cb_stickers.current()
            if 0 <= sel_idx < len(self.sticker_list):
                self.sticker.set(self.sticker_list[sel_idx][0])
                self.update_preview()
        self.cb_stickers.bind("<<ComboboxSelected>>", _on_sticker_sel)
        self.cb_stickers.pack(fill=tk.X, pady=(0, 6))

        # Quick emoji sticker chips
        f_quick = ttk.Frame(tab_decor)
        f_quick.pack(fill=tk.X, pady=(0, 8))
        quick_emojis = [("🎉", "party_popper"), ("🎂", "birthday_cake"), ("✨", "sparkles"), ("📸", "camera"), ("🌴", "palm_tree"), ("☀️", "sun"), ("❤️", "heart"), ("💖", "sparkle_heart"), ("🐾", "paw"), ("🕶️", "sunglasses")]
        for em, k in quick_emojis:
            ttk.Button(f_quick, text=em, width=3, command=lambda key=k: (self.sticker.set(key), self._sync_sticker_cb(key), self.update_preview())).pack(side=tk.LEFT, padx=1)

        ttk.Label(tab_decor, text="Custom Image / Logo Overlay:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(6, 2))
        f_custom = ttk.Frame(tab_decor)
        f_custom.pack(fill=tk.X, pady=(0, 8))
        self.btn_cust_label = ttk.Button(f_custom, text="Choose Image...", command=self.action_choose_custom_sticker)
        self.btn_cust_label.pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(f_custom, text="✕", width=3, command=self.action_clear_custom_sticker).pack(side=tk.LEFT, padx=(4, 0))

        ttk.Label(tab_decor, text="Sticker Position Preset:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(4, 2))
        cb_pos = ttk.Combobox(
            tab_decor,
            textvariable=self.sticker_position,
            values=["topRight", "topLeft", "bottomRight", "bottomLeft", "center", "topCenter", "bottomCenter", "custom"],
            state="readonly"
        )
        cb_pos.bind("<<ComboboxSelected>>", self._on_sticker_preset_change)
        cb_pos.pack(fill=tk.X, pady=(0, 6))

        ttk.Label(tab_decor, text="Sticker X Offset (-1.0 to 1.0):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-1.0, to=1.0, variable=self.sticker_pos_x, command=lambda e: (self.sticker_position.set("custom"), self.update_preview())).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Sticker Y Offset (-1.0 to 1.0):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-1.0, to=1.0, variable=self.sticker_pos_y, command=lambda e: (self.sticker_position.set("custom"), self.update_preview())).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Sticker Scale:", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=0.10, to=0.60, variable=self.sticker_scale, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Sticker Opacity:", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=0.10, to=1.0, variable=self.sticker_opacity, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Sticker Rotation Angle (°):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-180.0, to=180.0, variable=self.sticker_rotation, command=lambda e: self.update_preview()).pack(fill=tk.X)

        # Custom Banner Maker Group
        ttk.Separator(tab_decor, orient="horizontal").pack(fill=tk.X, pady=10)
        ttk.Label(tab_decor, text="─── Custom Banner Maker ───", font=("Arial", 9, "bold")).pack(anchor=tk.CENTER, pady=(0, 6))

        ttk.Label(tab_decor, text="Banner Message:").pack(anchor=tk.W)
        e_banner = ttk.Entry(tab_decor, textvariable=self.banner_text)
        e_banner.bind("<KeyRelease>", lambda e: self.update_preview())
        e_banner.pack(fill=tk.X, pady=(0, 4))

        ttk.Label(tab_decor, text="Banner Style:").pack(anchor=tk.W)
        self.cb_bstyle = ttk.Combobox(tab_decor, values=[t for _, t in BANNER_STYLE_OPTIONS], state="readonly")
        self.cb_bstyle.set(BANNER_STYLE_OPTIONS[0][1])
        def _on_bstyle_sel(e):
            idx = self.cb_bstyle.current()
            if 0 <= idx < len(BANNER_STYLE_OPTIONS):
                self.banner_style.set(BANNER_STYLE_OPTIONS[idx][0])
                self.update_preview()
        self.cb_bstyle.bind("<<ComboboxSelected>>", _on_bstyle_sel)
        self.cb_bstyle.pack(fill=tk.X, pady=(0, 4))

        ttk.Label(tab_decor, text="Banner Icon:").pack(anchor=tk.W)
        self.cb_bicon = ttk.Combobox(tab_decor, values=[t for _, t in BANNER_ICON_OPTIONS], state="readonly")
        self.cb_bicon.set(BANNER_ICON_OPTIONS[0][1])
        def _on_bicon_sel(e):
            idx = self.cb_bicon.current()
            if 0 <= idx < len(BANNER_ICON_OPTIONS):
                self.banner_icon.set(BANNER_ICON_OPTIONS[idx][0])
                self.update_preview()
        self.cb_bicon.bind("<<ComboboxSelected>>", _on_bicon_sel)
        self.cb_bicon.pack(fill=tk.X, pady=(0, 4))

        f_bcolors = ttk.Frame(tab_decor)
        f_bcolors.pack(fill=tk.X, pady=(2, 6))
        ttk.Label(f_bcolors, text="Bg:").pack(side=tk.LEFT)
        e_bg = ttk.Entry(f_bcolors, textvariable=self.banner_color, width=9)
        e_bg.bind("<KeyRelease>", lambda e: self.update_preview())
        e_bg.pack(side=tk.LEFT, padx=2)
        ttk.Button(f_bcolors, text="🎨", width=3, command=self.action_choose_banner_bg_color).pack(side=tk.LEFT, padx=1)
        ttk.Label(f_bcolors, text="Text:").pack(side=tk.LEFT, padx=(4, 0))
        e_tx = ttk.Entry(f_bcolors, textvariable=self.banner_text_color, width=9)
        e_tx.bind("<KeyRelease>", lambda e: self.update_preview())
        e_tx.pack(side=tk.LEFT, padx=2)

        ttk.Label(tab_decor, text="Banner X Offset (-1.0 to 1.0):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-1.0, to=1.0, variable=self.banner_pos_x, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Banner Y Offset (-1.0 to 1.0):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-1.0, to=1.0, variable=self.banner_pos_y, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Banner Scale:", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=0.5, to=2.0, variable=self.banner_scale, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_decor, text="Banner Rotation (°):", font=("Arial", 8)).pack(anchor=tk.W)
        ttk.Scale(tab_decor, from_=-180.0, to=180.0, variable=self.banner_rotation, command=lambda e: self.update_preview()).pack(fill=tk.X)

        f_decor_btns = ttk.Frame(tab_decor)
        f_decor_btns.pack(fill=tk.X, pady=(12, 0))
        ttk.Button(f_decor_btns, text="Reset Borders, Stickers & Banners", command=self.action_reset_decor).pack(side=tk.RIGHT)

        # Tab 5: Protocol Debug
        tab_debug = ttk.Frame(sidebar, padding=8)
        sidebar.add(tab_debug, text="Debug Log")

        self.log_text = tk.Text(tab_debug, bg="#121212", fg="#00FF66", font=("Consolas", 8), wrap=tk.NONE)
        self.log_text.pack(fill=tk.BOTH, expand=True)

        btn_clr_log = ttk.Button(tab_debug, text="Clear Log", command=lambda: self.log_text.delete("1.0", tk.END))
        btn_clr_log.pack(side=tk.BOTTOM, fill=tk.X, pady=4)

        # 3. Bottom Bulk Queue Strip
        queue_frame = ttk.Frame(self, padding=8)
        queue_frame.pack(side=tk.BOTTOM, fill=tk.X)

        q_head = ttk.Frame(queue_frame)
        q_head.pack(fill=tk.X)
        ttk.Label(q_head, text="Bulk Print Queue", font=("Arial", 10, "bold")).pack(side=tk.LEFT)

        btn_clear_q = ttk.Button(q_head, text="Clear Queue", command=self.action_clear_queue)
        btn_clear_q.pack(side=tk.RIGHT, padx=4)

        self.btn_bulk_print = ttk.Button(q_head, text="Print Bulk Queue", command=self.action_bulk_print)
        self.btn_bulk_print.pack(side=tk.RIGHT, padx=4)

        self.btn_print_one = ttk.Button(q_head, text="Print Current Photo", command=self.action_print_selected)
        self.btn_print_one.pack(side=tk.RIGHT, padx=4)

        # Queue Listbox
        self.queue_listbox = tk.Listbox(queue_frame, height=4, font=("Arial", 9), selectmode=tk.SINGLE)
        self.queue_listbox.pack(fill=tk.X, pady=4)
        self.queue_listbox.bind("<<ListboxSelect>>", self._on_queue_select)

        # Progress bar & Status footer
        footer = ttk.Frame(queue_frame)
        footer.pack(fill=tk.X, pady=(2, 0))

        self.lbl_status = ttk.Label(footer, text="Ready — Connect printer and add photos to print.")
        self.lbl_status.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.progress_bar = ttk.Progressview if hasattr(ttk, "Progressview") else ttk.Progressbar(footer, mode="determinate", length=220)
        self.progress_bar.pack(side=tk.RIGHT, padx=4)

    def _load_sample_image(self):
        w = 800
        h = 800
        img = Image.new("RGB", (w, h), (40, 44, 52))
        self.source_image = img
        self.source_image_name = "Sample Card"
        self.queue.append({"name": "Sample Card", "path": None, "image": img})
        self._refresh_queue_listbox()
        self.update_preview()

    def _on_sticker_preset_change(self, *args):
        pos = self.sticker_position.get()
        if pos != "custom":
            preset_map = {
                "topLeft": (-0.68, -0.68),
                "topRight": (0.68, -0.68),
                "bottomLeft": (-0.68, 0.68),
                "bottomRight": (0.68, 0.68),
                "center": (0.0, 0.0),
                "topCenter": (0.0, -0.68),
                "bottomCenter": (0.0, 0.68),
            }
            if pos in preset_map:
                x, y = preset_map[pos]
                self.sticker_pos_x.set(x)
                self.sticker_pos_y.set(y)
        self.update_preview()

    def _on_canvas_press(self, event):
        self.drag_start_x = event.x
        self.drag_start_y = event.y
        cfg = self.model_configs.get(self.selected_model.get(), self.model_configs["SQUARE"])
        cv_w = self.canvas.winfo_width()
        cv_h = self.canvas.winfo_height()
        if cv_w < 50: cv_w = 400
        if cv_h < 50: cv_h = 400
        cx = cv_w // 2
        cy = cv_h // 2
        cw = cfg["preview_w"]
        ch = cfg["preview_h"]
        norm_x = (event.x - cx) / max(1.0, cw / 2.0)
        norm_y = (event.y - cy) / max(1.0, ch / 2.0)

        has_sticker = (self.sticker.get() != "none" or self.custom_sticker_img is not None)
        has_banner = (bool(self.banner_text.get().strip()) and self.banner_style.get() != "none")

        st_pos = self.sticker_position.get()
        if st_pos == "custom":
            eff_st_x = self.sticker_pos_x.get()
            eff_st_y = self.sticker_pos_y.get()
        else:
            preset_map = {
                "topLeft": (-0.68, -0.68),
                "topRight": (0.68, -0.68),
                "bottomLeft": (-0.68, 0.68),
                "bottomRight": (0.68, 0.68),
                "center": (0.0, 0.0),
                "topCenter": (0.0, -0.68),
                "bottomCenter": (0.0, 0.68),
            }
            eff_st_x, eff_st_y = preset_map.get(st_pos, (0.68, 0.68))

        mode = getattr(self, "drag_focus_mode", None)
        focus = mode.get() if mode else "auto"

        if focus == "sticker":
            self.drag_target = "sticker"
            self.sticker_pos_x.set(eff_st_x)
            self.sticker_pos_y.set(eff_st_y)
            self.sticker_position.set("custom")
        elif focus == "banner":
            self.drag_target = "banner"
        elif focus == "pan":
            self.drag_target = "pan"
        else:
            # Auto detection with generous hit areas
            sticker_hit = has_sticker and (abs(norm_x - eff_st_x) < 0.45 and abs(norm_y - eff_st_y) < 0.45)
            banner_hit = has_banner and (abs(norm_x - self.banner_pos_x.get()) < 0.48 and abs(norm_y - self.banner_pos_y.get()) < 0.32)

            if sticker_hit:
                self.drag_target = "sticker"
                self.sticker_pos_x.set(eff_st_x)
                self.sticker_pos_y.set(eff_st_y)
                self.sticker_position.set("custom")
            elif banner_hit:
                self.drag_target = "banner"
            else:
                self.drag_target = "pan"

    def _on_canvas_drag(self, event):
        cfg = self.model_configs.get(self.selected_model.get(), self.model_configs["SQUARE"])
        cw = cfg["preview_w"]
        ch = cfg["preview_h"]
        dx = (event.x - self.drag_start_x) / max(1.0, cw / 2.0)
        dy = (event.y - self.drag_start_y) / max(1.0, ch / 2.0)

        if self.drag_target == "sticker":
            self.sticker_pos_x.set(max(-1.0, min(1.0, self.sticker_pos_x.get() + dx)))
            self.sticker_pos_y.set(max(-1.0, min(1.0, self.sticker_pos_y.get() + dy)))
            self.sticker_position.set("custom")
        elif self.drag_target == "banner":
            self.banner_pos_x.set(max(-1.0, min(1.0, self.banner_pos_x.get() + dx)))
            self.banner_pos_y.set(max(-1.0, min(1.0, self.banner_pos_y.get() + dy)))
        else:
            self.pan_x.set(max(-1.0, min(1.0, self.pan_x.get() + dx * 0.5)))
            self.pan_y.set(max(-1.0, min(1.0, self.pan_y.get() + dy * 0.5)))

        self.drag_start_x = event.x
        self.drag_start_y = event.y
        self.update_preview()

    def action_choose_banner_bg_color(self):
        c = colorchooser.askcolor(self.banner_color.get())[1]
        if c:
            self.banner_color.set(c)
            self.update_preview()

    def action_choose_bg_color(self):
        c = colorchooser.askcolor(self.bg_color)[1]
        if c:
            self.bg_color = c
            self.update_preview()

    def action_rotate(self, delta: int):
        self.rotation.set((self.rotation.get() + delta) % 360)
        self.update_preview()

    def mark_manual_adjustment(self):
        if self._is_applying_preset:
            return
        if self.film_preset_var.get() != "Custom / Manual (Unsaved)":
            self.film_preset_var.set("Custom / Manual (Unsaved)")

    def on_control_adjusted(self):
        self.mark_manual_adjustment()
        self.update_preview()

    def on_film_preset_changed(self, event=None):
        sel_title = self.film_preset_var.get()
        preset_id = None
        for pid, title in FILM_PRESET_OPTIONS:
            if title == sel_title:
                preset_id = pid
                break
        if not preset_id or preset_id == "none":
            return
        p = FILM_PRESETS.get(preset_id)
        if not p:
            return

        self._is_applying_preset = True
        try:
            if "print_mode" in p:
                self.print_mode.set(p["print_mode"])
            if "filter" in p:
                filt = p["filter"]
                if filt in ("monochrome", "mono"):
                    self.filter_preset.set("monochrome")
                elif filt == "sepia":
                    self.filter_preset.set("sepia")
                elif filt == "vintage":
                    self.filter_preset.set("vintage")
                elif filt == "vivid":
                    self.filter_preset.set("vivid")
                else:
                    self.filter_preset.set("none")
            if "brightness" in p:
                self.brightness.set(p["brightness"])
            if "contrast" in p:
                self.contrast.set(p["contrast"])
            if "saturation" in p:
                self.saturation.set(p["saturation"])
            if "warmth" in p:
                self.warmth.set(p["warmth"])
            if "vignette" in p:
                self.vignette.set(p["vignette"])
            if "light_leak" in p:
                self.light_leak.set(p["light_leak"])
            if "leak_placement" in p:
                self.leak_placement.set(p["leak_placement"])
            if "leak_intensity" in p:
                self.leak_intensity.set(p["leak_intensity"])
            if "film_grain" in p:
                self.film_grain.set(p["film_grain"])
            if "analog_wear" in p:
                self.analog_wear.set(p["analog_wear"])
            if "show_date" in p:
                self.show_vintage_date.set(p["show_date"])
            if "date_color" in p:
                self.vintage_date_color.set(p["date_color"])
            self.film_preset_var.set(sel_title)
        finally:
            self._is_applying_preset = False
        self.update_preview()

    def action_reset_adjustments(self):
        self.zoom.set(1.0)
        self.pan_x.set(0.0)
        self.pan_y.set(0.0)
        self.rotation.set(0)
        self.brightness.set(0.0)
        self.contrast.set(1.0)
        self.saturation.set(1.0)
        self.filter_preset.set("none")
        self.film_preset_var.set("Default / Base (No Effects)")
        self.update_preview()

    def action_reset_analog_fx(self):
        self.warmth.set(0.0)
        self.vignette.set(0.0)
        self.light_leak.set("none")
        self.leak_placement.set("auto")
        self.leak_intensity.set(0.70)
        self.film_grain.set(0.0)
        self.analog_wear.set(0.0)
        self.show_vintage_date.set(False)
        self.vintage_date_text.set("")
        self.vintage_date_color.set("amber")
        self.vintage_date_placement.set("bottomRight")
        self.film_preset_var.set("Default / Base (No Effects)")
        self.update_preview()

    def action_surprise_me_analog_fx(self):
        import random
        self.warmth.set(round(random.uniform(-0.3, 0.6), 2))
        self.vignette.set(round(random.uniform(0.25, 0.75), 2))
        self.light_leak.set(random.choice(["none", "burn", "sunburst", "sunset", "rainbow"]))
        self.leak_placement.set(random.choice(["auto", "left", "right", "topRight", "topLeft", "bottomLeft", "bottomRight", "diagonal"]))
        self.leak_intensity.set(round(random.uniform(0.45, 0.90), 2))
        self.film_grain.set(round(random.uniform(0.15, 0.55), 2))
        self.analog_wear.set(round(random.uniform(0.10, 0.45), 2))
        self.show_vintage_date.set(True)
        self.vintage_date_color.set(random.choice(["amber", "red", "green", "white"]))
        self.vintage_date_placement.set(random.choice(["bottomRight", "bottomLeft", "topRight", "topLeft"]))
        self.mark_manual_adjustment()
        self.update_preview()

    def roll_auto_leak(self):
        import random
        self.leak_placement.set("auto")
        self.leak_auto_seed = random.randint(1, 1000000)
        self.update_preview()

    def on_leak_placement_selected(self, event=None):
        import random
        if self.leak_placement.get() == "auto":
            self.leak_auto_seed = random.randint(1, 1000000)
        self.update_preview()

    def _render_full_canvas(self, source_img: Image.Image, target_w: int, target_h: int) -> Image.Image:
        img = source_img.copy()
        if self.rotation.get() != 0:
            img = img.rotate(-self.rotation.get(), expand=True, resample=Image.BICUBIC)

        if self.filter_preset.get() in ("monochrome", "mono"):
            img = ImageOps.grayscale(img).convert("RGB")
        elif self.filter_preset.get() == "sepia":
            gray = ImageOps.grayscale(img)
            img = ImageOps.colorize(gray, "#2e1a0b", "#f5e6cc")
        elif self.filter_preset.get() == "vintage":
            gray = ImageOps.grayscale(img)
            sepia_layer = ImageOps.colorize(gray, "#3d2714", "#f5ecd0")
            img = Image.blend(img, sepia_layer, 0.35)
            img = ImageEnhance.Contrast(img).enhance(0.95)
            img = ImageEnhance.Brightness(img).enhance(1.05)
        elif self.filter_preset.get() == "vivid":
            enh = ImageEnhance.Color(img)
            img = enh.enhance(1.4)

        if self.print_mode.get() == "rich":
            # Rich Mode: saturation (+18%) and subtle contrast pop (+8%)
            img = ImageEnhance.Color(img).enhance(1.18)
            img = ImageEnhance.Contrast(img).enhance(1.08)
        elif self.print_mode.get() == "natural":
            # Soft analog instant film highlights with 3D-LUT emulation
            img = ImageEnhance.Brightness(img).enhance(1.02)
            img = ImageEnhance.Contrast(img).enhance(0.96)
            img = ImageEnhance.Color(img).enhance(0.98)

        if self.brightness.get() != 0:
            enh = ImageEnhance.Brightness(img)
            img = enh.enhance(1.0 + self.brightness.get())
        if self.contrast.get() != 1.0:
            enh = ImageEnhance.Contrast(img)
            img = enh.enhance(self.contrast.get())
        if self.saturation.get() != 1.0 and self.filter_preset.get() not in ("monochrome", "mono"):
            enh = ImageEnhance.Color(img)
            img = enh.enhance(self.saturation.get())

        mode = self.fit_mode.get()
        hex_c = self.bg_color.lstrip("#")
        bg_rgb = tuple(int(hex_c[i:i+2], 16) for i in (0, 2, 4))
        canvas = Image.new("RGB", (target_w, target_h), bg_rgb)

        img_aspect = img.width / img.height
        tgt_aspect = target_w / target_h

        if mode == "stretch":
            w = target_w
            h = target_h
        elif mode == "fit":
            if img_aspect > tgt_aspect:
                w = target_w
                h = int(w / img_aspect)
            else:
                h = target_h
                w = int(h * img_aspect)
        else: # crop
            if img_aspect > tgt_aspect:
                h = target_h
                w = int(h * img_aspect)
            else:
                w = target_w
                h = int(w / img_aspect)

        z = self.zoom.get()
        w = max(1, int(w * z))
        h = max(1, int(h * z))
        sc = img.resize((w, h), Image.LANCZOS)
        x = (target_w - w) // 2 + int(self.pan_x.get() * (target_w / 2))
        y = (target_h - h) // 2 + int(self.pan_y.get() * (target_h / 2))
        canvas.paste(sc, (x, y))

        # Apply Analog Creative FX (PolaroidEngine)
        canvas = apply_analog_fx(
            canvas,
            photo_box=(x, y, w, h) if mode == "fit" else (0, 0, target_w, target_h),
            warmth=self.warmth.get(),
            vignette=self.vignette.get(),
            light_leak=self.light_leak.get(),
            leak_placement=self.leak_placement.get(),
            leak_intensity=self.leak_intensity.get(),
            film_grain=self.film_grain.get(),
            analog_wear=self.analog_wear.get(),
            show_vintage_date=self.show_vintage_date.get(),
            vintage_date_text=self.vintage_date_text.get(),
            vintage_date_color=self.vintage_date_color.get(),
            vintage_date_placement=self.vintage_date_placement.get(),
            seed=self.leak_auto_seed,
        )

        # Apply Decorative Frame
        if self.frame_style.get() != "none":
            canvas = draw_decorative_frame(canvas, self.frame_style.get())

        # Apply Stickers or Custom Image Overlay
        if self.sticker.get() != "none" or self.custom_sticker_img is not None:
            canvas = draw_sticker_overlay(
                canvas,
                sticker=self.sticker.get(),
                sticker_image=self.custom_sticker_img,
                position=self.sticker_position.get(),
                scale=self.sticker_scale.get(),
                opacity=self.sticker_opacity.get(),
                rotation=self.sticker_rotation.get(),
                pos_x=self.sticker_pos_x.get(),
                pos_y=self.sticker_pos_y.get(),
            )

        # Apply Custom Banner
        if self.banner_text.get().strip() and self.banner_style.get() != "none":
            canvas = draw_custom_banner(
                canvas,
                text=self.banner_text.get(),
                style=self.banner_style.get(),
                icon=self.banner_icon.get(),
                bg_color=self.banner_color.get(),
                text_color=self.banner_text_color.get(),
                pos_x=self.banner_pos_x.get(),
                pos_y=self.banner_pos_y.get(),
                scale=self.banner_scale.get(),
                rotation=self.banner_rotation.get(),
            )

        return canvas

    def _sync_sticker_cb(self, key: str):
        if hasattr(self, "cb_stickers") and hasattr(self, "sticker_list"):
            for idx, (k, t) in enumerate(self.sticker_list):
                if k == key:
                    self.cb_stickers.current(idx)
                    break

    def action_choose_custom_sticker(self):
        path = filedialog.askopenfilename(
            title="Select Sticker Image or Logo",
            filetypes=[("Image Files", "*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.gif")]
        )
        if not path:
            return
        try:
            raw = Image.open(path)
            self.custom_sticker_img = ImageOps.exif_transpose(raw).convert("RGBA")
            self.custom_sticker_path.set(path)
            if hasattr(self, "btn_cust_label"):
                self.btn_cust_label.config(text=os.path.basename(path)[:18])
            self.update_preview()
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load image: {e}")

    def action_clear_custom_sticker(self):
        self.custom_sticker_img = None
        self.custom_sticker_path.set("")
        if hasattr(self, "btn_cust_label"):
            self.btn_cust_label.config(text="Choose Image...")
        self.update_preview()

    def action_reset_decor(self):
        self.frame_style.set("none")
        if hasattr(self, "cb_frames"):
            self.cb_frames.current(0)
        self.sticker.set("none")
        if hasattr(self, "cb_stickers"):
            self.cb_stickers.current(0)
        self.action_clear_custom_sticker()
        self.sticker_position.set("topRight")
        self.sticker_pos_x.set(0.65)
        self.sticker_pos_y.set(0.65)
        self.sticker_scale.set(0.25)
        self.sticker_opacity.set(1.0)
        self.sticker_rotation.set(0.0)
        self.banner_text.set("")
        self.banner_style.set("none")
        if hasattr(self, "cb_bstyle"):
            self.cb_bstyle.current(0)
        self.banner_icon.set("none")
        if hasattr(self, "cb_bicon"):
            self.cb_bicon.current(0)
        self.banner_color.set("#e11d48")
        self.banner_text_color.set("#ffffff")
        self.banner_pos_x.set(0.0)
        self.banner_pos_y.set(0.68)
        self.banner_scale.set(1.0)
        self.banner_rotation.set(0.0)
        self.update_preview()

    def update_preview(self):
        if not self.source_image:
            return

        cfg = self.model_configs.get(self.selected_model.get(), self.model_configs["SQUARE"])
        target_w = cfg["width"]
        target_h = cfg["height"]

        canvas = self._render_full_canvas(self.source_image, target_w, target_h)

        # Scale down to canvas preview
        cw = cfg["preview_w"]
        ch = cfg["preview_h"]
        disp = canvas.resize((cw, ch), Image.BILINEAR)

        self.tk_photo = ImageTk.PhotoImage(disp)
        self.canvas.delete("all")
        cv_w = self.canvas.winfo_width()
        cv_h = self.canvas.winfo_height()
        if cv_w < 50: cv_w = 400
        if cv_h < 50: cv_h = 400
        cx = cv_w // 2
        cy = cv_h // 2
        self.canvas.create_image(cx, cy, image=self.tk_photo)
        self.canvas.create_rectangle(cx - cw//2, cy - ch//2, cx + cw//2, cy + ch//2, outline="#888", width=1)

    def action_open_files(self):
        paths = filedialog.askopenfilenames(
            title="Select Photos to Print",
            filetypes=[("Image Files", "*.jpg;*.jpeg;*.png;*.bmp;*.webp;*.tiff")]
        )
        if not paths:
            return
        for p in paths:
            try:
                raw = Image.open(p)
                trans = ImageOps.exif_transpose(raw).convert("RGB")
                name = os.path.basename(p)
                self.queue.append({"name": name, "path": p, "image": trans})
            except Exception as e:
                messagebox.showerror("Error", f"Failed to load {p}: {e}")

        self._refresh_queue_listbox()
        if self.queue:
            self._select_queue_idx(len(self.queue) - 1)

    def _refresh_queue_listbox(self):
        self.queue_listbox.delete(0, tk.END)
        for i, itm in enumerate(self.queue):
            status = itm.get("status", "Queued")
            self.queue_listbox.insert(tk.END, f"#{i+1}: {itm['name']} [{status}]")

    def _on_queue_select(self, event):
        sel = self.queue_listbox.curselection()
        if sel:
            self._select_queue_idx(sel[0])

    def _select_queue_idx(self, idx: int):
        if 0 <= idx < len(self.queue):
            self.selected_queue_idx = idx
            self.source_image = self.queue[idx]["image"]
            self.source_image_name = self.queue[idx]["name"]
            self.update_preview()

    def action_clear_queue(self):
        self.queue.clear()
        self._refresh_queue_listbox()
        self._load_sample_image()

    def action_scan(self):
        self.lbl_status.config(text="Scanning for nearby Instax printers...")
        def _scan():
            fut = self.run_coro(self.ble.scan(4.0))
            devs = fut.result()
            self.after(0, self._on_scan_done, devs)
        threading.Thread(target=_scan, daemon=True).start()

    def _on_scan_done(self, devs: List[dict]):
        self.discovered_printers = devs
        names = [d["name"] for d in devs]
        if names:
            self.cb_printers["values"] = names
            self.target_device.set(names[0])
            self.lbl_status.config(text=f"Discovered {len(names)} printer(s).")
        else:
            self.lbl_status.config(text="No printers found. (Tip: Turn OFF phone Bluetooth)")
            self.on_log("💡 Tip: Instax printers can only pair with ONE device at a time. If your printer is not appearing, turn OFF Bluetooth on your phone/tablet so the printer is free to pair.")

    def action_toggle_connect(self):
        if self.is_connected:
            self.run_coro(self.ble.disconnect())
            self.is_connected = False
            self.lbl_status_icon.config(foreground="gray")
            self.btn_connect.config(text="Connect")
            self.lbl_status.config(text="Disconnected from printer.")
        else:
            target = self.target_device.get()
            self.lbl_status.config(text=f"Connecting to {target}...")
            def _connect():
                try:
                    fut = self.run_coro(self.ble.connect(target, timeout=8.0))
                    fut.result()
                    fut_st = self.run_coro(self.ble.fetch_status())
                    st = fut_st.result()
                    self.after(0, self._on_connected, st)
                except Exception as e:
                    err_str = str(e)
                    if "bluez" in err_str.lower() or "d-bus" in err_str.lower() or "not provided" in err_str.lower():
                        err_msg = (
                            f"No Bluetooth hardware or BlueZ service found on this system.\n\n"
                            f"Details: {err_str}\n\n"
                            f"💡 Note: Cloud environments (like GitHub Codespaces) and virtual machines do not have physical Bluetooth antennas.\n\n"
                            f"👉 To test live printing with zero hardware right here in Codespaces, run the Legacy Instax Wi-Fi app (which includes a built-in virtual simulator):\n\n"
                            f"python3 Legacy-Instax-Printer/Linux/LegacyInstaxPrinterGUI.py"
                        )
                        title = "Bluetooth Hardware Required"
                    else:
                        err_msg = (
                            f"{e}\n\n"
                            f"💡 Tip: Instax printers only allow ONE Bluetooth connection at a time. "
                            f"If previously connected to your phone or tablet, please turn OFF Bluetooth on your phone so the printer is free to connect to your computer."
                        )
                        title = "Connection Error"
                    self.after(0, lambda: messagebox.showerror(title, err_msg))
                    self.after(0, lambda: self.lbl_status.config(text="Bluetooth hardware unavailable." if "bluez" in err_str.lower() else "Failed to connect. Make sure phone Bluetooth is OFF."))
            threading.Thread(target=_connect, daemon=True).start()

    def _on_connected(self, st):
        self.is_connected = True
        self.lbl_status_icon.config(foreground="#00E676")
        self.btn_connect.config(text="Disconnect")
        self.film_remaining.set(f"Film: {st.film_remaining}/10")
        self.battery_info.set(f"Battery: {st.battery_percent}%")

        if st.width == 1260 or st.height == 840:
            self.selected_model.set("WIDE")
        elif st.width == 800:
            self.selected_model.set("SQUARE")
        elif st.width == 600:
            self.selected_model.set("MINI")

        self.update_preview()
        self.lbl_status.config(text=f"Connected to {self.target_device.get()} ({self.selected_model.get()} Link • {st.width}x{st.height} px)")

    def action_refresh_status(self):
        if not self.is_connected:
            self.action_toggle_connect()
            return
        def _fetch():
            try:
                st = self.run_coro(self.ble.fetch_status()).result()
                self.after(0, lambda: self.film_remaining.set(f"Film: {st.film_remaining}/10"))
                self.after(0, lambda: self.battery_info.set(f"Battery: {st.battery_percent}%"))
                self.after(0, lambda: self.lbl_status.config(text=f"Status: {st.film_remaining}/10 film, {st.battery_percent}% battery, door {'OPEN' if st.is_cover_open else 'closed'}."))
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("Error", str(e)))
        threading.Thread(target=_fetch, daemon=True).start()

    def action_flash_led(self):
        if not self.is_connected:
            messagebox.showinfo("Connect First", "Please connect to your printer first.")
            return
        self.run_coro(self.ble.flash_rainbow_led())

    def action_stop_led(self):
        if not self.is_connected:
            messagebox.showinfo("Connect First", "Please connect to your printer first.")
            return
        self.run_coro(self.ble.stop_led())

    def action_print_selected(self):
        if not self.source_image:
            return
        self._print_items([{"name": self.source_image_name, "image": self.source_image, "idx": self.selected_queue_idx}])

    def action_bulk_print(self):
        if not self.queue:
            return
        items = [{"name": itm["name"], "image": itm["image"], "idx": i} for i, itm in enumerate(self.queue)]
        self._print_items(items)

    def _print_items(self, items: List[dict]):
        if self.is_printing:
            return
        self.is_printing = True

        def _worker():
            try:
                if not self.is_connected:
                    self.after(0, lambda: self.lbl_status.config(text="Connecting to printer..."))
                    self.run_coro(self.ble.connect(self.target_device.get())).result()
                    st = self.run_coro(self.ble.fetch_status()).result()
                    self.after(0, self._on_connected, st)

                cfg = self.model_configs.get(self.selected_model.get(), self.model_configs["SQUARE"])
                w = cfg["width"]
                h = cfg["height"]

                for n, itm in enumerate(items):
                    self.after(0, lambda n=n: self.lbl_status.config(text=f"Printing {n+1}/{len(items)}: '{itm['name']}'..."))

                    # Render using full pipeline including Analog FX
                    rendered_canvas = self._render_full_canvas(itm["image"], target_w=w, target_h=h)
                    buf = io.BytesIO()
                    rendered_canvas.save(buf, format="JPEG", quality=90, progressive=False)
                    jpeg_bytes = buf.getvalue()

                    def progress(stage, pct):
                        self.after(0, lambda: self.progress_bar.config(value=int(pct * 100)))
                        self.after(0, lambda: self.lbl_status.config(text=f"[{n+1}/{len(items)}] {stage}"))

                    res = self.run_coro(self.ble.print_jpeg(jpeg_bytes, mode=self.print_mode.get(), progress_cb=progress)).result()
                    self.after(0, lambda: self.film_remaining.set(f"Film: {res.film_remaining}/10"))
                    if itm["idx"] >= 0 and itm["idx"] < len(self.queue):
                        self.queue[itm["idx"]]["status"] = "Printed ✓"
                        self.after(0, self._refresh_queue_listbox)

                    if n + 1 < len(items):
                        time.sleep(3)

                self.after(0, lambda: self.lbl_status.config(text="🎉 Print complete!"))
            except Exception as e:
                self.after(0, lambda: messagebox.showerror("Print Error", str(e)))
                self.after(0, lambda: self.lbl_status.config(text=f"Error: {e}"))
            finally:
                self.is_printing = False
                self.after(0, lambda: self.progress_bar.config(value=0))

        threading.Thread(target=_worker, daemon=True).start()

if __name__ == "__main__":
    app = InstaxDesktopApp()
    app.mainloop()
