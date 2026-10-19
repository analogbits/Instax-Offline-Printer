# 📸 Instax Offline Printer Applications Suite
### Universal 100% Offline Printing for macOS, Windows & Linux

[![Try BLE Web App Online](https://img.shields.io/badge/BLE_Web_App-Mini_%7C_SQUARE_%7C_WIDE-3b82f6?style=for-the-badge&logo=googlechrome&logoColor=white)](https://analogbits.github.io/Instax-Offline-Printer/)
[![Try Legacy Wi-Fi Web App](https://img.shields.io/badge/Legacy_Web_App-SHARE_SP--1_%7C_SP--2_%7C_SP--3-10b981?style=for-the-badge&logo=wifi&logoColor=white)](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)
[![Download Universal Offline Suite](https://img.shields.io/badge/Download-Universal_Offline_Suite_(.zip)-22c55e?style=for-the-badge&logo=github&logoColor=white)](https://github.com/analogbits/Instax-Offline-Printer/releases/latest)
[![Software Documentation & Runbook](https://img.shields.io/badge/Documentation-Comprehensive_Runbook-8b5cf6?style=for-the-badge&logo=readthedocs&logoColor=white)](DOCUMENTATION.md)
[![Code Walkthrough](https://img.shields.io/badge/Code_Walkthrough-Annotated_Guide-06b6d4?style=for-the-badge&logo=github&logoColor=white)](CODE_WALKTHROUGH.md)

> 🚀 **Try either Web App right now in your browser (macOS, Windows, Linux, Android & iPhone/iPad):**  
> - **🔵 [👉 Launch Web Bluetooth Printer (SQUARE Link • Link WIDE • Mini Link)](https://analogbits.github.io/Instax-Offline-Printer/)** *(Works natively in Chrome, Edge, Brave & Opera on Mac/Windows/Linux/Android — and on **iPhone / iPad** via the built-in **Local Wi-Fi Bluetooth Bridge** in regular Safari or the free **Bluefy** app!)*  
> - **🎞️ [👉 Launch Legacy Wi-Fi Direct Web Printer (Instax SHARE SP-1 • SP-2 • SP-3)](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)** *(Works on Mac, Windows, Linux, Android & iOS)*

A complete, self-contained suite of native standalone applications, Adobe Lightroom Classic & Linux Darktable plugins, command-line tools, and zero-install offline utilities for printing directly to:
* **Bluetooth Low Energy (BLE) Printers:** **Fujifilm Instax SQUARE Link**, **Instax Link WIDE / WIDE 2**, and **Instax Mini Link (1, 2, 3, & Link+)**
* **Legacy Wi-Fi Direct Printers:** **Fujifilm Instax SHARE SP-1**, **SP-2**, and **SP-3 SQUARE** (`192.168.0.251:8080`)

---

## 🔒 100% Offline & Private Guarantee
* **No Internet Required:** None of these applications connect to the cloud, send telemetry, or require accounts.
* **Direct Hardware Communication:** Communicates directly with your printer's Bluetooth GATT characteristics (Link series) or Wi-Fi Direct TCP socket (`192.168.0.251:8080`, SHARE SP series).
* **Permanent Future-Proofing:** Even if Fujifilm's mobile apps or servers ever become obsolete, this offline suite ensures you can always print from your desktop forever.

---

## ⚠️ Essential Prerequisites (Prior to First Use!)

To ensure a smooth, error-free experience, follow these two quick steps **prior to printing** from your computer:

### 1️⃣ Step 1: Update Your Printer Firmware First (Prior to Use!)
> [!IMPORTANT]
> **Always ensure your printer is on the latest firmware before using this offline suite!**
> * **Why this matters (e.g. Instax Link WIDE):** Printers running the initial factory firmware **`0100`** have a known manufacturer bug with BLE packet buffer overflows, causing image data transfers to hang, time out, or abort midway. Updating your printer to firmware **`0101`** (or newer) completely resolves this issue and ensures 100% reliable printing.
> * **How to update prior to use:**
>   1. Turn on your printer and open the official Fujifilm mobile app (e.g., ***instax Link WIDE***, ***instax SQUARE Link***, or ***instax mini Link***) on your phone.
>   2. Connect to your printer and navigate to **Settings $\to$ Firmware Update** (or **Printer Settings $\to$ Firmware Version**).
>   3. Let the official app install the latest firmware update to the printer.

### 2️⃣ Step 2: Turn OFF Bluetooth on Your Phone / Tablet
> [!IMPORTANT]
> **Instax printers only allow ONE active Bluetooth connection at a time.**
> * Once the firmware is updated, **turn OFF Bluetooth** in your phone's Settings/Control Center (or force-close the official Instax mobile app).
> * If your phone remains connected, the printer **completely stops broadcasting** its Bluetooth beacons and will appear **invisible** to your computer.
> * Turn your printer off and back on — it will now immediately appear and connect on your computer!

---

## 🚀 Quick Start Guide by Operating System

### 🍏 1. macOS (`macOS/` & `Legacy-Instax-Printer/macOS/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax Printer.app`** | Double-click in Finder | Full native Swift desktop app for BLE Link printers (WIDE, SQUARE, Mini). Apple Photos/iCloud browser, interactive pan/zoom/rotate framing, artistic filters, live film/battery gauges, Multi-Photo Collage Studio, QR Print, debug console (`⌘D`), and offline guide (`⌘?`). |
| **`Legacy Instax Printer.app`** | Double-click in Finder | Dedicated native Swift desktop app for Wi-Fi Direct **Instax SHARE SP-1, SP-2 & SP-3** printers with built-in Wi-Fi network scanner dropdown (`INSTAX-XXXXXXXX`), live 10-LED film counter, Collage Studio, QR Print, and built-in Virtual SP Simulator. |
| **`Start-iPhone-WiFi-Bridge.command`** | Double-click in Finder | **Local Wi-Fi Bluetooth Bridge for iPhone / iPad / Mac Safari.** Hosts the Web App on your home Wi-Fi (`http://192.168.1.x:8765`) with a scannable QR code so you can print directly from regular iPhone Safari via your Mac's Bluetooth. |
| **`instax-square`** / **`legacy-instax`** | `./instax-square print photo.jpg` | High-performance standalone CLI binaries for BLE and Wi-Fi Direct printers. No Python or runtime needed. |
| **`macOS-Run.command`** | Double-click in Finder | Emergency drag-and-drop terminal launcher. |
| **`install-cli.sh`** | Run in Terminal | Installs `instax-square` system-wide to `/usr/local/bin`. |

---

### 🪟 2. Windows (`Windows/` & `Legacy-Instax-Printer/Windows/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer.vbs`** *(Recommended)* | Double-click in Explorer | **Zero-Install Standalone App.** Opens instantly in a dedicated native desktop window with zero command-line popups. Uses the pre-installed Windows 10/11 Microsoft Edge engine to connect directly to the Windows Bluetooth stack (WinRT). No Python needed! |
| **`Start-iPhone-WiFi-Bridge.bat`** | Double-click in Explorer | **Local Wi-Fi Bluetooth Bridge for iPhone / iPad Safari.** Hosts the Web App on your home Wi-Fi (`http://192.168.1.x:8765`) with a scannable QR code so you can print directly from regular iPhone Safari via your Windows PC's Bluetooth. |
| **`Windows-Run.bat`** | Double-click | Python GUI launcher (`InstaxPrinterGUI.pyw` / `LegacyInstaxPrinterGUI.py`). Auto-detects dependencies and falls back to the All-in-One app if Python is not installed. |
| **`instax_printer.py`** / **`legacy_instax_printer.py`** | `python instax_printer.py print photo.jpg` | Cross-platform BLE and Wi-Fi Direct command-line engines with Collage, QR Code, Caption, Dry Run, and `--serve` Wi-Fi Bridge support. |

---

### 🐧 3. Linux (`Linux/` & `Legacy-Instax-Printer/Linux/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer-Linux.sh`** *(Recommended)* | Double-click or `./Instax-Printer-Linux.sh` | **Zero-Install Standalone App.** Launches immediately in a borderless native window using Chromium, Google Chrome, Brave, or Edge. No Python, pip, or Tkinter required! |
| **`Start-iPhone-WiFi-Bridge.sh`** | Double-click or `./Start-iPhone-WiFi-Bridge.sh` | **Local Wi-Fi Bluetooth Bridge for iPhone / iPad Safari & Firefox.** Hosts the Web App on your home Wi-Fi (`http://192.168.1.x:8765`) with a scannable QR code so you can print directly from regular iPhone Safari via your Linux machine's Bluetooth. |
| **`linux-run.sh`** | Double-click or `./linux-run.sh` | Python Tkinter desktop GUI launcher (`InstaxPrinterGUI.py` / `LegacyInstaxPrinterGUI.py`). |
| **`instax-printer.desktop`** | Copy to `~/.local/share/applications/` | Adds Instax Printer to your Linux application menu. |
| **`instax_printer.py`** / **`legacy_instax_printer.py`** | `python3 instax_printer.py print photo.jpg` | Standalone Linux command-line printers for BLE (BlueZ) and Wi-Fi Direct (`SP-1/2/3`), plus `--serve` Wi-Fi Bridge support. |

---

### 🌐 4. Universal Web Apps & iPhone / iPad Safari Printing (`Web-Bluetooth-Offline/` & `Legacy-Instax-Printer/Web-WiFi-Offline/`)

#### 🔵 A. Modern BLE Link Printers (SQUARE Link, Link WIDE, Mini Link 1/2/3)
* **Live Online Web App:** [https://analogbits.github.io/Instax-Offline-Printer/](https://analogbits.github.io/Instax-Offline-Printer/)
* **Offline Studio File:** [`Web-Bluetooth-Offline/InstaxPrinterWeb.html`](Web-Bluetooth-Offline/InstaxPrinterWeb.html)
* **Desktop & Android:** Works natively with zero install in **Google Chrome, Microsoft Edge, Brave, Opera, and Arc** on macOS, Windows 10/11, Linux, Android, and ChromeOS.
* **📱 iPhone / iPad & Apple Safari Support (2 Easy Options):**
  * *Why needed:* Apple deliberately disables the W3C Web Bluetooth API (`navigator.bluetooth`) in WebKit (affecting iPhone Safari, iOS Chrome, iOS Edge, and macOS Safari).
  1. **🏠 Option 1 — At Home via Local Wi-Fi Bluetooth Bridge (Zero iOS Apps Needed!):**
     * Double-click `Start-iPhone-WiFi-Bridge.command` (macOS), `Start-iPhone-WiFi-Bridge.bat` (Windows), or `./Start-iPhone-WiFi-Bridge.sh` (Linux).
     * Your computer displays a scannable QR code and local address (e.g. `http://192.168.1.x:8765`).
     * Scan with your iPhone camera to open the Web App in **regular iPhone Safari**, select photos from your Camera Roll, and tap **🖨 Print Physical Photo**.
     * *How it works under the hood:* Your Mac uses **two separate radios simultaneously** (Wi-Fi receives the photo from your iPhone over your home router, while Bluetooth transmits the image to your Instax printer).
  2. **🎒 Option 2 — On the Go via Bluefy (No Computer Needed):**
     * When away from home, open the Web App inside the free [Bluefy – Web BLE Browser](https://apps.apple.com/app/bluefy-web-ble-browser/id1492822055) app on iOS to communicate directly from iPhone to printer over Bluetooth.

---

#### 🎞️ B. Legacy Wi-Fi Direct Printers (Instax SHARE SP-1, SP-2 & SP-3)
* **Live Online Web App:** [https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)
* **Offline Studio File:** [`Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html`](Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)
* **📱 Printing from iPhone or iPad (3 Easy Options):**
  1. **Option 1 — Safari Web Studio via Local Wi-Fi Bridge:**
     * Connect your computer to **`INSTAX-XXXXXXXX`** and double-click `Start-Legacy-iPhone-WiFi-Bridge.command` (macOS), `Start-iPhone-WiFi-Bridge.bat` (Windows), or `./Start-iPhone-WiFi-Bridge.sh` (Linux).
     * Connect iPhone to **`INSTAX-XXXXXXXX`** and open the displayed URL (e.g. `http://192.168.0.x:8089`) in regular iPhone Safari.
     * Pick photos from your Camera Roll, frame collages, apply filters, and print over Wi-Fi Direct!
  2. **Option 2 — 1-Second AirDrop to Mac (Fastest for Mac Users):**
     * In Apple Photos on iPhone, tap Share $\to$ AirDrop to your Mac in 1 second.
     * Connect Mac to **`INSTAX-XXXXXXXX`**, open `Legacy Instax Printer.app` (or [`LegacyInstaxPrinterWeb.html`](Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)), pick the photo from Downloads, and click **Print Over Wi-Fi Direct**!
  3. **Option 3 — Direct iPhone-to-Printer (No Computer Needed):**
     * Connect iPhone to **`INSTAX-XXXXXXXX`** and print directly using Fujifilm's official [instax SHARE app](https://apps.apple.com/app/instax-share/id816944602) from the App Store.

---

### 🧩 5. Adobe Lightroom Classic & Linux Darktable Plugins (`Lightroom-Classic-Plugin/`)
* **Adobe Lightroom Classic (`Instax-Printer.lrplugin` — macOS & Windows):**
  * Print directly from Lightroom's Library or Develop module to **any BLE Link or Legacy SHARE SP-1/2/3 printer** with zero cloud or phone hops!
  * **Quick Print:** Select photo(s) $\to$ **File (or Library) $\to$ Plug-in Extras $\to$ Print to Instax...**
  * **Export Dialog:** Select **Export To: Instax Offline Printer** with full support for Auto-Detect BLE, SP-1/2/3 Wi-Fi Direct, Multi-Photo Collages, QR Codes, Captions, and **0-Film Dry Run**.
  * **Cross-Platform Bundled Binaries:** Includes `bin/mac/` (`InstaxCLIHelper.app` + native universal binaries) and `bin/win/` (`instax-square.bat` + `legacy-instax.bat`).
* **Linux Darktable Plugin (`Linux-Darktable-Plugin/instax_darktable.lua` — Linux, Windows & macOS):**
  * Adds **"Instax Offline Printer (BLE & Wi-Fi Direct)"** directly to Darktable's Export module!

---

### 🍏 6. Apple Photos Direct Integration (`Apple-Photos-Addon/`)
Print directly from **Apple Photos** to your Instax printer with zero cloud hops:

* **⭐️ Native macOS Share Menu ("Share to Instax Printer" & "Legacy Instax Share"):**
  1. In **Apple Photos**, select one or more photos.
  2. Click the **Share button** `[↑]` in the top toolbar (or right-click photo(s) $\to$ **Share** $\to$ **Instax Printer**).
  3. The photos are automatically prepared and sent straight into Instax Printer's print queue!
* **Edit With:** Right-click any photo in Apple Photos $\to$ **Edit With $\to$ Instax Printer**.
* **1-Click Companion App (`Print from Apple Photos.app`):** Select photos in Apple Photos $\to$ click the app (or drag it into your Dock) to immediately queue your photos.
* **In-App Photos Browser:** Click `+ Apple Photos / iCloud` (`⌘ + Shift + I`) inside the app to search and browse your full library, albums, and favorites.

---

### 🎞️ 7. Legacy Instax Printer Suite (`Legacy-Instax-Printer/` — SP-1, SP-2 & SP-3 Wi-Fi Direct)
Dedicated offline suite for **Fujifilm Instax SHARE SP-1, SP-2 (`600 × 800`)**, and **SP-3 SQUARE (`800 × 800`)** printers over Wi-Fi Direct (`192.168.0.251:8080`, default PIN `1111`):
* **Live Wi-Fi Direct Scanner Dropdown & Diagnostics:** Click **[📶 Wi-Fi Test / Points]** to scan nearby `INSTAX-XXXXXXXX` 2.4 GHz hotspots (`CoreWLAN` / `system_profiler` on macOS, `netsh wlan` on Windows, `nmcli` on Linux) and probe `192.168.0.251:8080` hardware responsiveness in real time.
* **Honest Hardware LED Telemetry:** Displays unlit LEDs (`-- / 10 Film`) when offline and lights up exact green LEDs (`0–10` sheets remaining & `0–4` battery bars) once connected to your printer.
* **Bit-Exact 90° Clockwise Scanline Planar RGB Encoding:** Verified `60,000`-byte planar R, G, B segment streaming (`24` segments / `1,440,000` bytes for SP-1/SP-2; `32` segments / `1,920,000` bytes for SP-3).
* **Built-in Virtual SP Simulator (`127.0.0.1:18080`):** Test the entire suite, UI, collages, QR codes, and CLI without turning on a physical printer.

---

## 🎨 Creative Studio Features: Collages & Rich QR Badges

### 🖼 Multi-Photo Collage Studio (Up to 9 Photos)
Take full advantage of the larger **Instax Link WIDE** (`1260 × 840 px`) canvas, square prints, and mini prints:
* **11 Creative Layouts:**
  * **2 Photos:** Vertical Split (`50/50` Left/Right), Horizontal Split (Top/Bottom)
  * **3 Photos:** **3 Vertical WIDE Stripes** (ideal for Link WIDE!), Hero + 2 Stacked, Top Banner + 2 Columns
  * **4 Photos:** 2×2 Grid, **4 Vertical Photo-Booth Strips** (classic Instax WIDE photobooth!)
  * **6 Photos:** 3×2 WIDE Panoramic Grid
  * **8 Photos:** 4×2 WIDE Grid
  * **9 Photos:** 3×3 Grid
* **Adjustable Border Spacing:** Choose border gaps from `0 px` (seamless flush borders) to `32 px` (classic white matte borders) with live real-time preview.

### 📱 Rich QR Code Badges & Text Stamps (Instax QR Print)
Embed high-resolution, scannable QR codes onto your physical prints—just like Fujifilm's mobile apps:
* **Support Anything Scannable:** Web links (portfolios, videos, playlists), secret text messages, Wi-Fi credentials, location coordinates, or phone numbers.
* **5 Dynamic Corner Positions:** Bottom-Right (default), Bottom-Left, Top-Right, Top-Left, or Bottom-Center.
* **3 Badge Styles:** Translucent Glass, Solid White, or Dark Vignette.
* **Available Across All Apps:** Native Swift macOS apps, Windows/Linux GUIs, Lightroom Classic & Darktable plugins, CLI (`--qr <text>`), and Web apps!

### ✨ Stickers, Decorative Frames & Custom Overlays Studio (v2.0.0)
Customize your prints with decorative frames, hand-drawn doodles, emoji stickers, custom text banners, and personal logo watermarks—100% royalty-free with zero proprietary asset dependencies:
* **✋ Interactive Free Move & Canvas Dragging:** Drag stickers, custom banners, or pan the underlying photo directly on the canvas with touch (iPhone/iPad) or mouse drag. Choose your focus with the **Drag Target Focus** mode (`Auto`, `Photo Pan`, `Sticker Move`, `Banner Move`) with real-time coordinate slider synchronization.
* **🏷 Custom Banner & Text Maker:** Create stylized banners with your own custom text, dates, or emojis. Choose from 6 banner styles (**Ribbon**, **Pennant / Flag**, **Modern Pill**, **Vintage Label**, **Masking Tape**, **Speech Bubble**) across 8 curated color harmonies.
* **🎨 Hand-Drawn Doodle & Vector Stickers:**
  * **Hand-Drawn Doodles:** Doodle Crown, Sunglasses, Party Hat, Arrows, Sunburst, Sparkles, Coffee Mug, and Love Hearts.
  * **Party & Celebration:** 🎉 Party Popper, 🎂 Birthday Cake, ✨ Sparkles, 🥂 Cheers, 🎈 Balloon, 🎁 Gift Box.
  * **Travel & Outdoors:** 📸 Camera, ✈️ Airplane, 🌴 Palm Tree, ⛺️ Camping Tent, ⛰️ Mountain, ☀️ Sun, 🌊 Ocean Wave.
  * **Love & Affection:** ❤️ Classic Red Heart, 💖 Sparkle Heart, 💕 Two Hearts, 💌 Love Letter, 🌹 Rose, 💐 Floral Bouquet.
  * **Nature & Pets:** 🐾 Paw Print, 🐶 Puppy, 🐱 Kitten, 🌸 Cherry Blossom, ☕️ Coffee, 🍀 Four-Leaf Clover.
  * **Retro & Vibes:** 📼 Vintage Cassette Tape, 🕶️ Cool Sunglasses, ✌️ Peace Sign, ⚡️ Lightning Bolt, 🎵 Musical Note, 🔥 Fire / Lit.
* **🖼 10 Procedural Decorative Film Frame Styles:**
  * **Classic White Film Border:** Nostalgic instant paper card frame with bottom caption chin.
  * **Obsidian Black Matte:** Dramatic deep charcoal border with fine edge relief.
  * **Rainbow Spectrum Gradient:** Vibrant multi-band prismatic edge frame.
  * **Sunset Ombre:** Smooth warm gradient shifting from rose pink and amber orange into twilight indigo.
  * **35mm Vintage Film Sprockets:** Authentic analog film roll sprockets with perforation cutouts along both edges.
  * **Metallic Gold Foil:** Luxurious warm metallic foil border with bevel reflections.
  * **Rose Gold Shimmer:** Elegant rose champagne metallic border.
  * **Pastel Candy Geometric:** Playful soft pastel quad-color frame (sky blue, candy pink, mint green, and pale yellow).
  * **Scalloped Postage Stamp:** Vintage perforated postage stamp edge perforation cutouts.
  * **None (Standard Borderless):** Edge-to-edge full bleed printing.
* **🖼 Custom Image & Logo Watermarks ("Other Images"):** Select any custom PNG, JPG, or WebP graphic from your device (personal signatures, company logos, cartoon stickers, or graphic emblems) to overlay directly onto the photo.
* **🎛 Complete Placement, Scaling & Rotation Controls:**
  * **Direct Canvas Hit-Testing:** Click and drag any sticker or banner directly on screen.
  * **Live Sliders:** X/Y Position, Scale Multiplier (`0.10x` to `0.60x`), Opacity (`10%` to `100%`), and Rotation Angle (`-180°` to `+180°`).
* **💻 Universal Cross-Platform Support:** Available in Web Bluetooth (`InstaxPrinterWeb.html`), Legacy Web Wi-Fi (`LegacyInstaxPrinterWeb.html`), native macOS Swift apps (`Instax Printer.app` & `Legacy Instax Printer.app`), Windows/Linux desktop GUIs, and command-line interfaces (`--frame-style`, `--sticker`, `--sticker-image`, `--sticker-pos`, `--sticker-scale`, `--sticker-opacity`, `--sticker-rot`).

### 🎞️ Analog Creative FX & Film Emulation Studio (Ported from PolaroidEngine)
Bring the nostalgic warmth, chemical quirks, and physical characteristics of vintage instant film to any photo with zero external dependencies:
* **🎞️ Instant Film Emulation Presets Catalog (v1.8.1):**
  * **Default / Base (No Effects):** Clean neutral baseline with zero analog effects, neutral color reproduction, and pristine digital clarity.
  * **Polaroid Film Simulations:**
    * **Polaroid SX-70 (1972 Warm Chemistry):** Iconic warm, muted tones, soft contrast, sunburst corner leak, and authentic chemical texture.
    * **Polaroid 600 (Classic 80s/90s Pop):** High-contrast, punchy color rendition with left-hinge film burn leak and tactile grain.
    * **Polaroid I-Type / Modern Color:** Clean, crisp modern instant color emulsion with subtle grain and gentle lens vignette.
    * **Polaroid Spectra / Image System:** Wide-format rich color rendition with sunset gradient and balanced optical warmth.
  * **Vintage & Nostalgia Eras:**
    * **1970s Golden Vintage:** Deep amber color wash, heavy sunburst flare, high silver grain, and analog dust/scratches.
    * **1980s Retro Flash Pop:** Vibrant saturation, cool-balanced highlights, diagonal rainbow prism leak, and glowing red LED date stamp.
    * **1990s Point & Shoot / Disposable:** Flash pop, moderate edge burn leak, tactile grain, and classic amber LED date stamp.
    * **1960s Monochrome Silver Halide:** Dense silver halide crystals, rich black-and-white tonal contrast, and subtle darkroom wear.
  * **Instax Film Profiles:**
    * **🌈 instax-Rich (Vibrant High Contrast):** Maximizes dynamic range and color saturation for vivid landscapes and portraits.
    * **📷 instax-Natural (3D-LUT Fuji Emulation):** Fujifilm's signature 3D-LUT profile with soft analog instant film highlights.
    * **Instax Monochrome (B&W Street Film):** High-contrast street documentary black-and-white emulsion.
    * **Instax Warm Sepia (Nostalgic Tea Wash):** Warm tea-toned monochrome wash with gentle vintage vignette.
* **🔄 Bi-Directional Cross-Tab Synchronization:** Selecting any film preset automatically synchronizes settings across **both** the Color/Filters tab (print mode, filter preset, brightness, contrast, saturation) and Analog FX tab (warmth, vignette, light leak, intensity, grain, wear, date stamp). Fine-tuning any individual slider or combobox automatically switches the preset dropdown to `Custom / Manual (Unsaved)`.
* **Warmth / Color Temp Dial:** Shift color temperature non-destructively from `-1.0` (Cool Arctic Blue) to `+1.0` (Golden Amber Sunlight).
* **Lens Vignette:** Dial in `0%` to `100%` optical falloff shadow around the edges of the frame.
* **Authentic Light Leaks:** Choose from 4 physical film leak behaviors:
  * **Red Film Burn:** Fiery orange/red light leaking through an unlatched film door hinge.
  * **Golden Sunburst Flare:** Bright solar wash entering from the corner.
  * **Sunset Glow:** Coral and rose dual-tone wash.
  * **Prismatic Rainbow Spectrum:** Multi-band color prism streak across the emulsion.
  * **8 Placements:** Auto, Left Edge, Right Edge, Top-Right, Top-Left, Bottom-Left, Bottom-Right, Diagonal.
* **Tactile Film Grain (Silver Halide):** Procedural crystal noise rendered directly at native print DPI for authentic tactile film presence.
* **Dust, Scratches & Wear:** Deterministic hairline scratches, fine dust motes, curved fibers, and chemical developer pod pressure spread marks that stay locked in place as you adjust intensity.
* **Vintage LED Date Stamp:** Retro 90s digital LED datestamp (`'YY MM DD`) with authentic glowing halo (`shadowBlur: 6`) in Amber Gold (`#FF8C00`), Ruby Red (`#FF2525`), Emerald Green (`#00E676`), or Crisp White (`#F5F5F7`).
* **🎲 "Surprise Me!" & ↺ "Reset":** One-click retro vibe randomizer that automatically styles your photo with a unique vintage combination.
* **Frame-Aware Clipping:** Automatically clips all analog effects to the photo inside the paper border when using **Letterbox (Fit)** mode, keeping white/black card borders clean.

---

## 🎨 Hand-Drawn Doodle Stickers, Artistic Frames & Custom Banner Maker
### 100% Royalty-Free Vector Math — Zero Proprietary Assets

Every application across the suite (Web Bluetooth, Web Wi-Fi Direct, native macOS SwiftUI apps, Linux & Windows GUIs/CLIs) includes an extensive creative decoration studio engineered entirely with procedural vector math:

* **💖 Romance & Love Doodle Stickers:**
  * Hand-lettered cursive *"love"* calligraphy badge
  * Bold distressed *"I LOVE YOU"* typographic block
  * Intertwined cursive *"forever"* in ribbon heart
  * Sketchy hand-drawn scribble heart & winged angel heart
  * Romantic love letter envelope with wax seal & heart seal
  * Radiating / bursting doodle heart with speed lines
  * Floating heart-shaped helium balloon bouquet
  * Cupid's arrow piercing heart & anatomical finger "heart hands"
  * Continuous looping infinity ribbon heart
* **🎉 Seasonal & Celebration Doodle Stickers:**
  * Multi-tier birthday cake with burning candles & pennant bunting garland
  * *"Happy Holidays"* gold starburst emblem & *"Season's Greetings"* holly wreath
  * Decorated Christmas evergreen tree with star topper & holiday hanging stockings
  * Friendly Halloween ghost with pointed witch hat, glowing jack-o'-lantern & flying bats
  * Summer beach flip-flops, spiral seashells, cherry blossom petals & mimosa blooms
* **🖼️ 18 Decorative Film Frames (Classic & Artistic):**
  * Classic White Border, Obsidian Black Matte, Rainbow Spectrum, Sunset Ombre
  * 35mm Vintage Film Sprockets, Metallic Gold Foil, Rose Gold Shimmer, Pastel Candy Geometric, Scalloped Postage Stamp
  * **Baroque Filigree Lace:** Victorian lace border with delicate corner flourishes and oval cameo framing
  * **Wedding Botanical Floral:** Elegant olive green vine brackets with coral pink florets and soft mint leaves
  * **Leaded Stained Glass Mosaic:** Multi-color jewel-tone glass border (ruby, sapphire, amber, emerald, amethyst) with dark lead came outlines
  * **Glowing Golden Bokeh & Sparkles:** Luminous circular light orbs and four-point cross sparkles
  * **Night Sky Fireworks Burst:** Multi-colored radial starburst pyrotechnic explosions
  * **Hanging Twin Hearts Garland:** Delicate overhead string garland with dangling twin-heart beads
  * **Festive Pine & Berry Garland:** Deep forest green pine boughs with holiday red winterberry clusters
  * **Autumn Botanical Leaves:** Warm russet, maple gold, and burnt orange autumn foliage border
* **🎯 Free Canvas Positioning & Interactive Dragging:**
  * **Intelligent Drag Target Hit-Testing:** Click and drag stickers, custom image watermarks, or banners freely anywhere across the canvas. Smart hit-testing ensures clicking an overlay manipulates that element directly without accidentally moving or panning the underlying photo.
  * **Dedicated Drag Target Focus Bar (`🎯 Auto` • `🖼️ Photo` • `🎨 Sticker` • `🎀 Banner`):** Quickly toggle canvas drag focus across native macOS SwiftUI apps, Web Studios, and desktop GUIs to lock dragging onto stickers, banners, or photo framing.
  * **Seamless Preset Synchronization:** Switching between position presets (corners, centers) automatically aligns the internal coordinate space so manual dragging continues smoothly from the exact preset anchor without coordinate jumping.
  * Direct numeric **X & Y Offset sliders** (`-1.0` to `+1.0`) with live coordinate mapping for precision placement across all canvas aspect ratios (Square, Wide, Mini).
  * Scale multipliers (`0.10×` to `2.50×`), opacity transparency (`10%` to `100%`), and continuous `360°` rotation dials (`-180°` to `+180°`).
* **🎀 Custom Banner Maker:**
  * Create personalized typographic ribbons, banners, and badges with your own custom text!
  * **6 Banner Styles:** 3D Folded Swallowtail Ribbon, Calligraphy Brush Underline, Frosted Pill Badge, Vintage Luggage Tag, Postal Rubber Cancellation Stamp, and Triangle Bunting Garland.
  * **Icon Accents:** Heart (❤️), Sparkles (✨), Party Popper (🎉), Star (⭐), Camera (📸), Cake (🎂), Cherry Blossom (🌸), Ring (💍).
  * **Color Customization:** Dedicated color pickers for banner background and text colors.
  * **Independent Transform Controls:** Free X/Y canvas placement, scaling, and rotation.

---

## 🖨 Supported Printer Models & Formats

| Model | Connection Protocol | Image Canvas Resolution | Payload Format & Buffer | Format Aspect |
| :--- | :--- | :--- | :--- | :--- |
| **Instax SQUARE Link** | Bluetooth LE (GATT) | `800 × 800 px` | JPEG (`≤ 60 KB`, `900 B` chunks) | 1:1 Square |
| **Instax Link WIDE** & **Link WIDE 2™** | Bluetooth LE (GATT) | `1260 × 840 px` | JPEG (`≤ 110 KB`, `1800 B` chunks) | 3:2 Landscape *(Firmware v0101+ required; v0100 has BLE buffer bug)* |
| **Instax Mini Link 1 / 2** | Bluetooth LE (GATT) | `600 × 800 px` | JPEG (`≤ 60 KB`, `600 B` chunks) | 3:4 Portrait |
| **Instax Mini Link 3** & **mini Link+™** | Bluetooth LE (GATT) | `600 × 800 px` | JPEG (`≤ 54 KB`, `600 B` chunks) | 3:4 Portrait |
| **Instax SHARE SP-1 & SP-2** | Wi-Fi Direct (`192.168.0.251:8080`) | `600 × 800 px` | Planar RGB (`1,440 KB`, `24 × 60 KB` segments) | 3:4 Portrait |
| **Instax SHARE SP-3 SQUARE** | Wi-Fi Direct (`192.168.0.251:8080`) | `800 × 800 px` | Planar RGB (`1,920 KB`, `32 × 60 KB` segments) | 1:1 Square |

---

## 🧪 Safe Testing: Dry Run & Hardware Diagnostics (Zero Film Used!)

### 🏷️ Test Image Generator *(Contributed by [@orangekittysoftware](https://github.com/orangekittysoftware))*

Run `bin/test-image-maker.sh --app mac --format square` to generate a white JPEG
with six centered, sans-serif lines identifying the repository, code version,
printing app, and host OS name and version. Requires Bash 3 or later, Git, and
ImageMagick's `magick` command (on macOS, install with `brew install imagemagick`).
OS details describe the machine running the script, independently of `--app`.
Linux uses its distribution name and version from `/etc/os-release` when
available, otherwise its kernel name and release. On Windows, run in Bash
(such as Git Bash); OS detection also requires `powershell.exe`.

`--app` is required: `win`, `mac`, `linux`, `lrcplugin`, or `dtplugin`.
`--format` defaults to `square` (800 x 800 pixels); `wide` is 1260 x 840 and
`mini` is landscape at 800 x 600. Text is automatically sized to fit within a
20-pixel margin on all formats. The code version is the nearest Git tag reachable from HEAD
(`git describe --tags --abbrev=0`); generation fails if no tag is available.
Output is written to the repository's
`tmp/test-images/test-image-FORMAT-APP-CODEVERSION.jpg`, regardless of the current
working directory.

### 1. 🧪 "Dry Run" Mode (Full Image & BLE/Wi-Fi Throughput Test)
* **What it does:** Streams 100% of your real image chunks across Bluetooth or Wi-Fi Direct, negotiates packet framing, and waits for the printer's onboard ASIC chip to validate the image in RAM.
* **The Magic:** Once the printer validates the image without errors, our software immediately issues `PRINT_IMAGE_DOWNLOAD_CANCEL` (`0x10, 0x03` on BLE) or `CMD_RESET` (`0x50` on Wi-Fi Direct) instead of the physical exposure command.
* **Result:** **Zero film is exposed or ejected**, and it works even if your film cartridge is completely empty (`0/10`)!

### 2. ⚡ "Hardware Ping & LED Test" (Instant 1-Second Link Check)
* Queries printer firmware registers, verifies battery and film counts, and pulses the printer's front LED (`instax-square ping` or `⌘D` in the macOS app).

---

## 💡 Advice, Troubleshooting & FAQ

### Q: Do I need to use Google Chrome for Bluetooth? Does that same requirement apply to Wi-Fi printers?
* **Answer:** 
  * **For Bluetooth (BLE) Printers:** Yes, direct in-browser Web Bluetooth requires **Google Chrome**, **Microsoft Edge**, or **Brave** (or the free **Bluefy** app on iPhone) because Apple disabled Web Bluetooth in WebKit/Safari.
  * **For Wi-Fi Direct Printers (Instax SHARE SP-1/2/3):** On desktop, you can use **any browser** (Safari, Chrome, Firefox, Edge) to run the Web Studio accompanied by `legacy_web_bridge.py`. Better yet, use the native desktop apps ([`Legacy Instax Printer.app`](Legacy-Instax-Printer/macOS/) on Mac, `.vbs` on Windows, or `.sh` on Linux) with zero browser setup needed!

### Q: How do I print photos from my iPhone to a Legacy Instax Wi-Fi printer (SP-1/2/3)?
* **Answer:** You have two easy options:
  1. **Direct from iPhone (No Computer Needed):** Connect your iPhone's Wi-Fi to `INSTAX-XXXXXXXX` (Password: `11111111`) and print directly using Fujifilm's official [instax SHARE app](https://apps.apple.com/app/instax-share/id816944602) on the iOS App Store.
  2. **Print via Desktop Suite (For Collages, QR Codes & Filters):** AirDrop your photo from iPhone to your Mac in 1 second, join your Mac to `INSTAX-XXXXXXXX`, open `Legacy Instax Printer.app`, and click Print!

### Q: Why does my Instax Link WIDE fail to print, stall midway, or disconnect during image transmission?
* **Answer:** Check your printer's firmware version! Instax Link WIDE units running original factory firmware **`0100`** suffer from a known manufacturer bug with BLE packet buffer overflows, causing transmissions to stall or drop. Updating your Link WIDE to firmware **`0101`** (or newer) via Fujifilm's official *instax Link WIDE* mobile app resolves this bug completely.

### Q: Why do the web apps need a local bridge script (`legacy_web_bridge.py` or `instax_wifi_bridge.py`)?
* **Answer:** For security reasons, modern web browsers operate in a strict sandbox that prohibits client-side JavaScript from opening raw binary TCP sockets (needed for `192.168.0.251:8080`) or controlling OS-level Bluetooth hardware. The lightweight local bridge script acts as a safe, local translator between your desktop browser and the physical printer hardware.

### Q: Why do I get "Unsupported device" or "navigator.bluetooth is undefined" in the BLE Web App?
* **Answer:** Apple Safari and Mozilla Firefox do not support Web Bluetooth. Use **Google Chrome**, **Microsoft Edge**, or **Brave** on macOS, Windows, or Linux (on Linux, ensure `bluetoothd` is running) — or run `Start-iPhone-WiFi-Bridge` to use regular Safari!

### Q: The printer LED is blinking or will not connect:
* **Answer:** Instax BLE printers only allow **one** active Bluetooth connection at a time. If the printer is connected to your smartphone or tablet, briefly disable Bluetooth on that device so your computer can connect. For Legacy SP-1/2/3 printers, connect your computer's Wi-Fi to the printer's `INSTAX-XXXXXXXX` network first.

### Q: What if the printer connects during a Dry Run or status check, but refuses to print physical film?
* **Answer:** Driving the physical film ejection motor requires high current. Make sure the printer's battery is charged above 20% and the rear film door is clicked firmly shut.

---

## 📖 Software Engineering Documentation & Full Runbook
For complete architectural specifications, hardware protocol schemas (BLE GATT & Wi-Fi Direct `ISTX` framing), planar RGB scanline math, sequence diagrams, troubleshooting trees, and ISO/IEC/IEEE software engineering standards, see the dedicated:
👉 **[Full Software Documentation & Operational Runbook (`DOCUMENTATION.md`)](DOCUMENTATION.md)**  
👉 **[Developer Code Walkthrough & Annotated Source Guide (`CODE_WALKTHROUGH.md`)](CODE_WALKTHROUGH.md)**

---

## 🙏 Contributors & Acknowledgments

Special thanks to the community for feature ideas, testing, and code contributions:
* **[Clinton Wolfe (`@clintoncwolfe`)](https://github.com/clintoncwolfe)** (`u/wolf-in-tuxedo`):
  * **[PR #1](https://github.com/analogbits/Instax-Offline-Printer/pull/1):** Requested the Adobe Lightroom Classic integration and contributed Mini Link 3 testing, `LrToolkitIdentifier` & `LrExportSession` fixes, generic `INSTAX-` prefix matching, and the `InstaxCLIHelper.app` macOS TCC Bluetooth helper bundle.
* **[@orangekittysoftware](https://github.com/orangekittysoftware):**
  * **[PR #2](https://github.com/analogbits/Instax-Offline-Printer/pull/2):** Contributed `bin/test-image-maker.sh`, a cross-platform Instax test card generator for stamping prints with the app, code version, and OS details across Wide, Square, and Mini formats.
* **`u/pola-dude`:**
  * Suggested and tested the **Legacy Instax Printer** (`SP-1`, `SP-2` & `SP-3` Wi-Fi Direct) application suite.

