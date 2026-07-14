@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Local State Routine Runner debug start...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0local_state_routine_runner.ps1"
echo.
echo Program closed or failed. Exit code: %ERRORLEVEL%
echo If an error message appeared above, send it to Codex.
pause