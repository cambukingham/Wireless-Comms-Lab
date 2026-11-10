@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\setup_bench.ps1"
if errorlevel 1 (
    echo.
    echo Setup did not complete. Read the error above.
    pause
    exit /b 1
)
echo.
echo Setup complete. Open WINLAB Bench from the Start menu.
pause
