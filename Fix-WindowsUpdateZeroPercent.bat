@echo off
REM Windows Update Stuck at 0% - Batch File Fix
REM Run as Administrator
REM Purpose: Reset Windows Update service and clear cache

setlocal enabledelayedexpansion

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must run as Administrator
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo.
echo ========================================
echo Windows Update 0%% Fix
echo ========================================
echo.

REM Step 1: Stop services
echo [1/5] Stopping Windows Update service...
net stop wuauserv /y >nul 2>&1
if %errorLevel% equ 0 (
    echo + wuauserv stopped
) else (
    echo - Failed to stop wuauserv
)

net stop WaaSMedicSvc /y >nul 2>&1
if %errorLevel% equ 0 (
    echo + WaaSMedicSvc stopped
)

net stop BITS /y >nul 2>&1
if %errorLevel% equ 0 (
    echo + BITS stopped
)

REM Step 2: Clear Windows Update cache
echo [2/5] Clearing Windows Update cache...
if exist "C:\Windows\SoftwareDistribution\Download" (
    echo Clearing SoftwareDistribution\Download...
    rmdir /S /Q "C:\Windows\SoftwareDistribution\Download" >nul 2>&1
    echo + Cache cleared
)

REM Step 3: Flush DNS
echo [3/5] Flushing DNS cache...
ipconfig /flushdns >nul 2>&1
echo + DNS flushed

REM Step 4: Restart services
echo [4/5] Restarting services...
timeout /t 2 /nobreak >nul

net start BITS >nul 2>&1
if %errorLevel% equ 0 (
    echo + BITS started
)

net start wuauserv >nul 2>&1
if %errorLevel% equ 0 (
    echo + wuauserv started
)

REM Step 5: Create temporary PowerShell script for update check/install
echo [5/5] Preparing update check and installation...
echo.

setlocal enabledelayedexpansion

REM Create a temporary PowerShell script
set "PSScriptPath=%TEMP%\WU_UpdateCheck.ps1"

(
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo $UpdateSession = New-Object -ComObject Microsoft.Update.Session
echo $UpdateSearcher = $UpdateSession.CreateUpdateSearcher^(^)
echo Write-Host "Searching for available updates..." -ForegroundColor Yellow
echo $SearchResult = $UpdateSearcher.Search^('IsInstalled=0'^)
echo.
echo if ^($SearchResult.Updates.Count -gt 0^) {
echo     Write-Host "Found $($SearchResult.Updates.Count) update(s):" -ForegroundColor Green
echo     Write-Host ""
echo     $SearchResult.Updates ^| ForEach-Object {Write-Host "  - $($_.Title)" -ForegroundColor White}
echo     Write-Host ""
echo     Write-Host "Installing updates (this may take several minutes)..." -ForegroundColor Yellow
echo     $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
echo     $SearchResult.Updates ^| ForEach-Object {$UpdatesToInstall.Add^($_^) ^| Out-Null}
echo     $Installer = $UpdateSession.CreateUpdateInstaller^(^)
echo     $Installer.Updates = $UpdatesToInstall
echo     $InstallationResult = $Installer.Install^(^)
echo     if ^($InstallationResult.ResultCode -eq 4^) {
echo         Write-Host "Updates installed successfully!" -ForegroundColor Green
echo         Write-Host "Restart may be required." -ForegroundColor Yellow
echo     } else {
echo         Write-Host "Installation completed (result code: $($InstallationResult.ResultCode))" -ForegroundColor Cyan
echo     }
echo } else {
echo     Write-Host "No updates available - system is current!" -ForegroundColor Green
echo }
) > "!PSScriptPath!"

REM Run the temporary PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "!PSScriptPath!"

REM Clean up temporary script
del "!PSScriptPath!" /Q 2>nul

echo.
echo ========================================
echo Fix Complete - Updates Checked
echo ========================================
echo.
echo Next steps:
echo   1. If updates were installed, restart your computer
echo   2. Open Settings ^> Update ^& Security ^> Windows Update
echo   3. Verify updates have completed
echo.
echo.
pause
