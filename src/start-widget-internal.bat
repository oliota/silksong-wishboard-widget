@echo off
cd /d "%~dp0"
start "" wscript.exe "%~dp0start-widget.vbs"
exit /b 0
