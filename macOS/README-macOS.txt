================================================================================
           INSTAX OFFLINE PRINTER SUITE — macOS EDITION GUIDE
================================================================================

This folder contains native macOS applications and command-line tools for
printing to Instax SQUARE Link, Link WIDE, and Mini Link printers over
Bluetooth Low Energy (100% offline).

--------------------------------------------------------------------------------
⚠️ CRITICAL PREREQUISITE: TURN OFF BLUETOOTH ON YOUR PHONE / TABLET
--------------------------------------------------------------------------------
Instax printers only allow ONE Bluetooth connection at a time!
If the printer was previously paired with your iPhone, iPad, or Android device:
  1. The printer stops broadcasting beacons and will be INVISIBLE to your Mac.
  2. SOLUTION: Turn OFF Bluetooth in iOS Settings / Control Center on your phone,
     then turn the printer off and back on. It will immediately appear on your Mac.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
1. NATIVE macOS APP: "Instax Printer.app"
--------------------------------------------------------------------------------
How to Run:
  * Double-click "Instax Printer.app" in Finder.
  * (Optional) Drag "Instax Printer.app" to your Applications folder.

Key Features & Shortcuts:
  * Apple Photos & iCloud Library: Click "Add from Photos" to browse your iCloud
    albums, favorites, and recents with instant thumbnail loading.
  * Interactive Framing: Drag to pan, zoom (0.5x–2.5x), and rotate 90° increments.
  * Fit Modes: Fill Square (Crop), Fit Entire Image (Letterbox), or Stretch.
  * Background Color: Select borders (White, Black, Cream, Pastel Pink, Pastel Blue).
  * Film Simulation: Switch between instax-Rich (vibrant) and instax-Natural (film stock).
  * Artistic Filters: Original, B&W Mono, Warm Sepia, Vintage Film, Cool Fade, Vivid.
  * Collage Printing: 2-Split (V/H), 3-Split, and 4-Grid photo layouts.
  * Live Telemetry: Shows remaining film sheets (X/10), battery percentage,
    charging state, and multi-printer picker.
  * Debug Console: Press Cmd + D to open the live packet trace window.
  * Offline Help & Manual: Press Cmd + ? to open the built-in offline guide.
  * LED Control: Flash rainbow effect or stop looping LEDs.

--------------------------------------------------------------------------------
2. COMMAND LINE INTERFACE: "instax-square"
--------------------------------------------------------------------------------
Standalone native terminal executable. No Python or dependencies required.

Quick CLI Commands:
  * Scan for printers:
      ./instax-square scan
  * Query printer status (film, battery, specs):
      ./instax-square status
  * Print photo in vibrant mode:
      ./instax-square print photo.jpg --mode rich
  * Print in classic film mode:
      ./instax-square print photo.jpg --mode natural
  * Batch print multiple photos:
      ./instax-square print img1.jpg img2.jpg img3.jpg
  * Render 800x800 square preview to disk:
      ./instax-square preview photo.jpg -o preview.jpg --fit crop
  * Turn off printer LED:
      ./instax-square led --off

--------------------------------------------------------------------------------
3. EMERGENCY FINDER SCRIPT: "macOS-Run.command"
--------------------------------------------------------------------------------
Double-click "macOS-Run.command" to open an interactive terminal launcher.
Type or drag-and-drop any image path and press Enter to print immediately.

--------------------------------------------------------------------------------
4. INSTALL TO SYSTEM PATH: "install-cli.sh"
--------------------------------------------------------------------------------
Run "./install-cli.sh" to copy 'instax-square' into /usr/local/bin so you can
type 'instax-square' from any terminal directory.

--------------------------------------------------------------------------------
TROUBLESHOOTING & macOS ADVICE:
--------------------------------------------------------------------------------
* macOS Bluetooth Permission:
  If prompted on first run, click "Allow" for Bluetooth access.
  If you ever accidentally denied access, go to:
    System Settings -> Privacy & Security -> Bluetooth -> Enable Instax Square Printer.
* Printer Busy / Already Connected:
  Instax printers only allow ONE Bluetooth connection at a time. If the printer
  is currently connected to your iPhone or iPad, turn off Bluetooth on that device
  temporarily so your Mac can discover and connect to it.
* Running inside Parallels Desktop / Virtual Machines:
  macOS controls the physical Bluetooth radio. If you want to print from macOS,
  run the app natively in macOS (not inside a VM).

================================================================================
