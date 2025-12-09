# Qt WebEngine MSIX Compatibility Script
# Addresses specific issues with Qt WebEngine in MSIX sandbox environment

param(
    [Parameter(Mandatory=$true)]
    [string]$PackagePath,
    
    [switch]$ApplyFixes,
    [switch]$Verbose
)

Write-Host "=== Qt WebEngine MSIX Compatibility Analysis ===" -ForegroundColor Cyan
Write-Host "Package: $PackagePath`n" -ForegroundColor Gray

if (-not (Test-Path $PackagePath)) {
    Write-Host "ERROR: Package path not found: $PackagePath" -ForegroundColor Red
    exit 1
}

Push-Location $PackagePath

# 1. Check WebEngine components
Write-Host "1. WebEngine Component Analysis:" -ForegroundColor Yellow
$webEngineComponents = @(
    "Qt6WebEngineCore.dll",
    "Qt6WebEngineWidgets.dll", 
    "QtWebEngineProcess.exe"
)

foreach ($component in $webEngineComponents) {
    if (Test-Path $component) {
        $size = (Get-Item $component).Length
        Write-Host "  ✓ $component ($([math]::Round($size/1MB, 2)) MB)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $component MISSING" -ForegroundColor Red
    }
}

# 2. Check WebEngine resources
Write-Host "`n2. WebEngine Resources:" -ForegroundColor Yellow
$webEngineResources = @{
    "icudtl.dat" = "ICU Data"
    "v8_context_snapshot.bin" = "V8 Context"
    "resources/qtwebengine_resources.pak" = "Web Resources"
    "resources/qtwebengine_resources_100p.pak" = "100% Resources"
    "resources/qtwebengine_resources_200p.pak" = "200% Resources"
    "locales/en-US.pak" = "English Locale"
}

foreach ($resource in $webEngineResources.Keys) {
    if (Test-Path $resource) {
        $size = (Get-Item $resource).Length
        Write-Host "  ✓ $($webEngineResources[$resource]): $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($webEngineResources[$resource]): $resource MISSING" -ForegroundColor Red
    }
}

# 3. Analyze qt.conf for WebEngine compatibility
Write-Host "`n3. qt.conf Analysis:" -ForegroundColor Yellow
if (Test-Path "qt.conf") {
    $qtConfContent = Get-Content "qt.conf" -Raw
    Write-Host "Current content:" -ForegroundColor Gray
    $qtConfContent.Split("`n") | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Check for WebEngine-specific settings
    $hasWebEngineSection = $qtConfContent -match "\[WebEngine\]"
    $hasSubprocessPath = $qtConfContent -match "BrowserSubprocessPath"
    
    Write-Host "`nCompatibility check:" -ForegroundColor Gray
    Write-Host "  WebEngine section: $(if ($hasWebEngineSection) { "✓" } else { "✗" })" -ForegroundColor $(if ($hasWebEngineSection) { "Green" } else { "Red" })
    Write-Host "  Subprocess path: $(if ($hasSubprocessPath) { "✓" } else { "✗" })" -ForegroundColor $(if ($hasSubprocessPath) { "Green" } else { "Red" })
} else {
    Write-Host "  qt.conf not found" -ForegroundColor Red
}

# 4. Test WebEngine process execution
Write-Host "`n4. WebEngine Process Test:" -ForegroundColor Yellow
if (Test-Path "QtWebEngineProcess.exe") {
    try {
        $webEngineInfo = Get-Command ".\QtWebEngineProcess.exe"
        Write-Host "  ✓ WebEngine process accessible" -ForegroundColor Green
        Write-Host "  Version: $($webEngineInfo.FileVersionInfo.FileVersion)" -ForegroundColor Gray
        
        # Test basic execution
        $testProcess = Start-Process -FilePath ".\QtWebEngineProcess.exe" -ArgumentList "--version" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
        if ($testProcess.ExitCode -ne $null) {
            Write-Host "  ✓ WebEngine process can execute (exit code: $($testProcess.ExitCode))" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ WebEngine process test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ QtWebEngineProcess.exe not found" -ForegroundColor Red
}

# 5. Check for MSIX-specific issues
Write-Host "`n5. MSIX Sandbox Compatibility:" -ForegroundColor Yellow

# Check if we're in an MSIX environment
$isInMSIX = $env:LOCALAPPDATA -and $env:LOCALAPPDATA.Contains("Packages")
Write-Host "  MSIX environment detected: $(if ($isInMSIX) { "Yes" } else { "No" })" -ForegroundColor $(if ($isInMSIX) { "Yellow" } else { "Green" })

# Check file permissions
try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "  Current user: $currentUser" -ForegroundColor Gray
    
    $exeAcl = Get-Acl "kiwix-desktop.exe" -ErrorAction SilentlyContinue
    if ($exeAcl) {
        Write-Host "  ✓ File permissions accessible" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Cannot read file permissions" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Permission check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Apply fixes if requested
if ($ApplyFixes) {
    Write-Host "`n6. Applying WebEngine MSIX Fixes:" -ForegroundColor Yellow
    
    # Fix 1: Enhanced qt.conf for MSIX
    $enhancedQtConf = @"
[Paths]
Plugins = plugins
Binaries = .
Libraries = .

[WebEngine]
BrowserSubprocessPath = QtWebEngineProcess.exe
DisableSandbox = true
SingleProcess = false
ProcessModel = process-per-site

[Platform]
WindowsArguments = --disable-web-security --allow-file-access-from-files --disable-features=VizDisplayCompositor --no-sandbox
"@
    
    try {
        $enhancedQtConf | Set-Content "qt.conf" -Encoding UTF8
        Write-Host "  ✓ Enhanced qt.conf created with MSIX compatibility settings" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Could not create enhanced qt.conf: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Fix 2: Create WebEngine environment script
    $webEngineScript = @"
@echo off
REM WebEngine MSIX Compatibility Launcher
set QT_WEBENGINE_DISABLE_SANDBOX=1
set QTWEBENGINE_CHROMIUM_FLAGS=--no-sandbox --disable-web-security --allow-file-access-from-files
set QT_WEBENGINE_DEBUG_CHROMIUM_FLAGS=--no-sandbox
start "" "%~dp0kiwix-desktop.exe" %*
"@
    
    try {
        $webEngineScript | Set-Content "launch-kiwix.bat" -Encoding ASCII
        Write-Host "  ✓ Created WebEngine compatibility launcher" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Could not create launcher: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Fix 3: Create PowerShell launcher with environment
    $psLauncher = @"
# WebEngine MSIX Launcher
`$env:QT_WEBENGINE_DISABLE_SANDBOX = "1"
`$env:QTWEBENGINE_CHROMIUM_FLAGS = "--no-sandbox --disable-web-security --allow-file-access-from-files"
`$env:QT_WEBENGINE_DEBUG_CHROMIUM_FLAGS = "--no-sandbox"

# Set working directory to package location
Set-Location (Split-Path -Parent `$MyInvocation.MyCommand.Path)

# Launch application
Start-Process -FilePath ".\kiwix-desktop.exe" -ArgumentList `$args -WorkingDirectory (Get-Location)
"@
    
    try {
        $psLauncher | Set-Content "launch-kiwix.ps1" -Encoding UTF8
        Write-Host "  ✓ Created PowerShell WebEngine launcher" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Could not create PowerShell launcher: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. Final recommendations
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan

if (-not (Test-Path "QtWebEngineProcess.exe")) {
    Write-Host "CRITICAL: QtWebEngineProcess.exe is missing" -ForegroundColor Red
    Write-Host "  → This is required for Qt WebEngine to function" -ForegroundColor Yellow
    Write-Host "  → Rebuild MSIX package with complete Qt6 WebEngine components" -ForegroundColor Yellow
}

if (-not (Test-Path "resources/qtwebengine_resources.pak")) {
    Write-Host "CRITICAL: WebEngine resources missing" -ForegroundColor Red
    Write-Host "  → Qt WebEngine requires resource files (.pak files)" -ForegroundColor Yellow
    Write-Host "  → Copy resources directory from Qt6 installation" -ForegroundColor Yellow
}

Write-Host "`nTo test the fixes:" -ForegroundColor Green
Write-Host "  1. Run: .\launch-kiwix.ps1" -ForegroundColor Gray
Write-Host "  2. Or: .\launch-kiwix.bat" -ForegroundColor Gray
Write-Host "  3. Check Windows Event Viewer for detailed errors" -ForegroundColor Gray

Write-Host "`nIf issues persist:" -ForegroundColor Yellow
Write-Host "  → Qt WebEngine may not be fully compatible with MSIX sandboxing" -ForegroundColor Gray
Write-Host "  → Consider building with Qt6 WebKit instead of WebEngine" -ForegroundColor Gray
Write-Host "  → Or use side-loading instead of Microsoft Store distribution" -ForegroundColor Gray

Pop-Location

Write-Host "`n=== WEBENGINE ANALYSIS COMPLETE ===" -ForegroundColor Cyan