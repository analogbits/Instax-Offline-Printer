@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo       Instax Offline Printer — Windows Launcher
echo ========================================================

:: 1. Check for standard python command in PATH
set "PY_CMD="
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=python"
    goto :FOUND_PYTHON
)

:: 2. Check for Windows Python Launcher (py.exe)
py -3 --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=py -3"
    goto :FOUND_PYTHON
)

:: 3. Python is not installed
echo [NOTICE] Python is not installed on this system.
echo.
echo Launching the All-in-One Standalone Instax App...
echo (Uses Windows built-in Microsoft Edge engine — 100%% offline, zero install)
echo.
call "%~dp0Instax-Printer.bat"
if %errorlevel% equ 0 exit /b 0

echo.
echo --------------------------------------------------------
echo Would you like to install Python for the Python GUI version?
echo   [1] Automatically install Python 3 via Windows winget
echo   [2] Open Python.org download page
echo   [3] Exit
echo --------------------------------------------------------
choice /c 123 /m "Select option:"
if errorlevel 3 exit /b 0
if errorlevel 2 (
    start https://www.python.org/downloads/
    exit /b 0
)
if errorlevel 1 (
    echo.
    echo Installing Python 3 via winget...
    winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements
    if %errorlevel% equ 0 (
        echo Installation complete! Please restart Windows-Run.bat.
        pause
        exit /b 0
    ) else (
        echo [ERROR] winget installation failed.
        pause
        exit /b 1
    )
)
exit /b 0

:FOUND_PYTHON
echo Python detected: %PY_CMD%
echo Checking required libraries (bleak, pillow)...
%PY_CMD% -c "import bleak, PIL" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing required offline Bluetooth & Image libraries...
    %PY_CMD% -m pip install bleak pillow
    if %errorlevel% neq 0 (
        echo [WARNING] Failed to install pip packages. Launching All-in-One standalone app...
        call "%~dp0Instax-Printer.bat"
        exit /b 0
    )
)

echo Starting Instax Offline Printer Desktop App...
start "" %PY_CMD%w InstaxPrinterGUI.pyw 2>nul
if %errorlevel% neq 0 (
    %PY_CMD% InstaxPrinterGUI.pyw
)
