#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/michaelfitzgerald/.gemini/antigravity/scratch/instax-square-printer"
MODULE_CACHE="/tmp/swift-module-cache"
APP_BUNDLE="$PROJECT_DIR/Instax Printer.app"
CLI_BIN="$PROJECT_DIR/instax-square"

mkdir -p "$MODULE_CACHE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "[1/3] Compiling instax-square CLI..."
/usr/bin/swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -O \
    "$PROJECT_DIR/Sources/InstaxSquareCore.swift" \
    "$PROJECT_DIR/Sources/CLI/main.swift" \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$PROJECT_DIR/Resources/CLI-Info.plist" \
    -o "$CLI_BIN"

/usr/bin/codesign --force --sign - "$CLI_BIN"

echo "[2/3] Compiling Instax Printer.app..."
/usr/bin/swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -O \
    -parse-as-library \
    "$PROJECT_DIR/Sources/InstaxSquareCore.swift" \
    "$PROJECT_DIR/Sources/App/InstaxSquareApp.swift" \
    -o "$APP_BUNDLE/Contents/MacOS/InstaxPrinter"

echo "[3/3] Compiling Instax Share Extension (.appex)..."
SHARE_APPEX="$APP_BUNDLE/Contents/PlugIns/Instax Share.appex"
mkdir -p "$SHARE_APPEX/Contents/MacOS"
mkdir -p "$SHARE_APPEX/Contents/Resources"
cp "$PROJECT_DIR/Resources/ShareExtension-Info.plist" "$SHARE_APPEX/Contents/Info.plist"

/usr/bin/swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -O \
    -parse-as-library \
    -Xlinker -e -Xlinker _NSExtensionMain \
    "$PROJECT_DIR/Sources/ShareExtension/InstaxShareViewController.swift" \
    -o "$SHARE_APPEX/Contents/MacOS/InstaxShare"

xattr -cr "$APP_BUNDLE"
/usr/bin/codesign --force --sign - --entitlements "$PROJECT_DIR/Resources/ShareExtension.entitlements" "$SHARE_APPEX"
/usr/bin/codesign --force --sign - "$APP_BUNDLE"

echo "Build complete!"
echo "  CLI   : $CLI_BIN"
echo "  App   : $APP_BUNDLE"
echo "  Share : $SHARE_APPEX"
