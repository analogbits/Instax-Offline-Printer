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

PRINTING FROM IPHONE OR IPAD:
-----------------------------
Option 1 (Safari Web Studio via Local Wi-Fi Bridge):
  Connect Linux Wi-Fi to "INSTAX-XXXXXXXX" and run:
  `./Start-iPhone-WiFi-Bridge.sh` (or `python3 legacy_web_bridge.py`).
  Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX", open http://192.168.0.x:8089 in
  regular iPhone Safari, frame your photos, and tap Print!

Option 2 (Print iPhone Photos via Linux):
  Transfer photo to your Linux PC (via local network, USB, or cloud), connect
  Wi-Fi to "INSTAX-XXXXXXXX", and run `./Legacy-Instax-Printer-Linux.sh` to print!

Option 3 (Direct from iPhone without PC):
  Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111) and print
  using the official "instax SHARE" app from the iOS App Store.

LOCAL WEB STUDIO BACKEND (OPTIONAL):
------------------------------------
If you prefer running the browser studio (LegacyInstaxPrinterWeb.html),
run `python3 legacy_web_bridge.py` to bridge browser requests to the
printer's raw binary TCP socket (192.168.0.251:8080).


