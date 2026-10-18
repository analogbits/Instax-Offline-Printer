===========================================================================
LEGACY INSTAX PRINTER — WINDOWS EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

100% Offline Wi-Fi Direct Desktop Application & CLI for Fujifilm Instax SHARE:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

HOW TO CONNECT & PRINT ON WINDOWS:
----------------------------------
1. Turn on your Instax SHARE SP-1, SP-2, or SP-3 printer.
2. Open Windows Wi-Fi settings and connect to your printer's Wi-Fi Direct
   hotspot named "INSTAX-XXXXXXXX".
   (Default Wi-Fi password if prompted by Windows is 11111111, and default
   printer PIN inside the app is 1111).
3. Double-click "Legacy-Instax-Printer.vbs" (or "Legacy-Instax-Printer.bat").
4. Click "Connect / Status" to read your printer's model, firmware, battery,
   and remaining film count.
5. Use "Test Transfer (0-Film Dry Run)" to test the full Wi-Fi Direct image
   transfer without using any film, or click "Print Over Wi-Fi Direct".

COMMAND LINE (CLI) USAGE:
-------------------------
  python legacy_instax_printer.py --status
  python legacy_instax_printer.py --model SP-2 --dry-run photo.jpg
  python legacy_instax_printer.py --model SP-3 photo.jpg
  python legacy_instax_printer.py --serve

HAVE PHOTOS ON IPHONE OR IPAD? EASY 1-STEP TRANSFER:
------------------------------------------------------
Transfer the photo to your PC (via iCloud, USB, email, or local network),
connect your PC Wi-Fi to "INSTAX-XXXXXXXX", open "Legacy-Instax-Printer.vbs",
and click "Print Over Wi-Fi Direct"!

LOCAL WEB STUDIO BACKEND (OPTIONAL):
------------------------------------
If you prefer running the browser studio (LegacyInstaxPrinterWeb.html),
run `python legacy_web_bridge.py` to bridge browser requests to the
printer's raw TCP socket (192.168.0.251:8080).

ZERO CHROME REQUIREMENT FOR WI-FI PRINTERS:
--------------------------------------------
Unlike Bluetooth LE printers (which need Chrome for Web Bluetooth), Instax
SHARE Wi-Fi Direct printers use standard HTTP & TCP. Works in all browsers natively!


