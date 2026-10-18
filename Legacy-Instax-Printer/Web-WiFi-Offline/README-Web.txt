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
📱 HOW TO PRINT FROM IPHONE & IPAD SAFARI (3 EASY SETUPS):
---------------------------------------------------------------------------
Your computer and phone each have a single Wi-Fi antenna. Because the printer
is its own Wi-Fi access point ("INSTAX-XXXXXXXX"), connecting to the printer
disconnects you from your home router. You have 3 easy setups:

  SETUP 1 (All-Wireless Direct — Recommended — Zero Cables):
    1. Turn on your Instax SHARE SP-1, SP-2, or SP-3 printer.
    2. On your Mac/PC: join Wi-Fi "INSTAX-XXXXXXXX" (Password: 11111111).
    3. On your iPhone: go to iOS Settings -> Wi-Fi -> join "INSTAX-XXXXXXXX"
       (Password: 11111111). When iOS shows "No Internet Connection", tap
       "Keep Trying Wi-Fi" (this is normal as the printer is not a modem).
    4. Start the Local Wi-Fi Bridge on your computer:
         • Mac:     Double-click Start-iPhone-WiFi-Bridge.command
         • Windows: Double-click Start-iPhone-WiFi-Bridge.bat
         • Linux:   Run ./Start-iPhone-WiFi-Bridge.sh
       (Or run `python3 legacy_instax_printer.py --serve`)
    5. In regular iPhone Safari, open: http://192.168.0.x:8089 (shown in terminal).
    6. Pick photos from your Camera Roll, frame/collage, and tap "Print Over Wi-Fi Direct"!

  SETUP 2 (Dual Network — Computer on Ethernet + Wi-Fi to Printer):
    Plug your computer into your home router with an Ethernet cable, and connect
    its Wi-Fi card to "INSTAX-XXXXXXXX". Your iPhone stays on normal Home Wi-Fi
    (e.g. http://192.168.1.x:8089) and prints with zero network switching!

  SETUP 3 (1-Second AirDrop to Mac — Fastest for iPhone Users):
    On your iPhone, select your photo and AirDrop it to your Mac. In
    "Legacy Instax Printer.app" or LegacyInstaxPrinterWeb.html on your Mac,
    click "Add Photo" and click "Print"!

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

