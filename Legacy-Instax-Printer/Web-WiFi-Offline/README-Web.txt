===========================================================================
LEGACY INSTAX PRINTER — WEB EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

Single-file offline HTML5 Studio ("LegacyInstaxPrinterWeb.html") + Local
Wi-Fi Direct TCP Bridge ("legacy_web_bridge.py") for Fujifilm Instax SHARE:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

---------------------------------------------------------------------------
🌐 SAFARI VS CHROME: ZERO CHROME REQUIRED FOR WI-FI PRINTERS!
---------------------------------------------------------------------------
Unlike Bluetooth LE printers (which require Chrome/Edge/Brave because Apple
blocks Web Bluetooth in WebKit), Instax SHARE printers communicate over
standard HTTP and TCP/IP (192.168.0.251:8080).
Regular Apple Safari on iPhone, iPad, and macOS works 100% natively!
No third-party browsers like Chrome or Bluefy are needed.

---------------------------------------------------------------------------
📱 HAVE PHOTOS ON IPHONE OR IPAD? AIRDROP TO MAC IN 1 SECOND!
---------------------------------------------------------------------------
You do NOT need any complicated bridge scripts or network switching:
  1. On iPhone: Tap Share -> AirDrop photo to your Mac (1 second).
  2. On Mac: Connect Wi-Fi to "INSTAX-XXXXXXXX" (Password: 11111111).
  3. Open LegacyInstaxPrinterWeb.html -> click "Choose Photo" -> click Print!

---------------------------------------------------------------------------
💻 LOCAL WEB STUDIO BACKEND (legacy_web_bridge.py):
---------------------------------------------------------------------------
Because web browsers block direct raw TCP sockets from webpages for security,
run `python3 legacy_web_bridge.py` on your computer to provide a lightweight local
bridge between LegacyInstaxPrinterWeb.html and the printer at 192.168.0.251:8080.

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

