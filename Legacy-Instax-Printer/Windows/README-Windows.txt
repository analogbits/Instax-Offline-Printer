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

IPHONE & IPAD SAFARI PRINTING (3 EASY SETUPS):
------------------------------------------------
Your PC has a single Wi-Fi antenna. Because Instax SHARE SP-1/2/3 printers
broadcast their own Wi-Fi ("INSTAX-XXXXXXXX"), connecting to the printer
disconnects your PC from your home router. You have 3 easy ways to print:

  • SETUP 1 (All-Wireless Direct — Recommended):
    1. Connect Windows Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
    2. Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
       (Ignore the "No Internet Connection" notice on iOS).
    3. Double-click "Start-iPhone-WiFi-Bridge.bat".
    4. Open the displayed URL (http://192.168.0.x:8089) in regular iPhone Safari.
    5. Pick photos from your Camera Roll and tap "Print Over Wi-Fi Direct"!

  • SETUP 2 (Dual Network — PC on Ethernet):
    Plug PC into home router with Ethernet, and connect PC Wi-Fi to
    "INSTAX-XXXXXXXX". iPhone stays on Home Wi-Fi and prints via Safari!

  • SETUP 3 (USB / Cloud Transfer):
    Transfer photo to PC, then open "Legacy-Instax-Printer.vbs" and click "Print"!

ZERO CHROME REQUIREMENT FOR WI-FI PRINTERS:
--------------------------------------------
Unlike Bluetooth LE printers (which need Chrome for Web Bluetooth), Instax
SHARE Wi-Fi Direct printers use standard HTTP & TCP. Regular Apple Safari on
macOS and iOS works 100% natively with zero extra apps required!


