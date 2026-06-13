@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "PPKG=%ROOT%Edict\prov.ppkg"
set "DISM=%SystemRoot%\System32\dism.exe"
set "TIMEOUT=60"
set "MAX_WAIT=120"

if not exist "%PPKG%" exit /b 0

REM Install PPKG in background to avoid blocking OOBE
start "" /b "%DISM%" /online /add-provisioningpackage /packagepath:"%PPKG%" /quiet

REM Wait for DISM to complete, but don't block OOBE indefinitely
set /a waited=0
:wait_loop
timeout /t 2 /nobreak >nul
tasklist | find /i "dism.exe" >nul
if %errorlevel% equ 0 (
    set /a waited+=2
    if %waited% lss %MAX_WAIT% goto wait_loop
    REM If DISM is still running after max wait, kill it to prevent OOBE hang
    taskkill /f /im dism.exe >nul 2>&1
)

endlocal
exit /b 0
