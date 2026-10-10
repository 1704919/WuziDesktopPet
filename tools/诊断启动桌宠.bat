@echo off
setlocal
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restart_godot_pet.ps1" -ProjectPath "%~dp0..\godot"
if errorlevel 1 (
  echo.
  echo Startup failed. Check the output above before closing this window.
  pause
)
endlocal
