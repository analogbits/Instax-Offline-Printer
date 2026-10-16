# 📸 Instax Offline Printer Applications Suite
### Universal 100% Offline Printing for macOS, Windows & Linux

[![Try Web App Online](https://img.shields.io/badge/Web_App-Launch_in_Browser-3b82f6?style=for-the-badge&logo=googlechrome&logoColor=white)](https://analogbits.github.io/Instax-Offline-Printer/)
[![Download Offline Suite](https://img.shields.io/badge/Download-Offline_Suite_(.zip)-22c55e?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/analogbits/Instax-Offline-Printer/releases/latest)

> 🚀 **Try it right now in your browser (no download or installation required):**  
> **[👉 Launch Web Bluetooth Printer](https://analogbits.github.io/Instax-Offline-Printer/)** *(Works in Google Chrome, Microsoft Edge, Brave, and Opera on Mac, Windows, Linux, Android, and Chromebooks)*

A complete, self-contained suite of native standalone applications, command-line tools, and zero-install offline utilities for printing directly to **Fujifilm Instax SQUARE Link**, **Instax Link WIDE / WIDE 2**, and **Instax Mini Link (1, 2, 3, & Link+)** printers over Bluetooth Low Energy.

---

## 🔒 100% Offline & Private Guarantee
* **No Internet Required:** None of these applications connect to the cloud, send telemetry, or require accounts.
* **Direct Point-to-Point Bluetooth:** Communicates directly with your printer's hardware GATT characteristics.
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

### 🍏 1. macOS (`macOS/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax Square Printer.app`** | Double-click in Finder | Full native Swift desktop app. Apple Photos/iCloud browser, interactive pan/zoom/rotate framing, artistic filters, live film/battery gauges, collage printing, debug console (`⌘D`), and offline guide (`⌘?`). |
| **`instax-square`** | `./instax-square print photo.jpg` | High-performance standalone CLI binary. No Python or runtime needed. |
| **`macOS-Run.command`** | Double-click in Finder | Emergency drag-and-drop terminal launcher. |
| **`install-cli.sh`** | Run in Terminal | Installs `instax-square` system-wide to `/usr/local/bin`. |

---

### 🪟 2. Windows (`Windows/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer.vbs`** *(Recommended)* | Double-click in Explorer | **Zero-Install Standalone App.** Opens instantly in a dedicated native desktop window with zero command-line popups. Uses the pre-installed Windows 10/11 Microsoft Edge engine to connect directly to the Windows Bluetooth stack (WinRT). No Python needed! |
| **`Instax-Printer.bat`** | Double-click | Standalone app launcher via batch script. |
| **`Windows-Run.bat`** | Double-click | Python GUI launcher. Auto-detects dependencies and launches `InstaxPrinterGUI.pyw`. If Python is not installed, it automatically launches the All-in-One app so you are never stuck. |
| **`Windows-Print-Console.bat`** | Drag image onto `.bat` | Quick drag-and-drop command-line printing. |

---

### 🐧 3. Linux (`Linux/`)
| Component | How to Run | Description |
| :--- | :--- | :--- |
| **`Instax-Printer-Linux.sh`** *(Recommended)* | Double-click or `./Instax-Printer-Linux.sh` | **Zero-Install Standalone App.** Launches immediately in a borderless native window using Chromium, Google Chrome, Brave, or Edge. No Python, pip, or Tkinter required! |
| **`linux-run.sh`** | Double-click or `./linux-run.sh` | Python Tkinter desktop GUI launcher. Auto-falls back to the standalone app if Python packages are missing. |
| **`instax-printer.desktop`** | Copy to `~/.local/share/applications/` | Adds Instax Printer to your Linux application menu. |
| **`instax_printer.py`** | `python3 instax_printer.py print photo.jpg` | Standalone Linux command-line printer. |

---

### 🌐 4. Universal Web Bluetooth (`Web-Bluetooth-Offline/`)
* **Live Online Web App:** [https://analogbits.github.io/Instax-Offline-Printer/](https://analogbits.github.io/Instax-Offline-Printer/)
* **Offline File:** `InstaxPrinterWeb.html` (Double-click to open locally in Chrome, Edge, or Brave).
  * 100% zero-install, works across **Mac, Windows, Linux, Android, and Chromebooks**.
  * Uses the browser's native Web Bluetooth API to connect directly to your printer with zero installations.
  * Features live canvas drag-to-pan, 0.5×–2.5× zoom, 90° rotation, fit modes (Crop, Letterbox, Stretch), film simulations (instax-Rich vs instax-Natural), artistic filters (B&W Mono, Sepia, Vintage, Cool, Vivid), and real-time film remaining / battery telemetry.

---

## 🖨 Supported Printer Models & Formats

| Model | Image Canvas Resolution | Hardware Buffer Limit | Format Aspect |
| :--- | :--- | :--- | :--- |
| **Instax SQUARE Link** | `800 × 800 px` | 60 KB (61,440 B) | 1:1 Square |
| **Instax Link WIDE** & **Link WIDE 2™** | `1260 × 840 px` (or `800 × 1260 px`) | 110 KB (112,640 B) | 3:2 Landscape |
| **Instax Mini Link 1 / 2** | `600 × 800 px` | 60 KB (61,440 B) | 3:4 Portrait |
| **Instax Mini Link 3** & **mini Link+™** | `600 × 800 px` | Safe 54 KB budget (tight 55 KB ASIC buffer) | 3:4 Portrait |

---

## 💡 Advice, Troubleshooting & FAQ

### Q: Why doesn't Bluetooth work inside a Virtual Machine (Parallels / VMware / VirtualBox)?
* **Answer:** Hypervisors on macOS do **not** virtualize the Mac's internal Bluetooth Low Energy (BLE) radio into guest operating systems. Guest Windows or Linux will report *"Bluetooth is turned off"* or *"No adapter found"*.
* **Solution:** Run the app natively on the host Mac, or plug an inexpensive physical USB Bluetooth 4.0/5.0 dongle into your Mac and pass it through to the VM via the Parallels menu: **Devices $\to$ USB & Bluetooth $\to$ [Dongle] $\to$ Connect to Windows/Linux**.

### Q: Why do I get "Unsupported device" or "navigator.bluetooth is undefined"?
* **Answer:** Apple Safari and Mozilla Firefox do not support Web Bluetooth. Use **Google Chrome**, **Microsoft Edge**, or **Brave**.

### Q: The printer LED is blinking or will not connect:
* **Answer:** Instax printers only allow **one** active Bluetooth connection at a time. If the printer is connected to your smartphone or tablet, briefly disable Bluetooth on that device so your computer can connect.

### Q: What does "Cover Open" mean?
* **Answer:** The rear film door is slightly unlatched. Push firmly on the back door until it clicks into place.
