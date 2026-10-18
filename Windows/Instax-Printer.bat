@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "APP_FILE=%~dp0InstaxPrinterWeb.html"
set "APP_URL=file:///%APP_FILE:\=/%"

:: 1. Search for Microsoft Edge (Standard on 100% of modern Windows 10 & Windows 11)
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app="!APP_URL!"
    exit /b 0
)

if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app="!APP_URL!"
    exit /b 0
)

if exist "%LocalAppData%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%LocalAppData%\Microsoft\Edge\Application\msedge.exe" --app="!APP_URL!"
    exit /b 0
)

:: 2. Search for Google Chrome
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --app="!APP_URL!"
    exit /b 0
)

if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" --app="!APP_URL!"
    exit /b 0
)

if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
    start "" "%LocalAppData%\Google\Chrome\Application\chrome.exe" --app="!APP_URL!"
    exit /b 0
)

:: 3. Search for Brave Browser
if exist "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" (
    start "" "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" --app="!APP_URL!"
    exit /b 0
)

if exist "%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe" (
    start "" "%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe" --app="!APP_URL!"
    exit /b 0
)

:: 4. Fallback: try msedge command or system default browser
start msedge --app="!APP_URL!" 2>nul
if %errorlevel% equ 0 exit /b 0

start "" "!APP_URL!"
exit /b 0
