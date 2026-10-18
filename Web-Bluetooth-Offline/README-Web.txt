================================================================================
          INSTAX UNIVERSAL OFFLINE WEB PRINTER — USER GUIDE
================================================================================

This folder contains the zero-install, 100% offline Web Bluetooth application,
plus the Local Wi-Fi Bluetooth Bridge (`instax_wifi_bridge.py`) for printing
directly from regular iPhone Safari, iPad Safari, Mac Safari, and Firefox!

--------------------------------------------------------------------------------
📱 HOW TO PRINT FROM IPHONE & IPAD (OR APPLE SAFARI / FIREFOX):
--------------------------------------------------------------------------------
Why special support is needed for iPhone & Safari:
  Apple disables the Web Bluetooth API (`navigator.bluetooth`) inside WebKit on
  iOS (including iPhone Safari, iOS Chrome, and iOS Edge) as well as macOS Safari.

To solve this, we provide TWO effortless ways to print from an iPhone or iPad:

  OPTION A — Print in Regular iPhone / iPad Safari at Home (Zero Apps Needed):
    1. On your Mac, Windows PC, or Linux computer (with Bluetooth turned ON),
       start the Local Wi-Fi Bluetooth Bridge by double-clicking:
         • macOS:   Start-iPhone-WiFi-Bridge.command
         • Windows: Start-iPhone-WiFi-Bridge.bat
         • Linux:   Start-iPhone-WiFi-Bridge.sh
       (Or run: `python3 instax_wifi_bridge.py` or `python3 instax_printer.py --serve`)
    2. Your computer will open a browser window displaying a scannable QR code
       and your local home Wi-Fi address (e.g. http://192.168.1.x:8765).
    3. Point your iPhone camera at the QR code on your computer screen (or type
       the http://192.168.1.x:8765 address into regular iPhone Safari).
    4. Select any photo from your iPhone Camera Roll, frame it, add filters or
       a QR code, and tap "🖨 Print Physical Photo" — your iPhone sends the
       framed photo over Wi-Fi to your computer, which immediately beams it
       over Bluetooth to your Instax printer!

  OPTION B — Direct iPhone-to-Printer Bluetooth Anywhere (On the Go):
    1. Install the free "Bluefy – Web BLE Browser" app from the iOS App Store:
       https://apps.apple.com/app/bluefy-web-ble-browser/id1492822055
    2. Open the Web App inside Bluefy (or tap "📲 Open This Page in Bluefy" on
       the banner in iPhone Safari) to connect directly from your iPhone to
       your Instax printer over Bluetooth with no computer required.

--------------------------------------------------------------------------------
⚠️ CRITICAL PREREQUISITE: TURN OFF BLUETOOTH ON YOUR PHONE (WHEN USING DESKTOP)
--------------------------------------------------------------------------------
Instax printers only allow ONE Bluetooth connection at a time!
If the printer was previously paired with the official Fujifilm app on your phone:
  1. The printer stops broadcasting beacons and will NOT appear on your computer.
  2. SOLUTION: Close the official Fujifilm app (or turn OFF Bluetooth on your
     phone when printing via your computer), then turn the printer off and back on.

--------------------------------------------------------------------------------
SUPPORTED PLATFORMS & BROWSERS:
--------------------------------------------------------------------------------
1. Direct Web Bluetooth (Zero-Install):
   Works on Mac, Windows (10 & 11), Linux, Chromebooks, and Android:
     * Google Chrome
     * Microsoft Edge
     * Brave Browser
     * Opera
   Works on iPhone & iPad:
     * Bluefy – Web BLE Browser (free on iOS App Store)

2. Local Wi-Fi Bluetooth Bridge (`Start-iPhone-WiFi-Bridge` / `--serve`):
   Works in ALL browsers on your home Wi-Fi network:
     * iPhone Safari & iPad Safari (zero iOS apps needed!)
     * macOS Safari
     * Mozilla Firefox

How BLE Link iPhone Printing Works:
  Your computer uses TWO separate radios simultaneously:
  1. Wi-Fi connects to your Home router to receive the image from iPhone Safari.
  2. Bluetooth connects directly to your Instax Link printer.
  (Both devices stay on your normal Home Wi-Fi with full internet access).

Looking for Legacy Wi-Fi Direct Printers (Instax SHARE SP-1, SP-2, SP-3)?
  Older Instax SHARE printers do not have Bluetooth—they communicate via
  Wi-Fi Direct (192.168.0.251:8080).
  See the dedicated "Legacy-Instax-Printer/" folder (AirDrop photos from iPhone
  to your computer in 1 second and click Print!).

--------------------------------------------------------------------------------
⚠️ ESSENTIAL PREREQUISITES (PRIOR TO FIRST USE!)
--------------------------------------------------------------------------------
1. STEP 1 — UPDATE PRINTER FIRMWARE PRIOR TO USE:
   Always ensure your printer is on the latest firmware before desktop printing!
   * Instax Link WIDE on initial factory firmware 0100 has a known manufacturer
     BLE buffer bug that causes image transfers to stall or fail.
   * Updating to firmware 0101 (or newer) via the official mobile app resolves
     this completely.

2. STEP 2 — TURN OFF BLUETOOTH ON YOUR PHONE / TABLET:
   Instax printers only allow ONE Bluetooth connection at a time!
   * Once updated, turn OFF Bluetooth in your phone's Settings so your computer
     can connect directly to the printer.

--------------------------------------------------------------------------------
HOW TO USE:
--------------------------------------------------------------------------------
1. Turn on your Instax printer (press and hold power button until the LED glows).
2. Open "InstaxPrinterWeb.html" in Chrome/Edge/Brave (or start the Local Wi-Fi
   Bridge via `Start-iPhone-WiFi-Bridge` for iPhone/iPad/Mac Safari).
3. Click "📁 Add Photo..." to select any JPG, PNG, WEBP, or HEIC image.
4. Use the interactive canvas controls:
   - Drag directly on the photo with your mouse or finger to re-center.
   - Adjust the Zoom slider (0.5x to 2.5x).
   - Use "Rotate 90°" to rotate orientation.
   - Choose your Fit Mode: Fill Square (Crop), Fit Entire Image (Letterbox),
     or Stretch.
   - Pick an Artistic Filter: B&W Mono, Warm Sepia, Vintage Film, Cool Fade,
     or Vivid Pop.
   - Select your Film Mode: instax-Rich (vibrant pop) or instax-Natural (soft film).
5. Click "📡 Connect Instax".
6. The app will read your printer's hardware status:
   - Remaining film count (e.g. "Film: 10/10")
   - Real-time battery percentage ("Battery: 100%")
7. Click "🖨 Print Physical Photo".
   Watch the live upload progress bar. Within ~12 seconds, your printer
   will physically expose and eject your instant photo!

================================================================================
