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

PRINTING FROM IPHONE OR IPAD:
-----------------------------
Option 1 (Safari Web Studio via Local Wi-Fi Bridge):
  Connect Mac Wi-Fi to "INSTAX-XXXXXXXX" and double-click
  "Start-Legacy-iPhone-WiFi-Bridge.command" (on Desktop or in macOS/).
  Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX", open http://192.168.0.x:8089 in
  regular iPhone Safari, frame your photos, and tap Print!

Option 2 (1-Second AirDrop to Mac):
  AirDrop photo from iPhone to your Mac in 1 second, join Mac Wi-Fi to
  "INSTAX-XXXXXXXX", open "Legacy Instax Printer.app", and click Print!

Option 3 (Direct from iPhone without Mac):
  Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111) and print
  using the official "instax SHARE" app from the iOS App Store.

LOCAL WEB STUDIO BACKEND (OPTIONAL):
------------------------------------
If you want to use the offline browser studio (LegacyInstaxPrinterWeb.html),
run `python3 legacy_web_bridge.py` to bridge browser requests to the
printer's raw binary TCP socket (192.168.0.251:8080).


