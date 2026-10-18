================================================================================
          INSTAX OFFLINE PRINTER SUITE — WINDOWS INSTRUCTIONS & HELP
================================================================================

This folder contains offline applications for Windows 10, Windows 11, and future
versions of Windows. 100% private, zero cloud connection, zero internet required.

--------------------------------------------------------------------------------
⚠️ ESSENTIAL PREREQUISITES (PRIOR TO FIRST USE!)
--------------------------------------------------------------------------------
1. STEP 1 — UPDATE PRINTER FIRMWARE PRIOR TO USE:
   Always ensure your printer is on the latest firmware before desktop printing!
   * Instax Link WIDE on initial factory firmware 0100 has a known manufacturer
     BLE buffer bug that causes image transfers to stall or fail.
   * Updating to firmware 0101 (or newer) via the official mobile app resolves
     this completely.

2. STEP 2 — TURN OFF BLUETOOTH ON YOUR PHONE / TABLET:
   Instax printers only allow ONE Bluetooth connection at a time!
   * Once updated, turn OFF Bluetooth in iOS/Android Settings on your phone.
   * If your phone stays connected, the printer will be INVISIBLE to Windows.
   * Power-cycle the printer; it will immediately appear on Windows.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
OPTION 1: ALL-IN-ONE STANDALONE APPLICATION (RECOMMENDED — ZERO INSTALL)
--------------------------------------------------------------------------------
* No Python, no drivers, and no administrator setup required!
* Runs natively on 100% of Windows 10 and Windows 11 computers.

How to Run:
  1. Double-click "Instax-Printer.vbs" (Silent, recommended — no black console window).
     OR double-click "Instax-Printer.bat".
  2. The application opens instantly in its own dedicated, native desktop window.
  3. Click "Add Photo...", drag/zoom/rotate to frame, select artistic filters,
     and click "Connect Instax (BLE)".
  4. Once connected, your real-time film remaining (e.g. 10/10) and battery level
     will appear at the top.
  5. Click "Print Physical Photo"!

How it Works:
  It uses the built-in Microsoft Edge engine that is pre-installed on Windows 10/11
  to run locally with direct access to the Windows Bluetooth Low Energy stack (WinRT).

--------------------------------------------------------------------------------
OPTION 2: PYTHON DESKTOP GUI (Tkinter)
--------------------------------------------------------------------------------
For users who prefer a native Python GUI:
  1. Ensure Python 3 is installed (from python.org or the Microsoft Store).
     (Make sure "Add Python to PATH" is checked during install).
  2. Double-click "Windows-Run.bat".
  3. The launcher will automatically verify dependencies ('bleak', 'pillow') and
     launch "InstaxPrinterGUI.pyw".
  * NOTE: If Python is not installed, "Windows-Run.bat" will automatically launch
    the All-in-One Standalone app instead, so you are never left stuck!

--------------------------------------------------------------------------------
OPTION 3: COMMAND-LINE PRINTING
--------------------------------------------------------------------------------
To print directly from Command Prompt or PowerShell:
  Windows-Print-Console.bat photo.jpg

--------------------------------------------------------------------------------
OPTION 4: PRINT FROM IPHONE / IPAD SAFARI: "Start-iPhone-WiFi-Bridge.bat"
--------------------------------------------------------------------------------
Apple disables the Web Bluetooth API inside iPhone Safari and iPad Safari.
Double-click "Start-iPhone-WiFi-Bridge.bat" (or run `python instax_printer.py --serve`)
to host the Web App on your home Wi-Fi (http://192.168.1.x:8765) with a scannable
QR code. Point your iPhone camera at the QR code to open it in regular iPhone
Safari and print any photo from your iPhone Camera Roll via your PC's Bluetooth!

How BLE Link iPhone Printing Works:
  Your PC uses TWO separate radios simultaneously:
  1. Wi-Fi connects to your Home router to communicate with your iPhone.
  2. Bluetooth connects directly to your Instax Link printer.
  (Both devices stay on your normal Home Wi-Fi with full internet access).

Looking for Legacy Wi-Fi Direct Printers (SP-1, SP-2, SP-3)?
  See the dedicated "Legacy-Instax-Printer/Windows/" folder and run
  "Legacy-Instax-Printer.vbs" (Transfer photos to PC and click Print!).

--------------------------------------------------------------------------------
WINDOWS TROUBLESHOOTING & HELP:
--------------------------------------------------------------------------------
* Windows Bluetooth Pairing:
  Turn on your printer (press and hold power button). Windows 10 and 11 do not
  even require pairing in Windows Settings first—the application scans and connects
  directly over Bluetooth Low Energy.

* Virtual Machines (Parallels Desktop / VMware / VirtualBox):
  If you are running Windows inside a virtual machine on a Mac:
  - Mac VMs DO NOT have access to the Mac's internal Bluetooth radio by default.
  - Windows in a VM will report "Bluetooth is turned off" or "No Bluetooth adapter".
  - SOLUTION: Either run the native macOS application on your Mac, or plug an
    inexpensive USB Bluetooth dongle into your Mac and pass it through to the VM
    (Parallels menu -> Devices -> USB & Bluetooth -> [Your Dongle] -> Connect to Windows).

* Anti-Virus / SmartScreen Notice:
  Because these scripts and batch files run local offline tools, Windows Defender
  or SmartScreen may show "Windows protected your PC". Click "More info" -> "Run anyway".

* Low Battery / Cover Open:
  If the battery drops below 6%, the app will safeguard the print mechanism and
  prompt you to plug in the printer via USB-C/Micro-USB before printing.
  If the film door is unlatched, the status badge will indicate "Cover Open!".

================================================================================
