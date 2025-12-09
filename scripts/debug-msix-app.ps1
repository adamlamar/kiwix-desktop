# MSIX Qt Debugging Helper
# This script helps debug Qt applications installed as MSIX packages

param(
    [string]$PackageName = "KiwixFoundation.Kiwix",
    [switch]$QtDebug,
    [switch]$WebEngineDebug,
    [switch]$ShowHelp
)

if ($ShowHelp) {
    Write-Host @"
MSIX Qt Debugging Helper

Usage:
  .\debug-msix-app.ps1 [-QtDebug] [-WebEngineDebug] [-PackageName <name>]

Parameters:
  -QtDebug        Enable Qt plugin debugging (QT_DEBUG_PLUGINS=1)
  -WebEngineDebug Enable WebEngine debugging with safe flags
  -PackageName    Override package name (default: KiwixFoundation.Kiwix)
  -ShowHelp       Show this help message

Examples:
  .\debug-msix-app.ps1 -QtDebug
  .\debug-msix-app.ps1 -WebEngineDebug
  .\debug-msix-app.ps1 -QtDebug -WebEngineDebug

Note: MSIX applications cannot be launched directly from their installation directory.
This script uses alternative methods to launch with debugging enabled.
"@
    return
}

Write-Host "=== MSIX Qt Debugging Helper ===" -ForegroundColor Cyan
Write-Host ""

# Find the package
Write-Host "Looking for package: $PackageName" -ForegroundColor Yellow
$package = Get-AppxPackage -Name "*$PackageName*" | Select-Object -First 1

if (-not $package) {
    Write-Host "ERROR: Package not found. Available packages:" -ForegroundColor Red
    Get-AppxPackage | Where-Object { $_.Name -like "*Kiwix*" } | ForEach-Object {
        Write-Host "  $($_.Name) - $($_.PackageFullName)" -ForegroundColor Gray
    }
    return
}

Write-Host "Found package: $($package.PackageFullName)" -ForegroundColor Green
Write-Host "Installation location: $($package.InstallLocation)" -ForegroundColor Gray
Write-Host ""

# Set up environment variables for debugging
$envVars = @{}

if ($QtDebug) {
    $envVars["QT_DEBUG_PLUGINS"] = "1"
    $envVars["QT_LOGGING_RULES"] = "qt.qpa.plugins.debug=true"
    Write-Host "Qt debugging enabled" -ForegroundColor Yellow
}

if ($WebEngineDebug) {
    $envVars["QTWEBENGINE_CHROMIUM_FLAGS"] = "--disable-gpu --no-sandbox --disable-dev-shm-usage --disable-extensions"
    $envVars["QTWEBENGINE_REMOTE_DEBUGGING"] = "9222"
    Write-Host "WebEngine debugging enabled" -ForegroundColor Yellow
}

# Try different approaches to launch the app with environment variables

Write-Host ""
Write-Host "=== Launch Attempts ===" -ForegroundColor Cyan

# Method 1: Try using explorer to launch with environment
Write-Host "Method 1: Using Windows shell launch..." -ForegroundColor White
try {
    # Set environment variables in current session
    foreach ($var in $envVars.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($var.Key, $var.Value, "Process")
        Write-Host "  Set $($var.Key)=$($var.Value)" -ForegroundColor Gray
    }

    # Try launching via shell
    $appId = "$($package.PackageFamilyName)!KiwixDesktop"
    Write-Host "  Attempting to launch: $appId" -ForegroundColor Gray

    # Use shell execute to launch the app
    Start-Process "shell:AppsFolder\$appId" -ErrorAction Stop
    Write-Host "  Launch initiated successfully" -ForegroundColor Green
    Write-Host "  Note: Environment variables are set in this PowerShell session" -ForegroundColor Yellow
    Write-Host "  Check Windows Event Viewer for application logs and debugging output" -ForegroundColor Yellow

} catch {
    Write-Host "  Method 1 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Method 2: Alternative registry-based approach
Write-Host "Method 2: Alternative launch methods..." -ForegroundColor White
Write-Host "  You can also try launching from Start Menu while environment is set" -ForegroundColor Gray
Write-Host "  Or use: Get-StartApps | Where-Object Name -like '*Kiwix*' | Start-Process" -ForegroundColor Gray

Write-Host ""

# Method 3: Manual debugging suggestions
Write-Host "Method 3: Manual debugging steps..." -ForegroundColor White
Write-Host "1. Set environment variables globally:" -ForegroundColor Gray
foreach ($var in $envVars.GetEnumerator()) {
    Write-Host "   [Environment]::SetEnvironmentVariable('$($var.Key)', '$($var.Value)', 'User')" -ForegroundColor Gray
}
Write-Host ""
Write-Host "2. Launch Kiwix from Start Menu" -ForegroundColor Gray
Write-Host "3. Check Event Viewer: Windows Logs > Application" -ForegroundColor Gray
Write-Host "4. Look for Qt debugging output in console or log files" -ForegroundColor Gray

Write-Host ""

# Show process monitoring suggestion
Write-Host "=== Process Monitoring ===" -ForegroundColor Cyan
Write-Host "To monitor the process and see crashes in real-time:" -ForegroundColor White
Write-Host 'Get-EventLog -LogName Application -Newest 10 | Where-Object {$_.Source -eq "Application Error" -and $_.Message -like "*kiwix*"}' -ForegroundColor Gray

Write-Host ""
Write-Host "=== Debugging Complete ===" -ForegroundColor Cyan
