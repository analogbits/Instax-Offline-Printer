================================================================================
          INSTAX UNIVERSAL OFFLINE WEB PRINTER — USER GUIDE
================================================================================

This folder contains the zero-install, 100% offline Web Bluetooth application.
It runs locally in any modern Chromium-based web browser without installing
any drivers, Python packages, or software dependencies.

--------------------------------------------------------------------------------
⚠️ CRITICAL PREREQUISITE: TURN OFF BLUETOOTH ON YOUR PHONE / TABLET
--------------------------------------------------------------------------------
Instax printers only allow ONE Bluetooth connection at a time!
If the printer was previously paired with your iPhone, iPad, or Android device:
  1. The printer stops broadcasting beacons and will NOT appear in the browser chooser.
  2. SOLUTION: Turn OFF Bluetooth in iOS/Android Settings on your phone,
     then turn the printer off and back on. It will immediately show up in the chooser.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
SUPPORTED PLATFORMS & BROWSERS:
--------------------------------------------------------------------------------
Works on Mac, Windows (10 & 11), Linux, Chromebooks, and Android tablets/phones:
  * Google Chrome
  * Microsoft Edge
  * Brave Browser
  * Opera

NOTE: Apple Safari and Mozilla Firefox do NOT support the Web Bluetooth API.
      Please open InstaxPrinterWeb.html in Chrome, Edge, or Brave.

--------------------------------------------------------------------------------
HOW TO USE:
--------------------------------------------------------------------------------
1. Turn on your Instax printer (press and hold power button until the LED glows).
2. Double-click "InstaxPrinterWeb.html" to open it in Chrome, Edge, or Brave.
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
5. Click "📡 Connect Instax (BLE)".
   In the browser popup, select your printer (e.g. "INSTAX-50271289") and click Pair.
6. The app will immediately read your printer's hardware status:
   - Remaining film count (e.g. "Film: 10/10")
   - Real-time battery percentage ("Battery: 100%")
7. Click "🖨 Print Physical Photo".
   Watch the live chunk upload progress bar. Within ~12 seconds, your printer
   will physically expose and eject your instant photo!

--------------------------------------------------------------------------------
TROUBLESHOOTING & FAQ:
--------------------------------------------------------------------------------
* "Unsupported device" or "User cancelled the chooser":
  Make sure your printer is powered on and within 3 meters. If previously paired
  to a phone, briefly disconnect Bluetooth on the phone so the printer is free
  to advertise.

* "Undefined is not an object (evaluating 'navigator.bluetooth')":
  This happens if opened in Apple Safari. Open the file in Chrome or Edge instead.

* Running inside Virtual Machines (Parallels / VMware / VirtualBox):
  Virtual machines do not emulate low-level Bluetooth Low Energy (BLE) hardware
  by default. If running inside a VM, use a dedicated USB Bluetooth dongle passed
  through to the VM, or simply run the app directly on the host Mac/PC.

* Printer back cover open:
  If the back film compartment is ajar, the status badge will warn "Cover Open!".
  Firmly click the back hatch closed before printing.

================================================================================
