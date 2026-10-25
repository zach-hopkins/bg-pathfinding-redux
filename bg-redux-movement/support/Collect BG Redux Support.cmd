@echo off
setlocal
set "BG_REDUX_SCRIPT=%~dp0collect-support.ps1"
set "BG_REDUX_GAME=%~dp0..\.."
if not exist "%BG_REDUX_SCRIPT%" (
  set "BG_REDUX_SCRIPT=%~dp0bg-redux-movement\support\collect-support.ps1"
  set "BG_REDUX_GAME=%~dp0."
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BG_REDUX_SCRIPT%" -GameDirectory "%BG_REDUX_GAME%"
if errorlevel 1 echo Support collection failed. Please share the error above.
pause
