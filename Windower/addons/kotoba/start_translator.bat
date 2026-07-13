@echo off
echo Kotoba Translation Service (LLM Edition)
echo ========================================
echo.
echo Installing required package...
pip install httpx
echo.
if not exist translations.db (
    echo First run detected - building seed database...
    python build_seed_db.py
    echo.
)
echo Starting translator...
echo Press Ctrl+C to stop
echo.
python translator.py
pause
