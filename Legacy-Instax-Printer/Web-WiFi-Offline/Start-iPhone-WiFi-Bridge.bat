@echo off
title Legacy Instax Local Wi-Fi Bridge (SP-1 / SP-2 / SP-3 • iPhone / Safari)
set "DIR=%~dp0"
if exist "%DIR%legacy_web_bridge.py" (
    python "%DIR%legacy_web_bridge.py" %*
) else if exist "%DIR%..\Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%..\Web-WiFi-Offline\legacy_web_bridge.py" %*
) else if exist "%DIR%Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%Web-WiFi-Offline\legacy_web_bridge.py" %*
) else if exist "%DIR%Legacy-Instax-Printer\Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%Legacy-Instax-Printer\Web-WiFi-Offline\legacy_web_bridge.py" %*
) else if exist "%DIR%Instax Offline Printer Applications\Legacy-Instax-Printer\Web-WiFi-Offline\legacy_web_bridge.py" (
    python "%DIR%Instax Offline Printer Applications\Legacy-Instax-Printer\Web-WiFi-Offline\legacy_web_bridge.py" %*
) else (
    echo Could not find legacy_web_bridge.py
    pause
)
