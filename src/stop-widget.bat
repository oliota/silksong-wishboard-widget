@echo off
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*widget.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
