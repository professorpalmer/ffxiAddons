@echo off
REM Sendoria Discord Bot Auto-Start Script
REM This script starts the Discord bot when the addon loads

REM Change to the addon directory
cd /d "%~dp0"

REM Check if the silent bot executable exists
if exist "SendoriaBot_Silent.exe" (
    start "" "SendoriaBot_Silent.exe"
) else if exist "SendoriaBot.exe" (
    start "" "SendoriaBot.exe"
) else (
    echo ERROR: Discord bot executable not found!
    echo Please ensure SendoriaBot.exe or SendoriaBot_Silent.exe is in the addon folder.
)
