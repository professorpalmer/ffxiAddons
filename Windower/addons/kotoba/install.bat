@echo off
title Kotoba Installer
echo ============================================
echo   KOTOBA INSTALLER - LLM Edition (Windower)
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
where pythonw >nul 2>&1
if errorlevel 1 (
    echo   WARNING: pythonw not found — addon will fall back to python.exe
) else (
    echo   pythonw found (headless spawn OK).
)
echo.

REM Install httpx from requirements.txt
echo [2/4] Installing Python deps...
if exist "requirements.txt" (
    pip install -r requirements.txt
) else (
    pip install "httpx>=0.27.0"
)
if errorlevel 1 (
    echo.
    echo ERROR: pip install failed.
    echo Try: pip install -r requirements.txt
    echo.
    pause
    exit /b 1
)
echo   Dependencies installed.
echo.

REM Create config from example if not exists
echo [3/4] Checking config...
if not exist "translator_config.txt" (
    if exist "translator_config.example.txt" (
        copy /Y "translator_config.example.txt" "translator_config.txt" >nul
        echo   Created translator_config.txt from example.
    ) else (
        echo LLM_API_KEY=your_api_key_here> translator_config.txt
        echo LLM_BASE_URL=https://api.deepseek.com/v1>> translator_config.txt
        echo LLM_MODEL=deepseek-chat>> translator_config.txt
        echo   Created translator_config.txt
    )
    echo   Edit translator_config.txt and set LLM_API_KEY before playing.
) else (
    echo   translator_config.txt already exists.
)
echo.

REM Build seed database
echo [4/4] Building seed database...
python build_seed_db.py
if errorlevel 1 (
    echo   WARNING: seed DB build failed — translations still work, just colder cache.
) else (
    echo   Seed database ready.
)
echo.

echo ============================================
echo   INSTALL COMPLETE!
echo ============================================
echo.
echo Next steps:
echo   1. Edit translator_config.txt — set LLM_API_KEY=...
echo      (DeepSeek: https://platform.deepseek.com/  or OpenRouter / Ollama)
echo   2. Copy this folder to: ^<YourWindowerInstall^>\addons\kotoba\
echo      (if you are not already running from that path)
echo   3. In FFXI: //lua load kotoba
echo      (addon auto-starts translator.py via pythonw)
echo   4. Optional: run start_translator.bat for a visible console
echo   5. Type //kotoba or //kb in game for commands / panel
echo.
pause
