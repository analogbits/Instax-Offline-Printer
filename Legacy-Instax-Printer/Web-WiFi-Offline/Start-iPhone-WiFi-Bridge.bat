@echo off
title Legacy Instax Local Wi-Fi Bridge (iPhone / iPad / Safari)
set "DIR=%~dp0"
if exist "%DIR%legacy_web_bridge.py" (
    python "%DIR%legacy_web_bridge.py" %*
) else if exist "%DIR%..\Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%..\Web-WiFi-Offline\legacy_web_bridge.py" %*
) else if exist "%DIR%Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%Web-WiFi-Offline\legacy_web_bridge.py" %*
) else (
    echo Could not find legacy_web_bridge.py
    pause
)
