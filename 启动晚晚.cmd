@echo off
rem Fallback launcher for systems where VBScript has been disabled.
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0app\Main.ps1"
