@echo off
setlocal
set "GUI_PYTHON="
if exist "%~dp0.venv\Scripts\pythonw.exe" set "GUI_PYTHON=%~dp0.venv\Scripts\pythonw.exe"
if not defined GUI_PYTHON for /f "delims=" %%P in ('py -3 -c "import sys, tkinter; print(sys.executable)" 2^>nul') do if exist "%%~dpPpythonw.exe" set "GUI_PYTHON=%%~dpPpythonw.exe"
if not defined GUI_PYTHON for /f "delims=" %%P in ('python -c "import sys, tkinter; print(sys.executable)" 2^>nul') do if exist "%%~dpPpythonw.exe" set "GUI_PYTHON=%%~dpPpythonw.exe"
if not defined GUI_PYTHON if exist "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\pythonw.exe" set "GUI_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\pythonw.exe"
if not defined GUI_PYTHON (
    echo Python with Tkinter was not found. Install Python for Windows or set up .venv in this folder.
    pause
    exit /b 1
)
if /i "%~1"=="--check" (
    echo %GUI_PYTHON%
    exit /b 0
)
start "WINLAB Bench" /D "%~dp0proteus_control" "%GUI_PYTHON%" "%~dp0proteus_control\bench_panel.py"
