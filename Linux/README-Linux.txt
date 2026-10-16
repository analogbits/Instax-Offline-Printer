================================================================================
           INSTAX OFFLINE PRINTER SUITE — LINUX INSTRUCTIONS & HELP
================================================================================

This folder contains offline applications for Linux (Ubuntu, Debian, Fedora,
Arch Linux, and Raspberry Pi OS on Raspberry Pi 3/4/5).

--------------------------------------------------------------------------------
⚠️ CRITICAL PREREQUISITE: TURN OFF BLUETOOTH ON YOUR PHONE / TABLET
--------------------------------------------------------------------------------
Instax printers only allow ONE Bluetooth connection at a time!
If the printer was previously paired with your iPhone, iPad, or Android device:
  1. The printer stops broadcasting beacons and will be INVISIBLE to Linux.
  2. SOLUTION: Turn OFF Bluetooth in iOS/Android Settings on your phone,
     then turn the printer off and back on. It will immediately appear on Linux.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
OPTION 1: ALL-IN-ONE STANDALONE APPLICATION (RECOMMENDED — ZERO INSTALL)
--------------------------------------------------------------------------------
* No Python, no pip packages, and no Tkinter required!
* Zero-dependency execution using your system's Chromium, Chrome, Brave, or Edge.

How to Run:
  1. Open a terminal in this directory and execute:
       ./Instax-Printer-Linux.sh
     (Or double-click "Instax-Printer-Linux.sh" in your file manager).
  2. The app launches immediately in a dedicated desktop window.
  3. Load your photo, adjust framing/zoom/filters, connect your Instax via BLE,
     and print!

How it Works:
  Communicates directly with the Linux system BlueZ Bluetooth stack via D-Bus.

--------------------------------------------------------------------------------
OPTION 2: PYTHON DESKTOP GUI (Tkinter)
--------------------------------------------------------------------------------
For users who prefer running the native Python / Tkinter GUI:
  1. Run:
       ./linux-run.sh
  2. The script checks for Python 3 and required packages.
     - On Ubuntu/Debian, install packages with:
         sudo apt install python3 python3-pip python3-tk bluez
     - On Fedora:
         sudo dnf install python3 python3-pip python3-tkinter bluez
     - On Arch Linux:
         sudo pacman -S python python-pip tk bluez bluez-utils
  * NOTE: If Python or Tkinter is missing, "linux-run.sh" will automatically
    launch the All-in-One Standalone app instead, so you can always print!

--------------------------------------------------------------------------------
INSTALLING THE DESKTOP SHORTCUT:
--------------------------------------------------------------------------------
To add Instax Printer to your Linux application launcher menu:
  cp instax-printer.desktop ~/.local/share/applications/
  update-desktop-database ~/.local/share/applications/ 2>/dev/null

--------------------------------------------------------------------------------
LINUX TROUBLESHOOTING & HELP:
--------------------------------------------------------------------------------
* Bluetooth Permissions / BlueZ Service:
  Ensure the BlueZ Bluetooth daemon is active:
    sudo systemctl enable --now bluetooth
  Ensure your user belongs to the 'bluetooth' group:
    sudo usermod -aG bluetooth $USER

* Virtual Machines (Parallels Desktop / VirtualBox / KVM):
  Virtual machines do NOT have direct access to the host's internal Bluetooth radio.
  If running Linux inside a VM, you must plug in a physical USB Bluetooth dongle
  and pass the USB device directly into the VM.

* Modern Linux & PEP 668 ("externally-managed-environment"):
  On Ubuntu 24.04+, Debian 12+, and Fedora 40+, system Python protects against pip.
  Use Option 1 (./Instax-Printer-Linux.sh) to bypass this completely, or install
  packages via apt: 'sudo apt install python3-bleak python3-pil python3-tk'.

================================================================================
