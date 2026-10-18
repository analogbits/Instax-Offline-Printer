===========================================================================
LEGACY INSTAX PRINTER — macOS EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

Native macOS SwiftUI Application, Apple Photos Share Extension, and CLI tool
for Fujifilm's Wi-Fi Direct Instax SHARE printers:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

HOW TO USE ON macOS:
--------------------
1. Power on your Instax SHARE SP-1, SP-2, or SP-3 printer.
2. Click the Wi-Fi icon in your macOS menu bar and join your printer's
   network ("INSTAX-XXXXXXXX").
3. Open "Legacy Instax Printer.app" (also placed directly on your Desktop
   and in /Applications).
4. Default printer IP is 192.168.0.251, Port 8080, and Factory PIN is 1111.
5. Click "Connect Wi-Fi" to view your 10-LED film count and battery status,
   or toggle "Virtual SP Simulator" to test locally without a physical printer.
6. Use "Test Transfer (0-Film Dry Run)" to verify 100% of the Wi-Fi Direct
   transfer with zero film wasted!

COMMAND LINE (CLI) USAGE:
-------------------------
  ./legacy-instax --status
  ./legacy-instax --simulate --model sp2 --status
  ./legacy-instax --model sp2 --dry-run photo.jpg
  ./legacy-instax --model sp3 photo.jpg
  ./legacy-instax --serve

HAVE PHOTOS ON IPHONE OR IPAD? AIRDROP TO MAC IN 1 SECOND!
-----------------------------------------------------------
1. On iPhone: Select photo in Photos app -> Share -> AirDrop to Mac.
2. On Mac: Connect Mac Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
3. Open "Legacy Instax Printer.app" -> pick photo from Downloads -> click Print!

LOCAL WEB STUDIO BACKEND (OPTIONAL):
------------------------------------
If you want to use the offline browser studio (LegacyInstaxPrinterWeb.html),
run `python3 legacy_web_bridge.py` to bridge browser requests to the
printer's raw TCP socket (192.168.0.251:8080).

ZERO CHROME REQUIREMENT FOR WI-FI PRINTERS:
--------------------------------------------
Unlike Bluetooth LE printers (which need Chrome for Web Bluetooth), Instax
SHARE Wi-Fi Direct printers use standard HTTP & TCP. Regular Apple Safari on
macOS and iOS works 100% natively with zero extra apps required!


