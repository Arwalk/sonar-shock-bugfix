@echo off
title Sonar Shock - Community Bugfix Patch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ApplyPatch.ps1"
echo.
pause
