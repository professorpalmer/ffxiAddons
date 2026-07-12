@echo off
title Kotoba Installer
echo ============================================
echo   KOTOBA INSTALLER - LLM Edition
echo ============================================
echo.

REM Check for Python
echo [1/4] Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Python not found!
    echo Please install Python 3.8+ from https://www.python.org/downloads/
    echo IMPORTANT: Check "Add Python to PATH" during installation.
    echo.
    pause
    exit /b 1
)
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo   Python %PYVER% found.
echo.

REM Install httpx
echo [2/4] Installing httpx...
pip install httpx >nul 2>&1
if errorlevel 1 (
    echo   WARNING: pip install failed. You may need to run manually: pip install httpx
) else (
    echo   httpx installed.
)
echo.

REM Create config template if not exists
echo [3/4] Checking config...
if not exist "translator_config.txt" (
    echo LLM_API_KEY=your_api_key_here> translator_config.txt
    echo LLM_BASE_URL=https://api.deepseek.com/v1>> translator_config.txt
    echo LLM_MODEL=deepseek-chat>> translator_config.txt
    echo   Created translator_config.txt
) else (
    echo   translator_config.txt already exists.
)
echo.

REM Build seed database
echo [4/4] Building seed database...
python build_seed_db.py
echo.

echo ============================================
echo   INSTALL COMPLETE!
echo ============================================
echo.
echo Next steps:
echo   1. Edit translator_config.txt and add your LLM API key
echo      (Get a free DeepSeek key at https://platform.deepseek.com/)
echo   2. Run start_translator.bat to start the translator
echo   3. In FFXI: /addon load kotoba
echo   4. Type /kotoba in game to open the window
echo.
pause
