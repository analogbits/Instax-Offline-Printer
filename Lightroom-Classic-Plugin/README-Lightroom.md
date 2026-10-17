# 📸 Instax Offline Printer — Lightroom Classic & Darktable Plugins (v1.5.3)

Print directly from **Adobe Lightroom Classic** (macOS & Windows) or **Darktable** (Linux, Windows & macOS) to your **Fujifilm Instax printer** over Bluetooth Low Energy or Wi-Fi Direct with zero cloud hops, zero phone sync, and zero quality loss!

Supports **all** Fujifilm Instax portable printers:
- **Instax Link WIDE & Link WIDE 2™** (`1260 × 840` BLE)
- **Instax SQUARE Link** (`800 × 800` BLE)
- **Instax Mini Link 1 / 2 / 3 & mini Link+™** (`600 × 800` BLE)
- **Legacy Instax SHARE SP-1 & SP-2** (`600 × 800` Wi-Fi Direct `192.168.0.251:8080`)
- **Legacy Instax SHARE SP-3 SQUARE** (`800 × 800` Wi-Fi Direct `192.168.0.251:8080`)

---

## 💻 Platform Compatibility Overview

| Operating System | Photo Editor Integration | Bundled CLI Engine inside `Instax-Printer.lrplugin` |
| :--- | :--- | :--- |
| **macOS** (Apple Silicon & Intel) | **Adobe Lightroom Classic** (`Instax-Printer.lrplugin`) + **Darktable** | `bin/mac/InstaxCLIHelper.app` + `bin/mac/instax-square` + `bin/mac/legacy-instax` (Native Swift/CoreBluetooth/CoreText) |
| **Windows 10 / 11** | **Adobe Lightroom Classic** (`Instax-Printer.lrplugin`) + **Darktable** | `bin/win/instax-square.bat` + `bin/win/legacy-instax.bat` (`instax_printer.py` & `legacy_instax_printer.py` via WinRT BLE / TCP) |
| **Linux** (Ubuntu / Fedora / Arch) | **Darktable 4.x+** (`Linux-Darktable-Plugin/instax_darktable.lua`) | `bin/linux/instax-square` + `bin/linux/legacy-instax` (`instax_printer.py` & `legacy_instax_printer.py` via BlueZ BLE / TCP) |

---

## 🚀 How to Install in Adobe Lightroom Classic (macOS & Windows)

1. Open **Adobe Lightroom Classic**.
2. In the top menu bar, click **File $\to$ Plug-in Manager...** (`Cmd+Option+Shift+,` on macOS or `Ctrl+Alt+Shift+,` on Windows).
3. In the bottom-left corner of the Plug-in Manager window, click **Add**.
4. Select the **`Instax-Printer.lrplugin`** folder in this directory and click **Add Plug-in** (or **Select Folder** on Windows).
5. You will see a green status light next to **Instax Offline Printer** showing **"Installed and running"**.
6. Click **Done**.

> **macOS Note:** On your first print or Dry Run from Lightroom Classic, macOS will ask to allow **"Instax CLI Helper"** (`InstaxCLIHelper.app`) to access **Bluetooth**. Click **Allow**. This dedicated background helper bundle ensures macOS TCC grants Bluetooth access cleanly even though Adobe Lightroom Classic itself does not declare `NSBluetoothAlwaysUsageDescription`.
>
> **Windows Note:** Ensure Python 3.9+ is installed (`python --version`). On first print, the plugin's `bin/win/` engine automatically uses `bleak` and `Pillow` (`pip install bleak pillow qrcode`).

---

## 🐧 How to Install in Darktable (Linux, Windows & macOS)

Since Adobe does not release Lightroom Classic natively for Linux, we include a full-featured **Darktable Lua Export Storage Plugin** in **`Linux-Darktable-Plugin/instax_darktable.lua`**:

1. Install Python 3 dependencies if not already installed:
   ```bash
   pip install bleak pillow qrcode
   ```
2. Copy the plugin script to your Darktable config directory:
   ```bash
   mkdir -p ~/.config/darktable/lua/contrib
   cp Linux-Darktable-Plugin/instax_darktable.lua ~/.config/darktable/lua/contrib/
   echo 'require "contrib/instax_darktable"' >> ~/.config/darktable/luarc
   ```
3. Launch **Darktable**, open the **Export** module in the Lighttable view, and choose **"Instax Offline Printer (BLE & Wi-Fi Direct)"** under **target storage**!

---

## 🖨 Two Easy Ways to Print from Lightroom Classic

### Method 1: Instant Quick Print (`Plug-in Extras`)
1. In Lightroom's **Library** or **Develop** module, select one or more photos.
2. In the top menu bar, click **File $\to$ Plug-in Extras $\to$ Print to Instax...** (or **Library $\to$ Plug-in Extras $\to$ Print to Instax...**).
3. Choose:
   - **Target Printer:** *⚡ Auto-Detect BLE Printer*, *WIDE*, *SQUARE*, *Mini*, or *Legacy SHARE SP-1 / SP-2 / SP-3*
   - **Color Mode:** *instax-Rich Mode* or *instax-Natural Mode*
   - **Framing & Matte Border Color:** *Fill / Crop*, *Fit (Letterbox)*, or *Stretch*
   - **Collage Layout:** Print multiple selected photos individually or combine 2–9 selected Lightroom photos into a single Instax Collage!
   - **QR Code & Bottom Caption:** Optional scannable QR badge and text caption
   - **🧪 Dry Run (0-Film Test):** Check this box to test the full Bluetooth/Wi-Fi Direct image transfer to your printer's RAM with **0 film used**!
4. Click **Print Now**.

### Method 2: Via Lightroom Export Dialog (`Cmd+Shift+E` / `Ctrl+Shift+E`)
1. Select your photo(s) and click **File $\to$ Export...** (`Cmd+Shift+E` on macOS / `Ctrl+Shift+E` on Windows).
2. At the top dropdown (**Export To:**), choose **Instax Offline Printer**.
3. Configure your printer model, color mode, framing, collage layout, QR code, caption, or **Dry Run (0-Film Test)** and click **Export** (you can also save your favorite setup as a Lightroom Export Preset!).

---

## ⚠️ Essential Troubleshooting Tips

1. **Turn OFF Bluetooth on your phone/tablet first (for BLE Link printers):**  
   Instax Link printers only advertise to one Bluetooth Central device at a time. If your phone's Bluetooth is active, the printer may stay locked to your phone.
2. **Keep the printer battery charged (>20%):**  
   Driving the physical film ejection rollers requires high motor current. If the battery is low, the printer can connect over BLE/Wi-Fi during a Dry Run or status check, but the motor will refuse to eject film until recharged.
3. **Black protective cover on fresh packs:**  
   If you just loaded a fresh pack of film, make sure the initial black plastic dark slide has been ejected.

---

### 🙏 Acknowledgments
Special thanks to **[@orangekittysoftware](https://github.com/orangekittysoftware)** (`wolf-in-tuxedo`) for testing on Instax Mini Link 3 and contributing PR #1 (`LrToolkitIdentifier`, `LrExportMenuItems`, `LrExportSession`, generic `INSTAX-` prefix matching, and the `InstaxCLIHelper.app` macOS TCC Bluetooth launcher).
