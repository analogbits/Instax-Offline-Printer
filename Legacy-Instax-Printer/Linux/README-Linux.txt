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

HAVE PHOTOS ON IPHONE OR IPAD? EASY TRANSFER:
------------------------------------------------
Transfer the photo to your Linux computer (via local network, USB, or cloud),
connect your Wi-Fi to "INSTAX-XXXXXXXX", and run `./Legacy-Instax-Printer-Linux.sh`
to print!

LOCAL WEB STUDIO BACKEND (OPTIONAL):
------------------------------------
If you prefer running the browser studio (LegacyInstaxPrinterWeb.html),
run `python3 legacy_web_bridge.py` to bridge browser requests to the
printer's raw TCP socket (192.168.0.251:8080).

ZERO CHROME REQUIREMENT FOR WI-FI PRINTERS:
--------------------------------------------
Unlike Bluetooth LE printers (which need Chrome for Web Bluetooth), Instax
SHARE Wi-Fi Direct printers use standard HTTP & TCP. Works in all browsers natively!


