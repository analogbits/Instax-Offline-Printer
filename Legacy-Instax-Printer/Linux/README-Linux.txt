===========================================================================
LEGACY INSTAX PRINTER — LINUX EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

100% Offline Wi-Fi Direct Desktop Application & CLI for Fujifilm Instax SHARE:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

REQUIREMENTS:
-------------
  sudo apt install python3 python3-tk python3-pil

HOW TO RUN:
-----------
  chmod +x Legacy-Instax-Printer-Linux.sh
  ./Legacy-Instax-Printer-Linux.sh

COMMAND LINE USAGE:
-------------------
  python3 legacy_instax_printer.py --status
  python3 legacy_instax_printer.py --model SP-2 --dry-run photo.jpg
  python3 legacy_instax_printer.py --model SP-3 photo.jpg
  python3 legacy_instax_printer.py --serve

IPHONE & IPAD SAFARI PRINTING (3 EASY SETUPS):
------------------------------------------------
Your Linux machine has a single Wi-Fi antenna. Because Instax SHARE SP-1/2/3
printers broadcast their own Wi-Fi ("INSTAX-XXXXXXXX"), connecting to the
printer disconnects your PC from your home router. You have 3 easy ways to print:

  • SETUP 1 (All-Wireless Direct — Recommended):
    1. Connect Linux Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
    2. Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
       (Ignore the "No Internet Connection" notice on iOS).
    3. Run "./Start-iPhone-WiFi-Bridge.sh" (or `python3 legacy_instax_printer.py --serve`).
    4. Open the displayed URL (http://192.168.0.x:8089) in regular iPhone Safari.
    5. Pick photos from your Camera Roll and tap "Print Over Wi-Fi Direct"!

  • SETUP 2 (Dual Network — Linux on Ethernet):
    Plug Linux machine into home router with Ethernet, and connect Wi-Fi to
    "INSTAX-XXXXXXXX". iPhone stays on Home Wi-Fi and prints via Safari!

  • SETUP 3 (Local Network Transfer):
    Transfer photo to Linux machine, then open Legacy Instax Printer and click "Print"!

ZERO CHROME REQUIREMENT FOR WI-FI PRINTERS:
--------------------------------------------
Unlike Bluetooth LE printers (which need Chrome for Web Bluetooth), Instax
SHARE Wi-Fi Direct printers use standard HTTP & TCP. Regular Apple Safari on
macOS and iOS works 100% natively with zero extra apps required!


