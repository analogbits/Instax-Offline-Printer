#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICES_DIR="$HOME/Library/Services"
mkdir -p "$SERVICES_DIR"

echo "=========================================================="
echo "  📸 Instax Offline Printer — Apple Photos Add-On Installer"
echo "=========================================================="
echo ""

# Copy 1-Click App to Applications
if [ -d "$DIR/Print from Apple Photos.app" ]; then
    cp -R "$DIR/Print from Apple Photos.app" "/Applications/" 2>/dev/null || true
    echo "✓ Installed 1-Click App to: /Applications/Print from Apple Photos.app"
fi

# Refresh LaunchServices for Instax Printer.app and Legacy Instax Printer.app
for app_path in \
    "$DIR/../macOS/Instax Printer.app" \
    "$DIR/../Legacy-Instax-Printer/macOS/Legacy Instax Printer.app" \
    "$DIR/../../Instax Printer.app" \
    "$DIR/../../Legacy Instax Printer.app" \
    "/Users/michaelfitzgerald/Desktop/2026/github/Instax and Polaroid/Instax Printer.app" \
    "/Users/michaelfitzgerald/Desktop/2026/github/Instax and Polaroid/Legacy Instax Printer.app" \
    "/Applications/Instax Printer.app" \
    "/Applications/Legacy Instax Printer.app"; do
    if [ -d "$app_path" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R "$app_path" 2>/dev/null || true
    fi
done

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Three ways to print from Apple Photos:"
echo "1. In Apple Photos: Select any photo(s), then double-click 'Print from Apple Photos.app' (or drag it into your Mac Dock for instant 1-click printing)."
echo "2. Drag and drop: Drag photos directly out of Apple Photos onto the Instax Printer window or Dock icon."
echo "3. In-App Browser: Click '+ Apple Photos / iCloud' inside Instax Printer to browse your full library."
echo ""
