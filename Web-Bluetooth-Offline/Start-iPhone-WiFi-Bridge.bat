@echo off
title Instax Local Wi-Fi Bluetooth Bridge (iPhone / iPad Safari)
set "DIR=%~dp0"
if exist "%DIR%instax_wifi_bridge.py" (
    python "%DIR%instax_wifi_bridge.py" %*
) else if exist "%DIR%..\Web-Bluetooth-Offline\instax_wifi_bridge.py" (
    python "%DIR%..\Web-Bluetooth-Offline\instax_wifi_bridge.py" %*
) else if exist "%DIR%Web-Bluetooth-Offline\instax_wifi_bridge.py" (
    python "%DIR%Web-Bluetooth-Offline\instax_wifi_bridge.py" %*
) else if exist "%DIR%Instax Offline Printer Applications\Web-Bluetooth-Offline\instax_wifi_bridge.py" (
    python "%DIR%Instax Offline Printer Applications\Web-Bluetooth-Offline\instax_wifi_bridge.py" %*
) else (
    echo Could not find instax_wifi_bridge.py
    pause
)
