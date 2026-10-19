#!/bin/bash
set -e

cd "$(dirname "$0")"
CACHE_DIR="/tmp/swift-module-cache"
mkdir -p "$CACHE_DIR"
xattr -cr Resources Sources 2>/dev/null || true

echo "🔨 [1/4] Building legacy-instax CLI..."
/usr/bin/swiftc \
    -module-cache-path "$CACHE_DIR" \
    -O \
    Sources/LegacyInstaxCore.swift \
    Sources/CLI/main.swift \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Resources/CLI-Info.plist \
    -o legacy-instax

/usr/bin/codesign --force --sign - legacy-instax

echo "🔨 [2/4] Preparing Legacy Instax Printer.app bundle..."
APP_BUNDLE="Legacy Instax Printer.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/PlugIns"

cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "🔨 [3/4] Compiling Apple Photos Share Extension (Legacy Instax Share.appex)..."
EXT_BUNDLE="$APP_BUNDLE/Contents/PlugIns/Legacy Instax Share.appex"
mkdir -p "$EXT_BUNDLE/Contents/MacOS"
cp Resources/ShareExtension-Info.plist "$EXT_BUNDLE/Contents/Info.plist"

/usr/bin/swiftc \
    -module-cache-path "$CACHE_DIR" \
    -O \
    -module-name LegacyInstaxShare \
    -Xlinker -e -Xlinker _NSExtensionMain \
    Sources/ShareExtension/LegacyInstaxShareViewController.swift \
    -o "$EXT_BUNDLE/Contents/MacOS/LegacyInstaxShare"

find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --sign - --entitlements Resources/ShareExtension.entitlements "$EXT_BUNDLE"

echo "🔨 [4/4] Compiling Legacy Instax Printer macOS SwiftUI Application..."
/usr/bin/swiftc \
    -module-cache-path "$CACHE_DIR" \
    -O \
    -parse-as-library \
    Sources/LegacyInstaxCore.swift \
    Sources/App/LegacyInstaxApp.swift \
    -o "$APP_BUNDLE/Contents/MacOS/LegacyInstaxPrinter"

cp legacy-instax "$APP_BUNDLE/Contents/MacOS/legacy-instax"
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --sign - --deep "$APP_BUNDLE"

touch "$APP_BUNDLE"
touch legacy-instax

# Register bundle with macOS LaunchServices so Finder immediately reflects version 1.7.0
if [ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE" 2>/dev/null || true
fi

echo "📦 Packaging Legacy-Instax-Printer-macOS.zip..."
rm -f ../Legacy-Instax-Printer-macOS.zip
zip -q -r -y ../Legacy-Instax-Printer-macOS.zip "$APP_BUNDLE" legacy-instax

echo "✅ Successfully built '$APP_BUNDLE' and 'legacy-instax'!"
