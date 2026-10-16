#!/bin/bash
# ========================================================
# Linux Dependency Installer (Ubuntu/Debian/Fedora/Arch)
# ========================================================
echo "Detecting package manager..."
if command -v apt &> /dev/null; then
    sudo apt update
    sudo apt install -y python3 python3-pip python3-tk bluez libbluetooth-dev
elif command -v dnf &> /dev/null; then
    sudo dnf install -y python3 python3-pip python3-tkinter bluez-libs-devel
elif command -v pacman &> /dev/null; then
    sudo pacman -S --noconfirm python python-pip tk bluez bluez-utils
fi

pip3 install --user bleak pillow
echo "Installation complete! Run ./linux-run.sh to start the printer app."
