# 📸 Legacy Instax Printer — Offline Wi-Fi Direct Suite (`SP-1` • `SP-2` • `SP-3`)

A dedicated, 100% offline desktop and web application suite for Fujifilm's classic **Wi-Fi Direct** printers:
- **Fujifilm Instax SHARE SP-1™** (`600 × 800 px` • Instax Mini Film)
- **Fujifilm Instax SHARE SP-2™** (`600 × 800 px` • Instax Mini Film)
- **Fujifilm Instax SHARE SP-3™** (`800 × 800 px` • Instax SQUARE Film)

---

## ✨ Key Features Across All Platforms

1. **Direct Wi-Fi TCP Protocol Engine (`192.168.0.251:8080`, Default PIN `1111`)**:
   - Implements the complete big-endian Fujifilm Instax SHARE TCP packet framing (`0x24` commands / `0x2A` responses) and 5-session handshake (`PrePrint 1..8`, `PrinterLock`, `Reset`, `PrepImage + SendImage`, `TriggerPrint + StatusPoll`).
   - Encodes images into exact **Column-Major Planar RGB** (`1,440,000 bytes` across 24 segments for SP-1/SP-2; `1,920,000 bytes` across 32 segments with 90° clockwise alignment for SP-3).
2. **Dry Run (0-Film Test Mode) & Built-in Virtual SP Simulator**:
   - **Dry Run Mode** transmits all 24 or 32 planar RGB segments to your printer's RAM buffer to verify Wi-Fi stability and PIN authentication, then skips the physical print trigger (`0x53`) so **zero film is wasted**.
   - **Virtual SP Simulator (`127.0.0.1:18080`)** emulates a real SP-1, SP-2, or SP-3 locally so you can test the entire app and CLI without turning on your physical printer.
3. **Full Creative Studio**:
   - **Multi-Photo Collage Studio** (`Single`, `2-Up Vertical`, `2-Up Horizontal`, `3-Photo Grid`, `4-Photo 2×2 Grid`, `3-Photo Strip`, `6-Photo Contact Sheet`) with live **Collage Border Spacing** (`0–28 px`).
   - **Analog Creative FX & Film Emulation Studio (Ported from PolaroidEngine)**:
     - Warmth & Color Temperature dial (`-1.0` Cool Arctic Blue to `+1.0` Golden Amber Sunlight)
     - Radial Lens Vignette (`0%` to `100%`)
     - Authentic Analog Light Leaks (`Red Film Burn`, `Golden Sunburst Flare`, `Sunset Glow`, `Prismatic Rainbow Spectrum`) across 8 placements
     - Silver halide tactile film grain rendered at native print resolution
     - Analog wear & tear (curved hair fibers, hairline scratches, fine dust motes, chemical roller pod spread wave)
     - Vintage glowing 90s LED digital datestamps (`'YY MM DD`) in Amber Gold (`#FF8C00`), Ruby Red (`#FF2525`), Emerald Green (`#00E676`), or Crisp White (`#F5F5F7`)
     - 1-Click `🎲 Surprise Me!` retro randomizer & `↺ Reset`
   - **Scannable QR Code Generator** (`Website URL`, `Custom Text`, `Phone`, `Email`, `Wi-Fi Access`, `Map Coordinates`).
   - **Fujifilm SHARE Artistic Filters** (`Normal`, `Fujifilm Intelligence`, `Monochrome`, `Sepia`, `Vivid Velvia`, `Classic Chrome`) + bottom caption & date stamp.

---

## 📂 Included Platform Editions

| Folder | Platform | Application Files |
| :--- | :--- | :--- |
| **`macOS/`** | macOS 13+ (Universal) | `Legacy Instax Printer.app`, `legacy-instax` CLI, `Start-iPhone-WiFi-Bridge.command`, `legacy_web_bridge.py`, `build.sh` |
| **`Windows/`** | Windows 10 / 11 | `LegacyInstaxPrinterGUI.pyw`, `legacy_instax_printer.py`, `Legacy-Instax-Printer.vbs`, `Start-iPhone-WiFi-Bridge.bat`, `legacy_web_bridge.py`, `Legacy-Instax-Printer.bat` |
| **`Linux/`** | Ubuntu / Fedora / Arch | `LegacyInstaxPrinterGUI.py`, `legacy_instax_printer.py`, `Legacy-Instax-Printer-Linux.sh`, `Start-iPhone-WiFi-Bridge.sh`, `legacy_web_bridge.py` |
| **`Web-WiFi-Offline/`** | Any Browser / iPhone / Android | `LegacyInstaxPrinterWeb.html` (Canonical Offline Studio) + `legacy_web_bridge.py` (Local TCP Helper) |

---

## 💻 Desktop Application Runbooks (macOS, Windows & Linux)

Unlike web browsers, all **native desktop applications** in this suite connect **directly to your printer's TCP socket (`192.168.0.251:8080`)** using your computer's native OS network stack. **No bridge helpers or web servers are required!**

### 🔌 The 3-Step Connection Rule (Same for Mac, Windows & Linux):
1. **Power on your printer** (Instax SHARE SP-1, SP-2, or SP-3).
2. **Join the printer's Wi-Fi network** from your computer's Wi-Fi menu:
   - **SSID:** `INSTAX-XXXXXXXX` (printed on the barcode sticker under the battery/film door, e.g. `INSTAX-82193812`)
   - **Default Wi-Fi Password:** `11111111`
   - *(Your OS may show "No Internet" or "Connected without Internet" — this is completely normal because the printer is an offline direct hotspot).*
3. **Launch your desktop app and click Connect!** The live 10-LED film counter and battery level will light up immediately.

---

### 🍏 1. macOS Desktop Guide (`Legacy-Instax-Printer/macOS/`)

#### Native macOS SwiftUI Application (`Legacy Instax Printer.app`):
* **How to run:** Double-click **`Legacy Instax Printer.app`** (or unzip `Legacy-Instax-Printer-macOS.zip` and move it to your `/Applications` folder).
* **Step-by-step workflow:**
  1. Join your printer's **`INSTAX-XXXXXXXX`** Wi-Fi in the macOS menu bar.
  2. Open **`Legacy Instax Printer.app`**.
  3. Select your model (**SP-2**, **SP-1**, or **SP-3**) in the top toolbar.
  4. Click **`📡 Connect`**. The top indicator turns green, displaying your printer's model, and the authentic 10-LED gauge reflects your remaining film sheets.
  5. Drag-and-drop any photo into the window (or click **`📂 Open Image File...`**).
  6. *(Optional)* Apply filters (including the 12 new optical, digital, and structural matrix effects like Solarisation, Aerochrome, Cross-Processing, Duotone Cyanotype, Split-Toning, 1-bit Dithering, Chromatic Aberration, CRT Scanlines, and Pixel Sorting), add light leaks, date stamps, or build a collage in the right-hand Creative Inspector.
  7. Click **`🖨 Print Over Wi-Fi Direct`**!
* **13-Inch Laptop Screen Support:** The native window dynamically adapts with a flexible minimum size (1040×680, ideal 1240×840) and responsive scrollable sidebars, preventing any clipping or off-screen overflow on compact MacBook displays.
* **Built-in Safe Testing:**
  - Toggle **`🧪 Dry Run (0-Film)`** to transmit 100% of the image data over Wi-Fi and verify PIN authentication without dispensing physical film.
  - Switch the target to **`Virtual SP Simulator`** to practice framing and collages completely offline on your Mac even when away from your physical printer.
* **Apple Photos Extension:** Right-click any photo in Apple Photos $\to$ **Share $\to$ Legacy Instax Share** to beam it directly into the printer queue.

#### macOS Command-Line Tool (`legacy-instax`):
* **High-Performance Standalone Binary** compiled natively with Swift. Requires zero Python or external libraries.
* **Query printer status & film count:**
  ```bash
  ./legacy-instax status
  ```
* **Verify transfer without wasting film (Dry-Run):**
  ```bash
  ./legacy-instax print my_photo.jpg --model SP-2 --dry-run
  ```
* **Print physical photo:**
  ```bash
  ./legacy-instax print my_photo.jpg --model SP-2
  ```
* **Start local virtual simulator:**
  ```bash
  ./legacy-instax sim --port 18080 --model SP-2
  ```

---

### 🪟 2. Windows Desktop Guide (`Legacy-Instax-Printer/Windows/`)

#### Zero-Install Standalone Window (`Legacy-Instax-Printer.vbs`):
* **Recommended for everyday use:** Double-click **`Legacy-Instax-Printer.vbs`** in Windows Explorer.
* It launches the studio immediately in a dedicated, distraction-free desktop window with no black terminal windows.
* Requires no Python, pip, or administrator privileges.

#### Python Desktop GUI (`LegacyInstaxPrinterGUI.pyw` / `Legacy-Instax-Printer.bat`):
* **How to run:** Double-click **`Legacy-Instax-Printer.bat`** (or right-click `LegacyInstaxPrinterGUI.pyw` $\to$ *Run with Python*).
* **Step-by-step workflow:**
  1. Click the Wi-Fi icon in the Windows taskbar and connect to **`INSTAX-XXXXXXXX`** (Password: `11111111`).
  2. Launch the desktop app.
  3. Select your model (`SP-1`, `SP-2`, or `SP-3`) from the dropdown.
  4. Click **`Connect / Status`**. The 10-LED film counter updates live from the printer's EEPROM.
  5. Click **`Open Photo`**, adjust pan/zoom, choose your analog effects, and click **`Print Over Wi-Fi Direct`**.

#### Windows Command-Line Engine (`legacy_instax_printer.py`):
* Run in PowerShell or Command Prompt:
  ```powershell
  python legacy_instax_printer.py status
  python legacy_instax_printer.py print photo.jpg --model SP-2 --pin 1111
  python legacy_instax_printer.py print photo.jpg --dry-run
  ```

---

### 🐧 3. Linux Desktop Guide (`Legacy-Instax-Printer/Linux/`)

#### Zero-Install Standalone Launcher (`Legacy-Instax-Printer-Linux.sh`):
* **How to run:** Double-click **`Legacy-Instax-Printer-Linux.sh`** or execute in terminal:
  ```bash
  chmod +x Legacy-Instax-Printer-Linux.sh
  ./Legacy-Instax-Printer-Linux.sh
  ```
* Runs natively inside your installed browser (Chromium, Chrome, Brave, Edge) in app-window mode.

#### Native Tkinter Desktop Application (`LegacyInstaxPrinterGUI.py`):
* **How to run:**
  ```bash
  python3 LegacyInstaxPrinterGUI.py
  ```
* **Step-by-step workflow:**
  1. Connect your Wi-Fi interface to the printer:
     ```bash
     nmcli dev wifi connect "INSTAX-XXXXXXXX" password "11111111"
     ```
  2. In the app, select your printer model (`SP-1`, `SP-2`, or `SP-3`) and click **`Connect`**.
  3. Load your image, customize borders or filters, and click **`Print Over Wi-Fi Direct`**.

#### Linux Command-Line Engine:
* ```bash
  python3 legacy_instax_printer.py status
  python3 legacy_instax_printer.py print photo.jpg --model SP-2
  python3 legacy_instax_printer.py print photo.jpg --dry-run
  ```

---

## 📱 Printing from iPhone or iPad (3 Easy Options)

### Option 1: Mobile Safari Web Studio via Local Wi-Fi Bridge (Zero iOS Apps Needed!)
Use this suite's full visual studio (collages, QR codes, artistic filters, dry-run) directly from regular iPhone or iPad Safari:
1. **Connect Computer to Printer:** On your Mac, PC, or Linux computer, connect Wi-Fi to your printer's **`INSTAX-XXXXXXXX`** network (Factory Password: **`11111111`**).
2. **Launch Wi-Fi Bridge:**
   - **Mac:** Double-click `Start-Legacy-iPhone-WiFi-Bridge.command` (on Desktop or in `macOS/`).
   - **Windows:** Double-click `Start-iPhone-WiFi-Bridge.bat` (in `Windows/`).
   - **Linux:** Run `./Start-iPhone-WiFi-Bridge.sh` (in `Linux/`).
   - *(Or run `python3 legacy_web_bridge.py` in your terminal)*.
3. **Connect iPhone to Printer Wi-Fi:** On your iPhone, open **Settings $\to$ Wi-Fi** and join the same **`INSTAX-XXXXXXXX`** network.
   *(iOS may show "No Internet Connection" — this is normal! Tap "Keep Trying Wi-Fi" or stay connected).*
4. **Open Safari on iPhone & Print:**
   - In regular iPhone Safari, open the address displayed in the terminal: `http://192.168.0.x:8089` (e.g. `http://192.168.0.2:8089`).
   - Pick photos from your Camera Roll, frame collages, apply filters, and tap **Print Over Wi-Fi Direct**!

---

### Option 2: 1-Second AirDrop to Mac (Fastest for Mac Users)
If you don't want to switch Wi-Fi networks on your iPhone at all:
1. **AirDrop to Mac:** In Apple Photos on iPhone, tap **Share $\to$ AirDrop** and send the photo to your Mac (1 second).
2. **Connect Mac to Printer:** In your Mac's Wi-Fi menu, join your printer's **`INSTAX-XXXXXXXX`** network (Default Password: **`11111111`**).
3. **Click Print:** Open **`Legacy Instax Printer.app`** (or [`LegacyInstaxPrinterWeb.html`](Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)), pick your photo from Downloads, and click **Print Over Wi-Fi Direct**!

---

### Option 3: Direct iPhone-to-Printer Printing (No Computer Needed)
You can print directly from your iPhone or iPad using Fujifilm's official **instax SHARE** app:
1. **Power On Printer:** Turn on your Instax SHARE SP-1, SP-2, or SP-3 printer.
2. **Join Printer Wi-Fi:** On your iPhone, open **Settings $\to$ Wi-Fi** and join **`INSTAX-XXXXXXXX`** (Default Password: **`11111111`**).
3. **Open App & Print:** Open the free [Fujifilm instax SHARE app](https://apps.apple.com/app/instax-share/id816944602) on your iPhone, select your photo, and tap Print!

---

## 🌐 Why Web Browsers Need a Local Helper (Raw TCP vs HTTP)
* Unlike modern Web Bluetooth printers, older Instax SHARE printers (SP-1, SP-2, SP-3) communicate over **raw binary TCP sockets on port 8080** (`0x24` command bytes / `0x2A` responses).
* All web browsers (Safari, Chrome, Edge, Firefox) operate inside a strict security sandbox that prohibits client-side JavaScript from opening raw TCP stream sockets directly.
* That is why:
  * **Native Desktop Apps (`Legacy Instax Printer.app`, `.vbs`, `.sh`):** Connect directly to `192.168.0.251:8080` with native OS sockets (zero helpers needed).
  * **Desktop Web Studio (`LegacyInstaxPrinterWeb.html`):** Uses the lightweight local helper `python3 legacy_web_bridge.py` on your computer to bridge browser requests to the printer's TCP socket.

---

## 📶 Interactive Wi-Fi Test & Hardware Diagnostics
The Web Studio includes a built-in **`[📶 Wi-Fi Test / Points]`** diagnostic modal:
* Scans all nearby 2.4 GHz Wi-Fi access points via native OS tools (`networksetup` on macOS, `netsh` on Windows, `nmcli` on Linux).
* Probes TCP port `8080` at `192.168.0.251` to verify physical Instax SHARE hardware responsiveness.
* Tests the built-in Virtual SP-1/2/3 Simulator at `127.0.0.1:18080` for safe zero-film testing.

---

## 🎨 Creative Decoration Studio: Doodle Stickers, Frames & Custom Banners
* **💖 Romance & Love Doodles:** "love" calligraphy, distressed "I LOVE YOU", "forever" ribbon heart, scribble heart, winged heart, love letter envelope, radiating doodle heart, heart balloons, Cupid's arrow, and heart hands.
* **🎉 Seasonal Celebrations:** Birthday cake with burning candles, bunting garland, "Happy Holidays" starburst, "Season's Greetings" wreath, Christmas tree, stockings, friendly ghost, jack-o'-lantern, bats, summer flip-flops, seashells, cherry blossoms, and mimosa.
* **🖼️ 18 Decorative Frames:** Baroque filigree lace oval, wedding botanical corners, stained glass mosaic, golden bokeh sparkles, night fireworks, hanging twin hearts garland, holiday pine garland, autumn foliage, sprocket 35mm, gold foil, rose gold, postage stamp, and classic borders.
* **🎯 Free Canvas Positioning & Drag Focus:** Drag any sticker or banner freely on the preview canvas without moving the background photo, toggle dedicated Drag Target focus (`🎯 Auto`, `🖼️ Photo`, `🎨 Sticker`, `🎀 Banner`), or use fine-grain numeric X & Y offset sliders (`-1.0` to `+1.0`) with scale, opacity, and 360° rotation.
* **🎀 Custom Banner Maker:** 6 styles (3D folded ribbon, calligraphy brush, frosted pill badge, luggage tag, postal stamp, bunting garland), icon accents (❤️, ✨, 🎉, ⭐, 📸, 🎂, 🌸, 💍), custom text, and custom background & text colors.

