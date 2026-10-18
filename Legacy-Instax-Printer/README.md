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

## 📱 iPhone & iPad Safari Printing Guide: Single Wi-Fi Radio Explained

Want to print photos directly from your **iPhone or iPad Camera Roll** to an Instax SHARE SP-1, SP-2, or SP-3 without needing obsolete iOS apps?

### 💡 Understanding the Single Wi-Fi Radio Constraint
* Modern BLE printers (like SQUARE Link) use **two separate radios** (Wi-Fi for network/iPhone + Bluetooth for printer).
* **Legacy Instax SHARE printers only have Wi-Fi** (they act as their own Wi-Fi access point: `INSTAX-XXXXXXXX` at `192.168.0.251:8080`).
* Because computers and phones typically have **one Wi-Fi antenna**, connecting to `INSTAX-XXXXXXXX` disconnects you from your home router.
* **We designed 3 easy setups to handle this effortlessly:**

---

### 📶 Setup 1: All-Wireless Direct (Recommended — Zero Cables)
Both your computer and iPhone connect directly to the printer's private Wi-Fi network:
1. **Power On Printer:** Press and hold the power button on your SP-1, SP-2, or SP-3 until the LEDs illuminate.
2. **Connect Computer to Printer Wi-Fi:**
   - In your Mac/PC Wi-Fi menu, select **`INSTAX-XXXXXXXX`** (Factory Password: **`11111111`**).
3. **Connect iPhone to Printer Wi-Fi:**
   - On your iPhone, open **Settings $\to$ Wi-Fi** and select the same **`INSTAX-XXXXXXXX`** (Password: **`11111111`**).
   - *(iOS will display "No Internet Connection" — this is completely normal! Tap "Keep Trying Wi-Fi" or stay connected).*
4. **Launch Local Bridge on Computer:**
   - **Mac:** Double-click `Start-iPhone-WiFi-Bridge.command` (in `macOS/`, `Web-WiFi-Offline/`, or Desktop).
   - **Windows:** Double-click `Start-iPhone-WiFi-Bridge.bat` (in `Windows/` or `Web-WiFi-Offline/`).
   - **Linux:** Run `./Start-iPhone-WiFi-Bridge.sh`.
   - *(Or run `python3 legacy_instax_printer.py --serve`)*
5. **Open Safari on iPhone & Print:**
   - The terminal displays your local address: `http://192.168.0.x:8089` (e.g. `http://192.168.0.2:8089`).
   - Open that address in **regular iPhone Safari** (or scan the QR code).
   - Tap **"📁 Choose Photo"**, adjust framing/collages, and tap **"🖨 Print Over Wi-Fi Direct"**!
   - Your iPhone sends the photo to your computer, which streams the planar RGB segments directly to `192.168.0.251:8080`!

---

### 🔌 Setup 2: Dual Network (Mac/PC on Ethernet + Wi-Fi to Printer)
If your computer is connected to your home router with an Ethernet cable:
1. Your computer stays online on your Home LAN via Ethernet (`192.168.1.x`), while its Wi-Fi card connects to `INSTAX-XXXXXXXX` (`192.168.0.x`).
2. Your iPhone stays on regular Home Wi-Fi (`192.168.1.x`).
3. Open `http://192.168.1.x:8089` in Safari on your iPhone and print with zero network switching on your phone!

---

### ⚡ Setup 3: 1-Second AirDrop to Mac (Fastest for iPhone Users)
If you don't want to switch Wi-Fi networks on your iPhone at all:
1. On iPhone: In Apple Photos, tap **Share $\to$ AirDrop** and send the photo to your Mac (1 second).
2. The photo appears in your Mac's Downloads folder.
3. On Mac (connected to `INSTAX-XXXXXXXX`): Open **`Legacy Instax Printer.app`** or **`LegacyInstaxPrinterWeb.html`**, click **Add Photo**, and click **Print**!

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

