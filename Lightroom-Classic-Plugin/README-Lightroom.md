# 📸 Instax Offline Printer — Adobe Lightroom Classic Plugin (v1.5.1)

Print directly from **Adobe Lightroom Classic** to your **Fujifilm Instax printer** over Bluetooth Low Energy or Wi-Fi Direct with zero cloud hops, zero phone sync, and zero quality loss!

Supports **all** Fujifilm Instax portable printers:
- **Instax Link WIDE & Link WIDE 2™** (`1260 × 840` BLE)
- **Instax SQUARE Link** (`800 × 800` BLE)
- **Instax Mini Link 1 / 2 / 3 & mini Link+™** (`600 × 800` BLE)
- **Legacy Instax SHARE SP-1 & SP-2** (`600 × 800` Wi-Fi Direct `192.168.0.251:8080`)
- **Legacy Instax SHARE SP-3 SQUARE** (`800 × 800` Wi-Fi Direct `192.168.0.251:8080`)

---

## 🚀 How to Install in Adobe Lightroom Classic

1. Open **Adobe Lightroom Classic**.
2. In the top menu bar, click **File $\to$ Plug-in Manager...** (or press `Cmd+Option+Shift+,` on macOS).
3. In the bottom-left corner of the Plug-in Manager window, click **Add**.
4. Select the **`Instax-Printer.lrplugin`** folder in this directory and click **Add Plug-in**.
5. You will see a green status light next to **Instax Offline Printer** showing **"Installed and running"**.
6. Click **Done**.

> **macOS Bluetooth Permission Note:** On your first print or Dry Run from Lightroom Classic, macOS will ask to allow **"Instax CLI Helper"** (`InstaxCLIHelper.app`) to access **Bluetooth**. Click **Allow**. This dedicated background helper bundle ensures macOS TCC grants Bluetooth access cleanly even though Adobe Lightroom Classic itself does not declare `NSBluetoothAlwaysUsageDescription`.

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

### Method 2: Via Lightroom Export Dialog (`Cmd+Shift+E`)
1. Select your photo(s) and click **File $\to$ Export...** (`Cmd+Shift+E`).
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
