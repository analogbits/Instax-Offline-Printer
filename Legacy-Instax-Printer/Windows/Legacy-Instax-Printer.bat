@echo off
title Legacy Instax Printer — Wi-Fi Direct Studio (SP-1 / SP-2 / SP-3)
cd /d "%~dp0"

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Python 3 is not installed or not in PATH.
    echo Please install Python 3 from https://www.python.org/downloads/
    pause
    exit /b 1
)

python -c "import PIL" >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Installing Pillow image library...
    python -m pip install pillow
)

start "" pythonw LegacyInstaxPrinterGUI.pyw
