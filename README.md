# 📸 Instax Offline Printer Applications Suite
### Universal 100% Offline Printing for macOS, Windows & Linux

[![Try BLE Web App Online](https://img.shields.io/badge/BLE_Web_App-Mini_%7C_SQUARE_%7C_WIDE-3b82f6?style=for-the-badge&logo=googlechrome&logoColor=white)](https://analogbits.github.io/Instax-Offline-Printer/)
[![Try Legacy Wi-Fi Web App](https://img.shields.io/badge/Legacy_Web_App-SHARE_SP--1_%7C_SP--2_%7C_SP--3-10b981?style=for-the-badge&logo=wifi&logoColor=white)](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)
[![Download Offline Suite](https://img.shields.io/badge/Download-Offline_Suite_(.zip)-22c55e?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/analogbits/Instax-Offline-Printer/releases/latest)

> 🚀 **Try either Web App right now in your browser (works on macOS, Windows, and Linux):**  
> - **🔵 [👉 Launch Web Bluetooth Printer (SQUARE Link • Link WIDE • Mini Link)](https://analogbits.github.io/Instax-Offline-Printer/)** *(Works in Google Chrome, Microsoft Edge, Brave, and Opera on Mac, Windows, Linux, Android, and Chromebooks)*  
> - **🎞️ [👉 Launch Legacy Wi-Fi Direct Web Printer (Instax SHARE SP-1 • SP-2 • SP-3)](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)** *(Short link: [`analogbits.github.io/Instax-Offline-Printer/legacy.html`](https://analogbits.github.io/Instax-Offline-Printer/legacy.html) — Works on Mac, Windows, and Linux)*

A complete, self-contained suite of native standalone applications, Adobe Lightroom Classic & Linux Darktable plugins, command-line tools, and zero-install offline utilities for printing directly to:
* **Bluetooth Low Energy (BLE) Printers:** **Fujifilm Instax SQUARE Link**, **Instax Link WIDE / WIDE 2**, and **Instax Mini Link (1, 2, 3, & Link+)**
* **Legacy Wi-Fi Direct Printers:** **Fujifilm Instax SHARE SP-1**, **SP-2**, and **SP-3 SQUARE** (`192.168.0.251:8080`)

---

## 🔒 100% Offline & Private Guarantee
* **No Internet Required:** None of these applications connect to the cloud, send telemetry, or require accounts.
* **Direct Hardware Communication:** Communicates directly with your printer's Bluetooth GATT characteristics (Link series) or Wi-Fi Direct TCP socket (`192.168.0.251:8080`, SHARE SP series).
* **Permanent Future-Proofing:** Even if Fujifilm's mobile apps or servers ever become obsolete, this offline suite ensures you can always print from your desktop forever.

---

## ⚠️ CRITICAL: Turn OFF Bluetooth on Your Phone / Tablet First!
> [!IMPORTANT]
> **Instax printers only allow ONE Bluetooth connection at a time.**
> If your printer was previously paired with an iPhone, iPad, or Android device:
> 1. The printer **completely stops broadcasting** its Bluetooth beacons while connected to your phone.
> 2. It will appear **invisible** or fail to connect on your computer.
> 3. **Solution:** Temporarily turn **OFF** Bluetooth on your smartphone or iPad (or close the official Instax app), then turn your printer off and back on. It will immediately show up on your computer.

---

## 🚀 Quick Start Guide by Operating System

### 🍏 1. macOS (`macOS/` & `Legacy-Instax-Printer/macOS/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax Printer.app`** | Double-click in Finder | Full native Swift desktop app for BLE Link printers (WIDE, SQUARE, Mini). Apple Photos/iCloud browser, interactive pan/zoom/rotate framing, artistic filters, live film/battery gauges, Multi-Photo Collage Studio, QR Print, debug console (`⌘D`), and offline guide (`⌘?`). |
| **`Legacy Instax Printer.app`** | Double-click in Finder | Dedicated native Swift desktop app for Wi-Fi Direct **Instax SHARE SP-1, SP-2 & SP-3** printers with built-in Wi-Fi network scanner dropdown (`INSTAX-XXXXXXXX`), live 10-LED film counter, Collage Studio, QR Print, and built-in Virtual SP Simulator. |
| **`instax-square`** / **`legacy-instax`** | `./instax-square print photo.jpg` | High-performance standalone CLI binaries for BLE and Wi-Fi Direct printers. No Python or runtime needed. |
| **`macOS-Run.command`** | Double-click in Finder | Emergency drag-and-drop terminal launcher. |
| **`install-cli.sh`** | Run in Terminal | Installs `instax-square` system-wide to `/usr/local/bin`. |

---

### 🪟 2. Windows (`Windows/` & `Legacy-Instax-Printer/Windows/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer.vbs`** *(Recommended)* | Double-click in Explorer | **Zero-Install Standalone App.** Opens instantly in a dedicated native desktop window with zero command-line popups. Uses the pre-installed Windows 10/11 Microsoft Edge engine to connect directly to the Windows Bluetooth stack (WinRT). No Python needed! |
| **`Windows-Run.bat`** | Double-click | Python GUI launcher (`InstaxPrinterGUI.pyw` / `LegacyInstaxPrinterGUI.py`). Auto-detects dependencies and falls back to the All-in-One app if Python is not installed. |
| **`instax_printer.py`** / **`legacy_instax_printer.py`** | `python instax_printer.py print photo.jpg` | Cross-platform BLE and Wi-Fi Direct command-line engines with Collage, QR Code, Caption, and Dry Run support. |

---

### 🐧 3. Linux (`Linux/` & `Legacy-Instax-Printer/Linux/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer-Linux.sh`** *(Recommended)* | Double-click or `./Instax-Printer-Linux.sh` | **Zero-Install Standalone App.** Launches immediately in a borderless native window using Chromium, Google Chrome, Brave, or Edge. No Python, pip, or Tkinter required! |
| **`linux-run.sh`** | Double-click or `./linux-run.sh` | Python Tkinter desktop GUI launcher (`InstaxPrinterGUI.py` / `LegacyInstaxPrinterGUI.py`). |
| **`instax-printer.desktop`** | Copy to `~/.local/share/applications/` | Adds Instax Printer to your Linux application menu. |
| **`instax_printer.py`** / **`legacy_instax_printer.py`** | `python3 instax_printer.py print photo.jpg` | Standalone Linux command-line printers for BLE (BlueZ) and Wi-Fi Direct (`SP-1/2/3`). |

---

### 🌐 4. Universal Web Apps (`Web-Bluetooth-Offline/` & `Legacy-Instax-Printer/Web-WiFi-Offline/`)
* **🔵 BLE Link Web App (SQUARE Link, Link WIDE & Mini Link):**
  * **Live Online:** [https://analogbits.github.io/Instax-Offline-Printer/](https://analogbits.github.io/Instax-Offline-Printer/)
  * **Offline File:** [`Web-Bluetooth-Offline/InstaxPrinterWeb.html`](Web-Bluetooth-Offline/InstaxPrinterWeb.html)
  * **OS Compatibility:** Works on **macOS, Windows 10/11, Linux, Android, and ChromeOS** in Google Chrome, Microsoft Edge, Brave, Opera, or Arc.
* **🎞️ Legacy Wi-Fi Direct Web App (Instax SHARE SP-1, SP-2 & SP-3):**
  * **Live Online:** [https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html](https://analogbits.github.io/Instax-Offline-Printer/Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html) *(or [`/legacy.html`](https://analogbits.github.io/Instax-Offline-Printer/legacy.html))*
  * **Offline File:** [`Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html`](Legacy-Instax-Printer/Web-WiFi-Offline/LegacyInstaxPrinterWeb.html)
  * **OS Compatibility:** Works in **any modern browser on macOS, Windows, and Linux** (includes built-in Virtual SP-1/2/3 Simulator + `legacy_web_bridge.py` for live Wi-Fi scanning and raw TCP socket printing to `192.168.0.251:8080`).

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
* **Live Wi-Fi Direct Scanner Dropdown:** Click **Scan** to detect nearby `INSTAX-XXXXXXXX` 2.4 GHz hotspots (`CoreWLAN` / `system_profiler` on macOS, `netsh wlan` on Windows, `nmcli` on Linux) and join in 1 click.
* **Honest Hardware LED Telemetry:** Displays unlit LEDs (`-- / 10 Film`) when offline and lights up exact green LEDs (`0–10` sheets remaining & `0–4` battery bars) once connected to your printer.
* **Bit-Exact 90° Clockwise Scanline Planar RGB Encoding:** Verified `60,000`-byte planar R, G, B segment streaming (`24` segments / `1,440,000` bytes for SP-1/SP-2; `32` segments / `1,920,000` bytes for SP-3).

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

---

## 🖨 Supported Printer Models & Formats

| Model | Connection Protocol | Image Canvas Resolution | Payload Format & Buffer | Format Aspect |
| :--- | :--- | :--- | :--- | :--- |
| **Instax SQUARE Link** | Bluetooth LE (GATT) | `800 × 800 px` | JPEG (`≤ 60 KB`, `900 B` chunks) | 1:1 Square |
| **Instax Link WIDE** & **Link WIDE 2™** | Bluetooth LE (GATT) | `1260 × 840 px` | JPEG (`≤ 110 KB`, `1800 B` chunks) | 3:2 Landscape |
| **Instax Mini Link 1 / 2** | Bluetooth LE (GATT) | `600 × 800 px` | JPEG (`≤ 60 KB`, `600 B` chunks) | 3:4 Portrait |
| **Instax Mini Link 3** & **mini Link+™** | Bluetooth LE (GATT) | `600 × 800 px` | JPEG (`≤ 54 KB`, `600 B` chunks) | 3:4 Portrait |
| **Instax SHARE SP-1 & SP-2** | Wi-Fi Direct (`192.168.0.251:8080`) | `600 × 800 px` | Planar RGB (`1,440 KB`, `24 × 60 KB` segments) | 3:4 Portrait |
| **Instax SHARE SP-3 SQUARE** | Wi-Fi Direct (`192.168.0.251:8080`) | `800 × 800 px` | Planar RGB (`1,920 KB`, `32 × 60 KB` segments) | 1:1 Square |

---

## 🧪 Safe Testing: Dry Run & Hardware Diagnostics (Zero Film Used!)

### 🏷️ Test Image Generator *(Contributed by [@orangekittysoftware](https://github.com/orangekittysoftware) / [@clintoncwolfe](https://github.com/clintoncwolfe))*

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

### Q: Why do I get "Unsupported device" or "navigator.bluetooth is undefined" in the BLE Web App?
* **Answer:** Apple Safari and Mozilla Firefox do not support Web Bluetooth. Use **Google Chrome**, **Microsoft Edge**, or **Brave** on macOS, Windows, or Linux (on Linux, ensure `bluetoothd` is running).

### Q: The printer LED is blinking or will not connect:
* **Answer:** Instax BLE printers only allow **one** active Bluetooth connection at a time. If the printer is connected to your smartphone or tablet, briefly disable Bluetooth on that device so your computer can connect. For Legacy SP-1/2/3 printers, connect your computer's Wi-Fi to the printer's `INSTAX-XXXXXXXX` network first.

### Q: What if the printer connects during a Dry Run or status check, but refuses to print physical film?
* **Answer:** Driving the physical film ejection motor requires high current. Make sure the printer's battery is charged above 20% and the rear film door is clicked firmly shut.

---

## 🙏 Contributors & Acknowledgments

Special thanks to our open-source contributors:
* **[@orangekittysoftware](https://github.com/orangekittysoftware) / [@clintoncwolfe](https://github.com/clintoncwolfe)** (*Clinton Wolfe* / `u/wolf-in-tuxedo`):
  * **[PR #1](https://github.com/analogbits/Instax-Offline-Printer/pull/1):** Adobe Lightroom Classic plugin testing on Instax Mini Link 3, `LrToolkitIdentifier` & `LrExportSession` fixes, generic `INSTAX-` prefix matching, and the `InstaxCLIHelper.app` macOS TCC Bluetooth helper bundle.
  * **[PR #2](https://github.com/analogbits/Instax-Offline-Printer/pull/2):** Cross-platform Instax test card generator (`bin/test-image-maker.sh`) for stamping prints with the app, code version, and OS details across Wide, Square, and Mini formats.

