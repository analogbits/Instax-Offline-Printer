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

# Refresh LaunchServices for Instax Square Printer.app
if [ -d "$DIR/../macOS/Instax Square Printer.app" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R "$DIR/../macOS/Instax Square Printer.app" 2>/dev/null || true
fi
if [ -d "/Users/michaelfitzgerald/Desktop/Instax Square Printer.app" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -R "/Users/michaelfitzgerald/Desktop/Instax Square Printer.app" 2>/dev/null || true
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Three ways to print from Apple Photos:"
echo "1. In Apple Photos: Select any photo(s), then double-click 'Print from Apple Photos.app' (or drag it into your Mac Dock for instant 1-click printing)."
echo "2. Drag and drop: Drag photos directly out of Apple Photos onto the Instax Square Printer window or Dock icon."
echo "3. In-App Browser: Click '+ Apple Photos / iCloud' inside Instax Square Printer to browse your full library."
echo ""
