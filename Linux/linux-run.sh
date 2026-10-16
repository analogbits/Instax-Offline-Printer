#!/bin/bash
# ========================================================
# Instax Offline Printer — Linux Launcher
# Works on Ubuntu, Debian, Fedora, Arch, Raspberry Pi OS
# ========================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "========================================================"
echo "       Instax Offline Printer — Linux Edition"
echo "========================================================"

# 1. Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "[NOTICE] python3 is not installed."
    echo "Launching the All-in-One Standalone Linux Desktop App..."
    exec "$DIR/Instax-Printer-Linux.sh"
fi

# 2. Check if tkinter, bleak, and PIL are installed
python3 -c "import tkinter, bleak, PIL" &> /dev/null
if [ $? -ne 0 ]; then
    echo "Python libraries (tkinter/bleak/pillow) need installation."
    
    # Try apt on Debian/Ubuntu
    if command -v apt &> /dev/null && [ "$(id -u)" -eq 0 ]; then
        apt install -y python3-bleak python3-pil python3-tk 2>/dev/null
    fi
    
    # Try pip with PEP 668 compatibility
    pip3 install --user bleak pillow --break-system-packages 2>/dev/null || \
    pip3 install --user bleak pillow 2>/dev/null || \
    pip install bleak pillow 2>/dev/null

    # Re-check
    python3 -c "import tkinter, bleak, PIL" &> /dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "[NOTICE] Python GUI dependencies (Tkinter/Bleak) not ready."
        echo "Launching the All-in-One Standalone Desktop Application instead..."
        echo "(Zero-install, works out of the box via Chromium/Chrome)"
        echo ""
        exec "$DIR/Instax-Printer-Linux.sh"
    fi
fi

echo "Starting Instax Desktop GUI..."
python3 "$DIR/InstaxPrinterGUI.py"
