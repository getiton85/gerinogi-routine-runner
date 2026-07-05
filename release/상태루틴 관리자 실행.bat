@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File ""%~dp0local_state_routine_runner.ps1""' -WorkingDirectory '%~dp0' -Verb RunAs"
exit /b
