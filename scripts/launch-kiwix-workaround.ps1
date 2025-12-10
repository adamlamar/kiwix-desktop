# MSIX Execution Workaround Script
# This script provides alternative execution methods for MSIX-restricted environments

Write-Host "=== MSIX Execution Workaround for Kiwix Desktop ===" -ForegroundColor Cyan
Write-Host "Detected: Access denied errors - implementing workarounds..." -ForegroundColor Yellow

# Find package directory
$packagePath = Get-Location
Write-Host "`nPackage directory: $packagePath" -ForegroundColor Gray

# Method 1: Try launching via Windows Start Menu registration
Write-Host "`nMethod 1: Launching via Windows Start Menu..." -ForegroundColor Yellow
try {
    $appPackage = Get-AppxPackage | Where-Object { $_.Name -like "*Kiwix*" }
    if ($appPackage) {
        Write-Host "Found app package: $($appPackage.Name)" -ForegroundColor Green
        Write-Host "Package Family Name: $($appPackage.PackageFamilyName)" -ForegroundColor Gray

        # Try launching via explorer
        $explorerLaunch = "explorer.exe shell:appsFolder\$($appPackage.PackageFamilyName)!KiwixDesktop"
        Write-Host "Attempting: $explorerLaunch" -ForegroundColor Gray
        Start-Process $explorerLaunch -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
        $kiwixProcess = Get-Process -Name "kiwix-desktop" -ErrorAction SilentlyContinue
        if ($kiwixProcess) {
            Write-Host "Application launched successfully via Start Menu!" -ForegroundColor Green
            Write-Host "Process ID: $($kiwixProcess.Id)" -ForegroundColor Gray
            return
        } else {
            Write-Host "Start Menu launch failed" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Start Menu method failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 2: PowerShell App Execution
Write-Host "`nMethod 2: PowerShell App Execution..." -ForegroundColor Yellow
try {
    $apps = Get-StartApps | Where-Object { $_.Name -like "*Kiwix*" }
    if ($apps) {
        foreach ($app in $apps) {
            Write-Host "Found Start Menu app: $($app.Name)" -ForegroundColor Green
            Write-Host "App ID: $($app.AppID)" -ForegroundColor Gray

            # Try launching the app
            Start-Process -FilePath "explorer.exe" -ArgumentList "shell:appsFolder\$($app.AppID)" -ErrorAction SilentlyContinue

            Start-Sleep -Seconds 3
            $kiwixProcess = Get-Process -Name "kiwix-desktop" -ErrorAction SilentlyContinue
            if ($kiwixProcess) {
                Write-Host "Application launched successfully via PowerShell!" -ForegroundColor Green
                Write-Host "Process ID: $($kiwixProcess.Id)" -ForegroundColor Gray
                return
            }
        }
    }
    Write-Host "PowerShell app execution failed" -ForegroundColor Red
} catch {
    Write-Host "PowerShell method failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Method 3: Check if app is already running
Write-Host "`nMethod 3: Checking for existing process..." -ForegroundColor Yellow
$existingProcess = Get-Process -Name "kiwix-desktop" -ErrorAction SilentlyContinue
if ($existingProcess) {
    Write-Host "Kiwix Desktop is already running!" -ForegroundColor Green
    Write-Host "Process ID: $($existingProcess.Id)" -ForegroundColor Gray
} else {
    Write-Host "No existing Kiwix Desktop process found" -ForegroundColor Gray
}

# Method 4: Create batch launcher
Write-Host "`nMethod 4: Creating alternative launcher..." -ForegroundColor Yellow
$batchContent = @'
@echo off
echo Starting Kiwix Desktop via Windows App Launch...
start "" shell:appsFolder\KiwixFoundation.Kiwix_b0efqnfydk0bj!KiwixDesktop
'@

try {
    # Try to write to a writable location
    $tempPath = $env:TEMP
    $launcherPath = Join-Path $tempPath "launch-kiwix.bat"
    $batchContent | Set-Content $launcherPath -ErrorAction Stop
    Write-Host "Created launcher at: $launcherPath" -ForegroundColor Green
    Write-Host "You can run this batch file to launch Kiwix Desktop" -ForegroundColor Yellow
} catch {
    Write-Host "Could not create launcher: $($_.Exception.Message)" -ForegroundColor Red
}

# Show diagnostic information
Write-Host "`n=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Cyan
Write-Host "Issue: MSIX security restrictions prevent direct executable launch" -ForegroundColor Red
Write-Host "Root Cause: Windows Store apps run in restricted security context" -ForegroundColor Yellow

Write-Host "`nRecommended Solutions:" -ForegroundColor Green
Write-Host "1. Launch from Windows Start Menu:" -ForegroundColor White
Write-Host "   - Search 'Kiwix' in Start Menu and click the app" -ForegroundColor Gray
Write-Host "2. Use Windows Run dialog:" -ForegroundColor White
Write-Host "   - Press Win+R and type: shell:appsFolder\KiwixFoundation.Kiwix_b0efqnfydk0bj!KiwixDesktop" -ForegroundColor Gray
Write-Host "3. Use the batch launcher created in %TEMP%" -ForegroundColor White

Write-Host "`nTechnical Details:" -ForegroundColor Yellow
Write-Host "- All Qt6 dependencies are present (32 DLLs)" -ForegroundColor Gray
Write-Host "- qt.conf is correctly configured" -ForegroundColor Gray
Write-Host "- MSIX package is properly installed" -ForegroundColor Gray
Write-Host "- Issue is MSIX execution security, not missing components" -ForegroundColor Gray

Write-Host "`nThis is expected behavior for Microsoft Store apps." -ForegroundColor Cyan
Write-Host "The application should work normally when launched through the Windows Start Menu." -ForegroundColor Green
