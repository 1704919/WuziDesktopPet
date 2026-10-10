 1 | @echo off
 2 | setlocal
 3 | cd /d "%~dp0.."
 4 | powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restart_godot_pet.ps1" -ProjectPath "%~dp0..\godot"
 5 | if errorlevel 1 (
 6 |   echo.
 7 |   echo Startup failed. Check the output above before closing this window.
 8 |   pause
 9 | )
endlocal
