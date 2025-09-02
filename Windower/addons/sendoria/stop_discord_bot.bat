@echo off
REM Sendoria Discord Bot Auto-Stop Script
REM This script stops the Discord bot when the addon unloads

REM Try to stop the silent version first
taskkill /F /IM "SendoriaBot_Silent.exe" >nul 2>&1

REM Try to stop the regular version
taskkill /F /IM "SendoriaBot.exe" >nul 2>&1
