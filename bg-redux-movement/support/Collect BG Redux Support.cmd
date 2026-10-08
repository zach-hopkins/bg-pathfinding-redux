@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bg-redux-movement\support\collect-support.ps1" -GameDirectory "%~dp0."
if errorlevel 1 echo Support collection failed. Please share the error above.
pause
