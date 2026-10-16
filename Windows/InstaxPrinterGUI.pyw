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
    from instax_printer import InstaxBLE, render_image, DEFAULT_DEVICE_NAME
except ImportError:
    from .instax_printer import InstaxBLE, render_image, DEFAULT_DEVICE_NAME

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
            "WIDE": {"width": 1260, "height": 840, "preview_w": 460, "preview_h": 307, "name": "Instax Link WIDE"},
            "MINI": {"width": 600, "height": 800, "preview_w": 300, "preview_h": 400, "name": "Instax Mini Link"}
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
        self.print_mode = tk.StringVar(value="rich")
        self.brightness = tk.DoubleVar(value=0.0)
        self.contrast = tk.DoubleVar(value=1.0)
        self.saturation = tk.DoubleVar(value=1.0)
        self.filter_preset = tk.StringVar(value="none")

        # Drag tracking
        self.drag_start_x = 0
        self.drag_start_y = 0

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

        ttk.Label(tab_color, text="Print Mode:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(0, 4))
        ttk.Radiobutton(tab_color, text="instax-Rich Mode (Vibrant)", value="rich", variable=self.print_mode).pack(anchor=tk.W)
        ttk.Radiobutton(tab_color, text="instax-Natural (Classic 3D-LUT)", value="natural", variable=self.print_mode).pack(anchor=tk.W)

        ttk.Label(tab_color, text="Filter Preset:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(10, 4))
        cb_filt = ttk.Combobox(tab_color, textvariable=self.filter_preset, values=["none", "monochrome", "sepia", "vivid"])
        cb_filt.bind("<<ComboboxSelected>>", lambda e: self.update_preview())
        cb_filt.pack(fill=tk.X)

        ttk.Label(tab_color, text="Brightness:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=-0.5, to=0.5, variable=self.brightness, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_color, text="Contrast:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=0.5, to=1.5, variable=self.contrast, command=lambda e: self.update_preview()).pack(fill=tk.X)

        ttk.Label(tab_color, text="Saturation:", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=(8, 2))
        ttk.Scale(tab_color, from_=0.0, to=2.0, variable=self.saturation, command=lambda e: self.update_preview()).pack(fill=tk.X)

        # Tab 3: Protocol Debug
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

    def _on_canvas_press(self, event):
        self.drag_start_x = event.x
        self.drag_start_y = event.y

    def _on_canvas_drag(self, event):
        dx = (event.x - self.drag_start_x) / 180.0
        dy = (event.y - self.drag_start_y) / 180.0
        self.pan_x.set(max(-1.0, min(1.0, self.pan_x.get() + dx)))
        self.pan_y.set(max(-1.0, min(1.0, self.pan_y.get() + dy)))
        self.drag_start_x = event.x
        self.drag_start_y = event.y
        self.update_preview()

    def action_choose_bg_color(self):
        c = colorchooser.askcolor(self.bg_color)[1]
        if c:
            self.bg_color = c
            self.update_preview()

    def action_rotate(self, delta: int):
        self.rotation.set((self.rotation.get() + delta) % 360)
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
        self.update_preview()

    def update_preview(self):
        if not self.source_image:
            return

        cfg = self.model_configs.get(self.selected_model.get(), self.model_configs["SQUARE"])
        target_w = cfg["width"]
        target_h = cfg["height"]

        # Render PIL image
        img = self.source_image.copy()
        if self.rotation.get() != 0:
            img = img.rotate(-self.rotation.get(), expand=True, resample=Image.BICUBIC)

        # Filters
        if self.filter_preset.get() == "monochrome":
            img = ImageOps.grayscale(img).convert("RGB")
        elif self.filter_preset.get() == "sepia":
            gray = ImageOps.grayscale(img)
            img = ImageOps.colorize(gray, "#2e1a0b", "#f5e6cc")
        elif self.filter_preset.get() == "vivid":
            enh = ImageEnhance.Color(img)
            img = enh.enhance(1.4)

        if self.brightness.get() != 0:
            enh = ImageEnhance.Brightness(img)
            img = enh.enhance(1.0 + self.brightness.get())
        if self.contrast.get() != 1.0:
            enh = ImageEnhance.Contrast(img)
            img = enh.enhance(self.contrast.get())
        if self.saturation.get() != 1.0 and self.filter_preset.get() != "monochrome":
            enh = ImageEnhance.Color(img)
            img = enh.enhance(self.saturation.get())

        # Fit Mode
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
                    err_msg = f"{e}\n\n💡 Tip: Instax printers only allow ONE Bluetooth connection at a time. If previously connected to your phone or tablet, please turn OFF Bluetooth on your phone so the printer is free to connect to your computer."
                    self.after(0, lambda: messagebox.showerror("Connection Error", err_msg))
                    self.after(0, lambda: self.lbl_status.config(text="Failed to connect. Make sure phone Bluetooth is OFF."))
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

                    # Generate JPEG
                    # Render using current settings
                    img = itm["image"]
                    buf = io.BytesIO()
                    # Resizing
                    resized = img.resize((w, h), Image.LANCZOS)
                    resized.save(buf, format="JPEG", quality=90, progressive=False)
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
