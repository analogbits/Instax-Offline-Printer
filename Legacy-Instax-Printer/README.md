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
| **`macOS/`** | macOS 13+ (Universal) | `Legacy Instax Printer.app`, `legacy-instax` CLI, `LegacyInstaxPrinterWeb.html`, `legacy_web_bridge.py`, `build.sh` |
| **`Windows/`** | Windows 10 / 11 | `LegacyInstaxPrinterGUI.pyw`, `legacy_instax_printer.py`, `Legacy-Instax-Printer.vbs`, `LegacyInstaxPrinterWeb.html`, `legacy_web_bridge.py`, `Legacy-Instax-Printer.bat` |
| **`Linux/`** | Ubuntu / Fedora / Arch | `LegacyInstaxPrinterGUI.py`, `legacy_instax_printer.py`, `Legacy-Instax-Printer-Linux.sh`, `LegacyInstaxPrinterWeb.html`, `legacy_web_bridge.py` |
| **`Web-WiFi-Offline/`** | Any Desktop Browser | `LegacyInstaxPrinterWeb.html` (Standalone Offline Studio) + `legacy_web_bridge.py` (Local TCP Helper) |

---

## 📱 Have Photos on an iPhone or iPad? AirDrop to Mac in 1 Second!

You do **not** need any complicated bridges or network hopping between your phone and computer:

1. **AirDrop to Mac:** On your iPhone, select your photo in the Photos app $\to$ tap **Share** $\to$ tap **AirDrop** to your Mac. The photo lands instantly in your Mac's Downloads folder.
2. **Connect Mac to Printer:** In your Mac's Wi-Fi menu, connect to your printer's **`INSTAX-XXXXXXXX`** network (Default Password: **`11111111`**).
3. **Click Print:** Open **`Legacy Instax Printer.app`** (or [`LegacyInstaxPrinterWeb.html`](Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)), pick your photo, and click **Print Over Wi-Fi Direct**!

*(If you are away from your computer, simply connect your iPhone's Wi-Fi directly to `INSTAX-XXXXXXXX` and use Fujifilm's official Instax SHARE app).*

---

## 🌐 Safari vs Chrome: Zero Chrome Required!
* **Web Bluetooth** requires Chrome/Edge/Brave because Apple blocks the Web Bluetooth API in WebKit/Safari.
* **Wi-Fi Direct printers use standard HTTP and TCP/IP.**
* Regular **Safari on iPhone, iPad, and macOS works 100% natively out of the box** for all Instax SHARE SP-1, SP-2, and SP-3 printers. **No Chrome, no Bluefy, and no extra apps required!**

---

## 📶 Interactive Wi-Fi Test & Hardware Diagnostics
The Web Studio includes a built-in **`[📶 Wi-Fi Test / Points]`** diagnostic modal:
* Scans all nearby 2.4 GHz Wi-Fi access points via native OS tools (`networksetup` on macOS, `netsh` on Windows, `nmcli` on Linux).
* Probes TCP port `8080` at `192.168.0.251` to verify physical Instax SHARE hardware responsiveness.
* Tests the built-in Virtual SP-1/2/3 Simulator at `127.0.0.1:18080` for safe zero-film testing.

