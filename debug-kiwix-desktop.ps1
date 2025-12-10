# PowerShell Debug Script for Kiwix Desktop
# This script helps diagnose launch issues by checking dependencies and environment

Write-Host "=== Kiwix Desktop Dependency Checker ===" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $scriptDir "kiwix-desktop.exe"

# Check if main executable exists
if (Test-Path $exePath) {
    Write-Host "✓ Main executable found" -ForegroundColor Green
    $exe = Get-Item $exePath
    Write-Host "  Size: $($exe.Length) bytes"
    Write-Host "  Modified: $($exe.LastWriteTime)"
} else {
    Write-Host "✗ Main executable NOT found" -ForegroundColor Red
    exit 1
}

# Check Qt platform plugins
$platformsDir = Join-Path $scriptDir "platforms"
if (Test-Path $platformsDir) {
    Write-Host "✓ Platforms directory found" -ForegroundColor Green
    $plugins = Get-ChildItem $platformsDir -Filter "*.dll"
    foreach ($plugin in $plugins) {
        Write-Host "  - $($plugin.Name)"
    }
    if (-not $plugins) {
        Write-Host "✗ No platform plugins found!" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Platforms directory NOT found" -ForegroundColor Red
}

# Check critical Qt DLLs
$criticalDlls = @(
    "Qt6Core.dll", "Qt6Gui.dll", "Qt6Widgets.dll",
    "Qt6WebEngineWidgets.dll", "Qt6WebEngineCore.dll",
    "Qt6Network.dll", "Qt6PrintSupport.dll"
)

Write-Host "`nChecking Qt libraries:" -ForegroundColor Yellow
foreach ($dll in $criticalDlls) {
    $dllPath = Join-Path $scriptDir $dll
    if (Test-Path $dllPath) {
        Write-Host "✓ $dll" -ForegroundColor Green
    } else {
        Write-Host "✗ $dll MISSING" -ForegroundColor Red
    }
}

# Check VC++ Runtime
Write-Host "`nChecking VC++ Runtime:" -ForegroundColor Yellow
$vcDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")
foreach ($dll in $vcDlls) {
    $dllPath = Join-Path $scriptDir $dll
    if (Test-Path $dllPath) {
        Write-Host "✓ $dll" -ForegroundColor Green
    } else {
        Write-Host "✗ $dll MISSING" -ForegroundColor Red
    }
}

# Try to get DLL dependencies using dumpbin if available
try {
    $dumpbin = Get-Command "dumpbin.exe" -ErrorAction SilentlyContinue
    if ($dumpbin) {
        Write-Host "`nDLL Dependencies (from dumpbin):" -ForegroundColor Yellow
        & dumpbin /dependents $exePath | Select-String "\.dll" | ForEach-Object {
            $dll = $_.Line.Trim()
            Write-Host "  $dll"
        }
    }
} catch {
    Write-Host "Could not run dumpbin to check dependencies" -ForegroundColor Yellow
}

Write-Host "`n=== Launch Attempt ===" -ForegroundColor Cyan

# Set Qt debug environment
$env:QT_DEBUG_LOGGING = "1"
$env:QT_LOGGING_RULES = "*.debug=true;qt.qpa.*=true"
$env:QT_QPA_PLATFORM_PLUGIN_PATH = $platformsDir
$env:QT_PLUGIN_PATH = $scriptDir

Write-Host "Environment variables set:"
Write-Host "  QT_QPA_PLATFORM_PLUGIN_PATH = $env:QT_QPA_PLATFORM_PLUGIN_PATH"
Write-Host "  QT_PLUGIN_PATH = $env:QT_PLUGIN_PATH"
Write-Host ""

Write-Host "Launching application..." -ForegroundColor Yellow
try {
    & $exePath --help 2>&1 | Tee-Object -FilePath (Join-Path $scriptDir "debug_output.log")
} catch {
    Write-Host "Exception during launch: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nCheck debug_output.log for any additional messages."
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
