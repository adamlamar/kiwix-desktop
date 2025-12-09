# MSIX Execution Fix Script
# This script fixes common MSIX execution issues for Qt applications

Write-Host "=== MSIX Execution Fix for Kiwix Desktop ===" -ForegroundColor Cyan

# Step 1: Find the correct MSIX package location
Write-Host "`nStep 1: Locating MSIX package..." -ForegroundColor Yellow

$kiwixPackages = Get-ChildItem "C:\Program Files\WindowsApps" -Directory | Where-Object { $_.Name -like "*Kiwix*" }

if ($kiwixPackages.Count -eq 0) {
    Write-Host "ERROR: No Kiwix MSIX packages found!" -ForegroundColor Red
    Write-Host "Please ensure the MSIX package is properly installed." -ForegroundColor Yellow
    exit 1
}

$packagePath = $kiwixPackages[0].FullName
$exePath = Join-Path $packagePath "kiwix-desktop.exe"

Write-Host "Found package: $packagePath" -ForegroundColor Green
Write-Host "Executable path: $exePath" -ForegroundColor Green

# Step 2: Verify executable exists
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: kiwix-desktop.exe not found in package!" -ForegroundColor Red
    exit 1
}

# Step 3: Change to package directory (CRITICAL for MSIX execution)
Write-Host "`nStep 2: Changing to package directory..." -ForegroundColor Yellow
Push-Location $packagePath

# Step 4: Test basic file access
Write-Host "`nStep 3: Testing file access..." -ForegroundColor Yellow
try {
    $fileInfo = Get-Item "kiwix-desktop.exe"
    Write-Host "✓ File accessible: $($fileInfo.Length) bytes" -ForegroundColor Green
} catch {
    Write-Host "✗ File access failed: $($_.Exception.Message)" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Step 5: Check and fix qt.conf
Write-Host "`nStep 4: Checking Qt configuration..." -ForegroundColor Yellow

$qtConfPath = "qt.conf"
$correctQtConf = @"
[Paths]
Plugins = plugins
"@

if (Test-Path $qtConfPath) {
    $currentContent = Get-Content $qtConfPath -Raw -ErrorAction SilentlyContinue
    Write-Host "Current qt.conf content:" -ForegroundColor Gray
    $currentContent.Split("`n") | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Check if it contains problematic QML paths
    if ($currentContent -like "*Qml*") {
        Write-Host "⚠ Detected potentially problematic QML paths in qt.conf" -ForegroundColor Yellow
        Write-Host "Fixing qt.conf..." -ForegroundColor Yellow
        try {
            $correctQtConf | Set-Content $qtConfPath -Encoding UTF8
            Write-Host "✓ qt.conf fixed" -ForegroundColor Green
        } catch {
            Write-Host "✗ Could not fix qt.conf: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "✓ qt.conf appears correct" -ForegroundColor Green
    }
} else {
    Write-Host "qt.conf missing, creating..." -ForegroundColor Yellow
    try {
        $correctQtConf | Set-Content $qtConfPath -Encoding UTF8
        Write-Host "✓ qt.conf created" -ForegroundColor Green
    } catch {
        Write-Host "✗ Could not create qt.conf: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 6: Test Qt libraries
Write-Host "`nStep 5: Checking Qt libraries..." -ForegroundColor Yellow
$qtDlls = Get-ChildItem . -Filter "Qt*.dll"
Write-Host "Qt DLLs found: $($qtDlls.Count)" -ForegroundColor Green

$criticalQt6Dlls = @(
    "Qt6Core.dll", "Qt6Gui.dll", "Qt6Widgets.dll", 
    "Qt6Network.dll", "Qt6WebEngineCore.dll", "Qt6WebEngineWidgets.dll"
)

foreach ($dll in $criticalQt6Dlls) {
    if (Test-Path $dll) {
        Write-Host "  ✓ $dll" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $dll MISSING" -ForegroundColor Red
    }
}

# Step 7: Test execution with proper environment
Write-Host "`nStep 6: Testing execution..." -ForegroundColor Yellow

# Set Qt environment variables
$env:QT_PLUGIN_PATH = Join-Path $packagePath "plugins"
$env:QT_QPA_PLATFORM_PLUGIN_PATH = Join-Path $packagePath "plugins\platforms"

Write-Host "Set QT_PLUGIN_PATH: $env:QT_PLUGIN_PATH" -ForegroundColor Gray
Write-Host "Set QT_QPA_PLATFORM_PLUGIN_PATH: $env:QT_QPA_PLATFORM_PLUGIN_PATH" -ForegroundColor Gray

# Test 1: Version check
Write-Host "`nTest 1: Version check..." -ForegroundColor Cyan
try {
    $process = Start-Process -FilePath ".\kiwix-desktop.exe" -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "version_output.txt" -RedirectStandardError "version_error.txt"
    
    Write-Host "Exit code: $($process.ExitCode)"
    
    if (Test-Path "version_output.txt") {
        $output = Get-Content "version_output.txt" -Raw
        if ($output.Trim()) {
            Write-Host "Output: $output" -ForegroundColor Green
        }
    }
    
    if (Test-Path "version_error.txt") {
        $error = Get-Content "version_error.txt" -Raw
        if ($error.Trim()) {
            Write-Host "Error: $error" -ForegroundColor Red
        }
    }
    
    # Cleanup
    Remove-Item "version_output.txt" -ErrorAction SilentlyContinue
    Remove-Item "version_error.txt" -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "Execution failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: GUI application launch (brief)
Write-Host "`nTest 2: Brief GUI launch test..." -ForegroundColor Cyan
try {
    $process = Start-Process -FilePath ".\kiwix-desktop.exe" -PassThru
    Start-Sleep -Seconds 3
    
    if (-not $process.HasExited) {
        Write-Host "✓ Application launched successfully!" -ForegroundColor Green
        Write-Host "Terminating test application..." -ForegroundColor Yellow
        $process.Kill()
        $process.WaitForExit()
    } else {
        Write-Host "✗ Application exited immediately with code: $($process.ExitCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "GUI launch failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 8: Generate diagnostic report
Write-Host "`nStep 7: Generating diagnostic report..." -ForegroundColor Yellow

$report = @"
=== KIWIX MSIX DIAGNOSTIC REPORT ===
Generated: $(Get-Date)
Package Path: $packagePath
Executable: $exePath

Package Contents:
$(Get-ChildItem . | Out-String)

Qt Libraries:
$(Get-ChildItem . -Filter "Qt*.dll" | Select-Object Name, Length | Out-String)

Environment:
QT_PLUGIN_PATH: $env:QT_PLUGIN_PATH
Working Directory: $(Get-Location)

"@

$report | Set-Content "kiwix-diagnostic-report.txt"
Write-Host "✓ Diagnostic report saved to: kiwix-diagnostic-report.txt" -ForegroundColor Green

Pop-Location

Write-Host "`n=== EXECUTION TEST COMPLETE ===" -ForegroundColor Cyan
Write-Host "If the application still doesn't launch properly, the issue may be:" -ForegroundColor Yellow
Write-Host "1. Qt WebEngine compatibility issues with MSIX sandboxing" -ForegroundColor Gray
Write-Host "2. Missing system-level dependencies" -ForegroundColor Gray
Write-Host "3. MSIX capability restrictions" -ForegroundColor Gray
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run: debug-msix-environment.ps1 for detailed analysis" -ForegroundColor Gray
Write-Host "2. Check Windows Event Viewer for application errors" -ForegroundColor Gray
Write-Host "3. Consider Qt WebEngine MSIX compatibility flags" -ForegroundColor Gray