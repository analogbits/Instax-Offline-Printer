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

PRINT FROM IPHONE / IPAD SAFARI (LOCAL WI-FI BRIDGE):
------------------------------------------------------
  chmod +x Start-iPhone-WiFi-Bridge.sh
  ./Start-iPhone-WiFi-Bridge.sh
  Open the displayed URL (http://<your-linux-ip>:8089) in Safari on your iPhone
  or iPad to print photos directly from your camera roll!

