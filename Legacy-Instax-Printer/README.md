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

