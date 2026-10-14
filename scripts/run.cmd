@echo off
setlocal
set "AA_NODE="
for %%i in (node.exe) do set "AA_NODE=%%~$PATH:i"
if defined AA_NODE (
  "%AA_NODE%" "%~dp0approve.js"
  exit /b 0
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0approve.ps1"
exit /b 0
