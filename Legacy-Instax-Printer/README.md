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
| **`macOS/`** | macOS 13+ (Universal) | `Legacy Instax Printer.app`, `legacy-instax` CLI, `Start-iPhone-WiFi-Bridge.command`, `legacy_web_bridge.py`, `LegacyInstaxPrinterWeb.html`, `build.sh` |
| **`Windows/`** | Windows 10 / 11 | `LegacyInstaxPrinterGUI.pyw`, `legacy_instax_printer.py`, `Start-iPhone-WiFi-Bridge.bat`, `legacy_web_bridge.py`, `LegacyInstaxPrinterWeb.html`, `Legacy-Instax-Printer.bat` |
| **`Linux/`** | Ubuntu / Fedora / Arch | `LegacyInstaxPrinterGUI.py`, `legacy_instax_printer.py`, `Start-iPhone-WiFi-Bridge.sh`, `legacy_web_bridge.py`, `LegacyInstaxPrinterWeb.html`, `Legacy-Instax-Printer-Linux.sh` |
| **`Web-WiFi-Offline/`** | iPhone / iPad / Any Browser | `LegacyInstaxPrinterWeb.html` + `legacy_web_bridge.py` + one-click `Start-iPhone-WiFi-Bridge.*` launchers |

---

## 📱 iPhone & iPad Safari Support (Local Wi-Fi Bridge)

Want to print photos directly from your **iPhone or iPad camera roll** without installing any legacy apps?

1. **Start the Bridge on Your Computer**:
   - **Mac**: Double-click `Start-iPhone-WiFi-Bridge.command` (in `macOS/`, `Web-WiFi-Offline/`, or your desktop folder).
   - **Windows**: Double-click `Start-iPhone-WiFi-Bridge.bat` (in `Windows/` or `Web-WiFi-Offline/`).
   - **Linux**: Run `./Start-iPhone-WiFi-Bridge.sh` (in `Linux/` or `Web-WiFi-Offline/`).
2. **Open Safari on your iPhone/iPad**:
   - The terminal shows your local Wi-Fi URL (e.g. `http://192.168.1.77:8089`).
   - Open that link in regular Safari on your iPhone or iPad connected to the same home Wi-Fi network.
3. **Pick & Print**:
   - Tap **"Choose Photo"** to select from your iPhone photo library.
   - Adjust collage, framing, captions, or QR codes.
   - Tap **"Print Physical Photo"** (or **"Dry Run"** for a zero-film test).
   - Your computer beams the print job to your Instax SHARE SP-1, SP-2, or SP-3 printer automatically!

