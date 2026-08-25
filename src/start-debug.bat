@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0widget.ps1"
echo.
echo Exit code: %ERRORLEVEL%
if exist "%~dp0widget-error.txt" (
  echo.
  echo ===== widget-error.txt =====
  type "%~dp0widget-error.txt"
)
pause
