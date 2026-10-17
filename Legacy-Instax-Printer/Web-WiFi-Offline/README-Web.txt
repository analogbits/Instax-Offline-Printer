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

OPTION 1 — Full Direct Wi-Fi Printing from Any Browser:
  Run:
    python3 legacy_web_bridge.py
  This opens http://127.0.0.1:8089/LegacyInstaxPrinterWeb.html and relays your
  browser's print & status commands directly to 192.168.0.251:8080!

OPTION 2 — 100% Standalone Browser Studio (Double-Click HTML):
  Double-click "LegacyInstaxPrinterWeb.html" to frame photos, build multi-photo
  collages with custom border spacing, generate scannable QR codes, test in the
  built-in Virtual SP-1/2/3 Browser Simulator, or export ready-to-print PNGs
  and Planar RGB (.bin) payloads.
