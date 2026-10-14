@echo off
setlocal
where node >nul 2>nul
if not errorlevel 1 (
  node "%~dp0approve.js"
  exit /b 0
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0approve.ps1"
exit /b 0
