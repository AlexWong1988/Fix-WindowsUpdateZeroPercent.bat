# Windows Update Stuck at 0% - Comprehensive Fix Script
# Run as Administrator
# Purpose: Reset Windows Update service and clear cache when stuck at 0%

#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Update 0% Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: This script must run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "[1/6] Stopping Windows Update service..." -ForegroundColor Yellow
try {
    Stop-Service -Name wuauserv -Force -ErrorAction Stop
    Write-Host "✓ wuauserv stopped" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to stop wuauserv: $_" -ForegroundColor Red
}

Write-Host "[2/6] Stopping Windows Update Medic Service..." -ForegroundColor Yellow
try {
    Stop-Service -Name WaaSMedicSvc -Force -ErrorAction SilentlyContinue
    Write-Host "✓ WaaSMedicSvc stopped" -ForegroundColor Green
} catch {
    Write-Host "⚠ WaaSMedicSvc not running (expected on some systems)" -ForegroundColor Gray
}

Write-Host "[3/6] Clearing Windows Update cache..." -ForegroundColor Yellow
$cachePaths = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Windows\Temp\*WU*",
    "C:\Windows\Temp\*update*"
)

foreach ($path in $cachePaths) {
    try {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Cleared: $path" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠ Could not clear $path (may be in use)" -ForegroundColor Gray
    }
}

Write-Host "[4/6] Resetting Windows Update components..." -ForegroundColor Yellow
try {
    # Reset network settings
    ipconfig /flushdns | Out-Null
    Write-Host "✓ Flushed DNS cache" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not flush DNS" -ForegroundColor Gray
}

# Reset Bits service
try {
    Stop-Service -Name BITS -Force -ErrorAction Stop
    Write-Host "✓ BITS service stopped" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not stop BITS service" -ForegroundColor Gray
}

Write-Host "[5/6] Restarting services..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    Start-Service -Name BITS
    Write-Host "✓ BITS service started" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to start BITS: $_" -ForegroundColor Red
}

try {
    Start-Service -Name wuauserv
    Write-Host "✓ wuauserv started" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to start wuauserv: $_" -ForegroundColor Red
}

Write-Host "[6/6] Checking for available updates..." -ForegroundColor Yellow
Write-Host ""

# Initialize COM objects for Windows Update
$UpdateSession = $null
$UpdateSearcher = $null
$SearchResult = $null
$UpdatesToInstall = $null

try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    
    Write-Host "  Searching for updates (this may take a minute)..." -ForegroundColor Gray
    $SearchResult = $UpdateSearcher.Search("IsInstalled=0")
    
    if ($SearchResult.Updates.Count -eq 0) {
        Write-Host "✓ No updates available - system is current!" -ForegroundColor Green
    } else {
        Write-Host "✓ Found $($SearchResult.Updates.Count) update(s)" -ForegroundColor Green
        Write-Host ""
        
        # Display available updates
        Write-Host "Available Updates:" -ForegroundColor Cyan
        $SearchResult.Updates | ForEach-Object {
            Write-Host "  • $($_.Title)" -ForegroundColor White
            if ($_.Description) {
                Write-Host "    $($_.Description.Substring(0, [Math]::Min(80, $_.Description.Length)))..." -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        # Prepare updates for installation
        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        $SearchResult.Updates | ForEach-Object {
            $UpdatesToInstall.Add($_) | Out-Null
        }
        
        Write-Host "Attempting to install updates..." -ForegroundColor Yellow
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesToInstall
        
        Write-Host "  This may take several minutes..." -ForegroundColor Gray
        $InstallationResult = $Installer.Install()
        
        if ($InstallationResult.ResultCode -eq 4) {
            Write-Host "✓ Updates installed successfully!" -ForegroundColor Green
            Write-Host "⚠ Computer restart may be required" -ForegroundColor Yellow
        } elseif ($InstallationResult.ResultCode -eq 3) {
            Write-Host "⚠ Updates installed but restart is required" -ForegroundColor Yellow
        } elseif ($InstallationResult.ResultCode -eq 2) {
            Write-Host "⚠ Some updates failed installation" -ForegroundColor Yellow
        } else {
            Write-Host "✓ Installation process completed (Code: $($InstallationResult.ResultCode))" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "⚠ Could not perform automatic update check/install: $_" -ForegroundColor Yellow
    Write-Host "   You can manually check for updates in Settings > Update & Security" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Update Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ask about restart
Write-Host "Restart Required?" -ForegroundColor Cyan
Write-Host "  If updates were installed, restart is often needed for completion." -ForegroundColor White

$restartNow = Read-Host "Restart computer now? (y/n)"
if ($restartNow -eq 'y' -or $restartNow -eq 'Y') {
    Write-Host ""
    Write-Host "Restarting in 30 seconds... (Press Ctrl+C to cancel)" -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "Reminder: Restart manually when ready for updates to complete" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps if issues persist:" -ForegroundColor Cyan
    Write-Host "  1. Restart your computer" -ForegroundColor White
    Write-Host "  2. Open Settings > Update & Security > Windows Update" -ForegroundColor White
    Write-Host "  3. Check for updates again" -ForegroundColor White
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  • Check Event Viewer > Windows Logs > System for WU errors" -ForegroundColor White
    Write-Host "  • Run 'sfc /scannow' in Command Prompt (admin) for system file repair" -ForegroundColor White
    Write-Host "  • See Windows-Update-0-Percent-Troubleshooting-Guide.txt for advanced options" -ForegroundColor White
}
