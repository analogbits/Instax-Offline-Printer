@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo   Instax Emergency Offline Console Print (Windows)
echo ========================================================

python -c "import bleak, PIL" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing dependencies...
    pip install bleak pillow
)

echo Scanning for nearby Instax printers...
python instax_printer.py scan --timeout 3
echo.

set /p inputFiles="Drag & drop one or more photos here and press Enter: "
if "%inputFiles%"=="" (
    echo No files specified.
    pause
    exit /b 0
)

echo.
echo Select print mode:
echo   1. instax-Rich (Vibrant, Saturated) [Default]
echo   2. instax-Natural (Classic Film 3D-LUT)
set /p modeChoice="Choice (1 or 2): "

set PRINT_MODE=rich
if "%modeChoice%"=="2" set PRINT_MODE=natural

python instax_printer.py print %inputFiles% --mode %PRINT_MODE%

echo.
pause
