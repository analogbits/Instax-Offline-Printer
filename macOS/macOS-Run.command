#!/bin/zsh
# ========================================================
# Instax Emergency Offline Print Terminal Launcher
# Double-click this script in Finder to print without GUI
# ========================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="$DIR/instax-square"

clear
echo "========================================================"
echo "      INSTAX EMERGENCY OFFLINE PRINT LAUNCHER"
echo "========================================================"
echo "This tool communicates directly with your Instax printer"
echo "over Mac Bluetooth Low Energy. No internet needed."
echo ""

if [ ! -f "$CLI" ]; then
    echo "Error: CLI binary not found at $CLI"
    read -k 1 -s
    exit 1
fi

echo "Checking Bluetooth and scanning for Instax printers..."
"$CLI" scan --timeout 3
echo ""

echo "--------------------------------------------------------"
echo "Drag & drop one or more photos here, then press RETURN:"
echo "(or type photo paths separated by space)"
echo "--------------------------------------------------------"
read -r inputLine

if [ -z "$inputLine" ]; then
    echo "No files provided. Exiting."
    read -k 1 -s
    exit 0
fi

eval "args=($inputLine)"

echo ""
echo "Select print quality mode:"
echo "  1) instax-Rich Mode (Vibrant & Punchy) [Default]"
echo "  2) instax-Natural Mode (Classic Fujifilm 3D-LUT)"
read -r -k 1 modeChoice
echo ""

MODE="rich"
if [ "$modeChoice" = "2" ]; then
    MODE="natural"
fi

echo "Printing with $MODE mode..."
"$CLI" print "${args[@]}" --mode "$MODE" --fit crop

echo ""
echo "Press any key to close this window..."
read -k 1 -s
