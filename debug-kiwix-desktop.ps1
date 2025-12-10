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

Write-Host "Testing if executable reaches main() function..." -ForegroundColor Yellow
Write-Host "Expected output: 'Starting Kiwix Desktop...'"
Write-Host ""

try {
    # Capture both stdout and stderr
    $process = Start-Process -FilePath $exePath -ArgumentList "--help" -Wait -PassThru -RedirectStandardOutput "stdout.log" -RedirectStandardError "stderr.log" -NoNewWindow

    Write-Host "Process completed with exit code: $($process.ExitCode)"

    # Check if we got the expected startup message
    if (Test-Path "stdout.log") {
        $stdout = Get-Content "stdout.log" -Raw
        if ($stdout -and $stdout.Contains("Starting Kiwix Desktop")) {
            Write-Host "✓ Application reaches main() function" -ForegroundColor Green
            Write-Host "Standard output:" -ForegroundColor Green
            Write-Host $stdout
        } else {
            Write-Host "✗ Application does NOT reach main() function" -ForegroundColor Red
            Write-Host "This indicates a DLL loading or runtime initialization failure"
            if ($stdout) {
                Write-Host "Unexpected output: $stdout" -ForegroundColor Yellow
            }
        }
    }

    if (Test-Path "stderr.log") {
        $stderr = Get-Content "stderr.log" -Raw
        if ($stderr) {
            Write-Host "Standard error:" -ForegroundColor Red
            Write-Host $stderr
        }
    }

    # If no output at all, it's definitely a DLL issue
    if (-not (Test-Path "stdout.log") -and -not (Test-Path "stderr.log")) {
        Write-Host "✗ No output captured - severe initialization failure" -ForegroundColor Red
    }
} catch {
    Write-Host "Exception during launch: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Additional Debugging Suggestions ===" -ForegroundColor Cyan
Write-Host "If the application doesn't reach main():"
Write-Host "1. Run 'dll-checker.ps1' for detailed DLL analysis"
Write-Host "2. Use Process Monitor to see file access attempts"
Write-Host "3. Check Windows Event Viewer for crash logs"
Write-Host "4. Verify all Qt6 platform plugins are present"

Write-Host "`nCheck debug_output.log for any additional messages."
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
