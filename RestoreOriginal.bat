@echo off
title Sonar Shock - Restore Original
setlocal
set "D=%~dp0"
set "G="
if exist "%D%Sonar Shock.pck.orig" set "G=%D%"
if not defined G if exist "%D%..\Sonar Shock.pck.orig" set "G=%D%..\"
if not defined G (
  echo Could not find "Sonar Shock.pck.orig" next to this script or one folder up.
  echo If you know where it is, just copy it over "Sonar Shock.pck" yourself.
  echo.
  pause
  exit /b 1
)
echo Restoring the original game data (copying 1.7 GB, give it a moment)...
copy /y "%G%Sonar Shock.pck.orig" "%G%Sonar Shock.pck" >nul
if errorlevel 1 (
  echo.
  echo Restore FAILED. Is the game still running?
  echo.
  pause
  exit /b 1
)
echo.
echo Done. "Sonar Shock.pck" is the untouched original again.
echo The backup file was kept, so you can re-apply the patch any time.
echo.
pause
