@echo off
setlocal enableextensions

timeout /t 15 /nobreak >nul

set "ROOT=%~dp0"
set "MSI=%ROOT%Edict\PowerShell.msi"
set "PS7=C:\Program Files\PowerShell\7\pwsh.exe"
set "PS1=%ROOT%Edict\start.ps1"

if exist "%MSI%" (
    msiexec /i "%MSI%" /qn /norestart
)

timeout /t 15 /nobreak >nul

if exist "%PS7%" (
    "%PS7%" -ExecutionPolicy Bypass -NoProfile -File "%PS1%"
)

timeout /t 120 /nobreak >nul

endlocal
exit /b 0
