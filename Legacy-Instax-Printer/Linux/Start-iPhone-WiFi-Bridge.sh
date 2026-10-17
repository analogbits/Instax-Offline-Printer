#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$DIR/legacy_web_bridge.py" ]; then
    exec python3 "$DIR/legacy_web_bridge.py" "$@"
elif [ -f "$DIR/../Web-WiFi-Offline/legacy_web_bridge.py" ]; then
    exec python3 "$DIR/../Web-WiFi-Offline/legacy_web_bridge.py" "$@"
elif [ -f "$DIR/Web-WiFi-Offline/legacy_web_bridge.py" ]; then
    exec python3 "$DIR/Web-WiFi-Offline/legacy_web_bridge.py" "$@"
elif [ -f "$DIR/Legacy-Instax-Printer/Web-WiFi-Offline/legacy_web_bridge.py" ]; then
    exec python3 "$DIR/Legacy-Instax-Printer/Web-WiFi-Offline/legacy_web_bridge.py" "$@"
elif [ -f "$DIR/Instax Offline Printer Applications/Legacy-Instax-Printer/Web-WiFi-Offline/legacy_web_bridge.py" ]; then
    exec python3 "$DIR/Instax Offline Printer Applications/Legacy-Instax-Printer/Web-WiFi-Offline/legacy_web_bridge.py" "$@"
else
    echo "Could not find legacy_web_bridge.py"
    exit 1
fi
