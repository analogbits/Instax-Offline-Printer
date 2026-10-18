===========================================================================
LEGACY INSTAX PRINTER — WEB EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

Single-file offline HTML5 Studio ("LegacyInstaxPrinterWeb.html") + Local
Wi-Fi Direct TCP Bridge ("legacy_web_bridge.py") for Fujifilm Instax SHARE:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

---------------------------------------------------------------------------
📱 PRINTING FROM IPHONE OR IPAD:
---------------------------------------------------------------------------
Option 1 — Direct iPhone-to-Printer (No Computer Needed):
  Connect iPhone Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111) and print
  directly using Fujifilm's official "instax SHARE" app on the iOS App Store.

Option 2 — Creative Desktop Suite (Collages, QR Codes, Filters):
  AirDrop photo from iPhone to your Mac in 1 second, connect Mac to
  "INSTAX-XXXXXXXX", and click Print in LegacyInstaxPrinterWeb.html!

---------------------------------------------------------------------------
💻 LOCAL WEB STUDIO BACKEND (legacy_web_bridge.py):
---------------------------------------------------------------------------
Instax SHARE printers communicate over raw binary TCP sockets (port 8080).
Because web browsers block direct raw TCP sockets from webpages for security,
run `python3 legacy_web_bridge.py` on your computer to bridge browser requests
to the printer at 192.168.0.251:8080.

---------------------------------------------------------------------------
📶 INTERACTIVE WI-FI TEST & HARDWARE DIAGNOSTICS:
---------------------------------------------------------------------------
Click the "[📶 Wi-Fi Test / Points]" button in the header of the Web Studio to:
  • Scan all nearby 2.4 GHz Wi-Fi hotspots via native OS commands.
  • Test TCP port 8080 responsiveness at 192.168.0.251.
  • Test the built-in Virtual SP Simulator at 127.0.0.1:18080.

---------------------------------------------------------------------------
STANDALONE OFFLINE BROWSER STUDIO (DOUBLE-CLICK HTML):
---------------------------------------------------------------------------
Double-click "LegacyInstaxPrinterWeb.html" in any browser to frame photos,
build multi-photo collages with custom border spacing, generate scannable
QR codes, test in the built-in Virtual SP-1/2/3 Browser Simulator, or export
ready-to-print PNGs and Planar RGB (.bin) payloads.

