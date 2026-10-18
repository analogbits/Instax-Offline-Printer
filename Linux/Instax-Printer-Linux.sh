#!/bin/bash
# ========================================================
# Instax Offline Printer — Standalone Linux App Launcher
# (Zero-Install, 100% Offline, Native BlueZ Bluetooth)
# ========================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$DIR/InstaxPrinterWeb.html" ]; then
    APP_PATH="$DIR/InstaxPrinterWeb.html"
else
    APP_PATH="$DIR/../Web-Bluetooth-Offline/InstaxPrinterWeb.html"
fi
APP_URL="file://$APP_PATH"

# Look for Chromium-based browsers that support Web Bluetooth on Linux
BROWSERS=(
    "google-chrome"
    "google-chrome-stable"
    "chromium"
    "chromium-browser"
    "brave-browser"
    "microsoft-edge"
    "microsoft-edge-stable"
)

for b in "${BROWSERS[@]}"; do
    if command -v "$b" &>/dev/null; then
        echo "Launching Instax Standalone Desktop App via $b..."
        nohup "$b" --app="$APP_URL" >/dev/null 2>&1 &
        exit 0
    fi
done

# Fallback: xdg-open (opens default system browser)
if command -v xdg-open &>/dev/null; then
    xdg-open "$APP_URL"
    exit 0
fi

echo "[ERROR] No compatible browser found (Google Chrome, Chromium, Brave, or Edge)."
echo "Please install Chromium via: sudo apt install chromium-browser"
exit 1
