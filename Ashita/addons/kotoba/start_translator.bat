@echo off
echo Kotoba Translation Service (DeepL Edition)
echo ==========================================
echo.
echo Installing required package...
pip install deepl
echo.
echo Starting translator...
echo Press Ctrl+C to stop
echo.
python translator.py
pause

