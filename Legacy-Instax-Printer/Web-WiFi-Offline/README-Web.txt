===========================================================================
LEGACY INSTAX PRINTER — WEB EDITION (Instax SHARE SP-1, SP-2 & SP-3)
===========================================================================

Single-file offline HTML5 Studio ("LegacyInstaxPrinterWeb.html") + Local
Wi-Fi Direct TCP Bridge ("legacy_web_bridge.py") for Fujifilm Instax SHARE:
  - Instax SHARE SP-1 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-2 (Mini Film • 600 × 800 Planar RGB)
  - Instax SHARE SP-3 (SQUARE Film • 800 × 800 Planar RGB)

WHY THE LOCAL BRIDGE IS INCLUDED:
---------------------------------
Unlike newer Bluetooth LE printers, older Instax SHARE SP-1, SP-2, and SP-3
printers use raw TCP sockets over Wi-Fi Direct (192.168.0.251:8080). Because
web browsers block direct raw TCP sockets from webpages, you have two ways to
use LegacyInstaxPrinterWeb.html:

OPTION 1 — Direct Printing from Mac, PC & iPhone / iPad Safari:
  Double-click:
    - Mac:     Start-iPhone-WiFi-Bridge.command
    - Windows: Start-iPhone-WiFi-Bridge.bat
    - Linux:   ./Start-iPhone-WiFi-Bridge.sh
  The terminal displays your computer's local Wi-Fi URL (e.g. http://192.168.1.77:8089).
  Open that link on your iPhone, iPad, or any device on your home network to print
  straight from your camera roll without installing any iOS apps!

OPTION 2 — Standalone Offline Browser Studio (Double-Click HTML):
  Double-click "LegacyInstaxPrinterWeb.html" to frame photos, build multi-photo
  collages with custom border spacing, generate scannable QR codes, test in the
  built-in Virtual SP-1/2/3 Browser Simulator, or export ready-to-print PNGs
  and Planar RGB (.bin) payloads.
