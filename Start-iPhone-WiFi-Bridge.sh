#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$DIR/instax_wifi_bridge.py" ]; then
    exec python3 "$DIR/instax_wifi_bridge.py" "$@"
elif [ -f "$DIR/Web-Bluetooth-Offline/instax_wifi_bridge.py" ]; then
    exec python3 "$DIR/Web-Bluetooth-Offline/instax_wifi_bridge.py" "$@"
elif [ -f "$DIR/../Web-Bluetooth-Offline/instax_wifi_bridge.py" ]; then
    exec python3 "$DIR/../Web-Bluetooth-Offline/instax_wifi_bridge.py" "$@"
elif [ -f "$DIR/Instax Offline Printer Applications/Web-Bluetooth-Offline/instax_wifi_bridge.py" ]; then
    exec python3 "$DIR/Instax Offline Printer Applications/Web-Bluetooth-Offline/instax_wifi_bridge.py" "$@"
else
    echo "Could not find instax_wifi_bridge.py"
    exit 1
fi
