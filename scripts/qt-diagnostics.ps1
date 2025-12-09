# Qt MSIX Diagnostics PowerShell Script
# This script helps diagnose Qt-related issues in the MSIX package

Write-Host ""
Write-Host "=== Qt MSIX Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Show current directory and key files
Write-Host "Current directory: $PWD" -ForegroundColor Yellow
Write-Host ""

Write-Host "Checking for key Qt files:" -ForegroundColor White

# Check essential Qt DLLs - try both Qt5 and Qt6
$qt5Files = @(
    "Qt5Core.dll",
    "Qt5Gui.dll",
    "Qt5Widgets.dll",
    "Qt5WebEngine.dll",
    "Qt5WebEngineCore.dll",
    "Qt5WebEngineWidgets.dll"
)

$qt6Files = @(
    "Qt6Core.dll",
    "Qt6Gui.dll",
    "Qt6Widgets.dll",
    "Qt6WebEngineCore.dll",
    "Qt6WebEngineWidgets.dll",
    "Qt6QmlMeta.dll"
)

$essentialFiles = @("kiwix-desktop.exe")

# Detect Qt version
$qtVersion = "Unknown"
$qtFiles = @()
if (Test-Path "Qt6Core.dll") {
    $qtVersion = "Qt6"
    $qtFiles = $qt6Files
    Write-Host "Detected Qt6 installation" -ForegroundColor Green
} elseif (Test-Path "Qt5Core.dll") {
    $qtVersion = "Qt5"
    $qtFiles = $qt5Files
    Write-Host "Detected Qt5 installation" -ForegroundColor Yellow
} else {
    Write-Host "No Qt installation detected" -ForegroundColor Red
}

$allEssentialFiles = $qtFiles + $essentialFiles

foreach ($file in $allEssentialFiles) {
    if (Test-Path $file) {
        if ($file -eq "kiwix-desktop.exe") {
            Write-Host "  [OK] $file found" -ForegroundColor Green
        } else {
            Write-Host "  [OK] $file found" -ForegroundColor Green
        }
    } else {
        if ($file -eq "Qt5Core.dll") {
            Write-Host "  [CRITICAL] $file NOT found - this will cause startup failure" -ForegroundColor Red
        } elseif ($file -eq "kiwix-desktop.exe") {
            Write-Host "  [CRITICAL] $file NOT found - main executable missing" -ForegroundColor Red
        } else {
            Write-Host "  [FAIL] $file NOT found" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Checking Qt configuration files:" -ForegroundColor White

if (Test-Path "qt.conf") {
    Write-Host "  [OK] qt.conf found" -ForegroundColor Green
    Write-Host "  Contents:" -ForegroundColor Gray
    Get-Content "qt.conf" | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  [FAIL] qt.conf NOT found - Qt may not find its plugins" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking for Qt platforms plugin:" -ForegroundColor White

if (Test-Path "platforms\qwindows.dll") {
    Write-Host "  [OK] platforms\qwindows.dll found" -ForegroundColor Green
} else {
    Write-Host "  [CRITICAL] platforms\qwindows.dll NOT found - Qt GUI will fail to initialize" -ForegroundColor Red
}

Write-Host ""
Write-Host "Platform plugins directory contents:" -ForegroundColor White

if (Test-Path "platforms") {
    $platformPlugins = Get-ChildItem "platforms\*.dll" -ErrorAction SilentlyContinue
    if ($platformPlugins) {
        foreach ($plugin in $platformPlugins) {
            Write-Host "  Found: $($plugin.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [WARN] No platform plugins found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL] platforms directory does not exist" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking Qt WebEngine support files:" -ForegroundColor White

$webEngineFiles = @(
    "QtWebEngineProcess.exe",
    "resources\qtwebengine_resources.pak",
    "resources\qtwebengine_devtools_resources.pak",
    "resources\qtwebengine_resources_100p.pak",
    "resources\qtwebengine_resources_200p.pak"
)

foreach ($webFile in $webEngineFiles) {
    if (Test-Path $webFile) {
        Write-Host "  [OK] $webFile found" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $webFile NOT found - may cause WebEngine issues" -ForegroundColor Yellow
    }
}

# Check for Qt WebEngine locales
if (Test-Path "locales") {
    $localeFiles = Get-ChildItem "locales\*.pak" -ErrorAction SilentlyContinue
    if ($localeFiles) {
        Write-Host "  [OK] WebEngine locales found ($($localeFiles.Count) files)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] No WebEngine locale files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARN] locales directory not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking Visual C++ Runtime files:" -ForegroundColor White

$vcRedistFiles = @(
    "MSVCP140.dll",
    "MSVCP140_1.dll",
    "MSVCP140_2.dll",
    "VCRUNTIME140.dll",
    "VCRUNTIME140_1.dll"
)

foreach ($vcFile in $vcRedistFiles) {
    if (Test-Path $vcFile) {
        Write-Host "  [OK] $vcFile found" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $vcFile NOT found - may cause runtime issues" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Environment variables that might affect Qt:" -ForegroundColor White
Write-Host "  QT_PLUGIN_PATH=$env:QT_PLUGIN_PATH" -ForegroundColor Gray
Write-Host "  QT_QPA_PLATFORM_PLUGIN_PATH=$env:QT_QPA_PLATFORM_PLUGIN_PATH" -ForegroundColor Gray

Write-Host ""
Write-Host "Attempting to get file version info:" -ForegroundColor White

try {
    $qtCoreFile = if (Test-Path "Qt6Core.dll") { "Qt6Core.dll" } elseif (Test-Path "Qt5Core.dll") { "Qt5Core.dll" } else { $null }

    if ($qtCoreFile) {
        $qtCoreVersion = (Get-ItemProperty $qtCoreFile).VersionInfo
        Write-Host "  $qtCoreFile version: $($qtCoreVersion.FileVersion)" -ForegroundColor Gray
    }

    if (Test-Path "kiwix-desktop.exe") {
        $appVersion = (Get-ItemProperty "kiwix-desktop.exe").VersionInfo
        Write-Host "  kiwix-desktop.exe version: $($appVersion.FileVersion)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  [WARN] Could not retrieve version information" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "=== Diagnostics complete ===" -ForegroundColor Cyan
Write-Host ""

# Summary
$criticalIssues = 0
if ($qtVersion -eq "Unknown") {
    $criticalIssues++
} elseif ($qtVersion -eq "Qt6" -and -not (Test-Path "Qt6Core.dll")) {
    $criticalIssues++
} elseif ($qtVersion -eq "Qt5" -and -not (Test-Path "Qt5Core.dll")) {
    $criticalIssues++
}
if (-not (Test-Path "platforms\qwindows.dll")) { $criticalIssues++ }
if (-not (Test-Path "kiwix-desktop.exe")) { $criticalIssues++ }

Write-Host "Qt Version: $qtVersion" -ForegroundColor Cyan

if ($criticalIssues -eq 0) {
    Write-Host "SUMMARY: No critical issues detected. Application should be able to start." -ForegroundColor Green
} else {
    Write-Host "SUMMARY: $criticalIssues critical issue(s) detected. Application will likely fail to start." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Troubleshooting Suggestions ===" -ForegroundColor Cyan

if ($criticalIssues -eq 0) {
    Write-Host "Since all files appear to be present, the crash might be due to:" -ForegroundColor Yellow
    Write-Host "1. Qt WebEngine sandbox restrictions in MSIX environment" -ForegroundColor White
    Write-Host "2. Missing environment variables or registry entries" -ForegroundColor White
    Write-Host "3. MSIX container limitations affecting Qt initialization" -ForegroundColor White
    Write-Host ""
    Write-Host "Try running the application with Qt debugging:" -ForegroundColor Yellow
    Write-Host '  $env:QT_DEBUG_PLUGINS=1; .\kiwix-desktop.exe' -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or with WebEngine debugging:" -ForegroundColor Yellow
    Write-Host '  $env:QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --no-sandbox"; .\kiwix-desktop.exe' -ForegroundColor Gray
    Write-Host ""
    Write-Host "If the crash persists, it may indicate a fundamental Qt/MSIX compatibility issue." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
