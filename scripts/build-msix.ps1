# PowerShell script to build MSIX package for Kiwix Desktop
param(
    [Parameter(Mandatory=$true)]
    [string]$BuildPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [string]$Version = "2.4.1.0",

    [string]$Architecture = "x64"
)

$ErrorActionPreference = "Stop"

Write-Host "Building Kiwix Desktop MSIX package..." -ForegroundColor Green
Write-Host "Build Path: $BuildPath" -ForegroundColor Cyan
Write-Host "Output Path: $OutputPath" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Architecture: $Architecture" -ForegroundColor Cyan

# Create staging directory
$StagingDir = Join-Path $env:TEMP "KiwixMSIXStaging"
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

Write-Host "Created staging directory: $StagingDir" -ForegroundColor Yellow

try {
    # Copy application files directly to staging directory (package root)
    # MSIX expects the executable in the package root, not in a subdirectory

    # Copy the main executable to package root
    $ExePath = Join-Path $BuildPath "release\kiwix-desktop.exe"
    if (-not (Test-Path $ExePath)) {
        throw "Executable not found at: $ExePath"
    }
    Copy-Item $ExePath $StagingDir -Force
    Write-Host "Copied main executable" -ForegroundColor Yellow

    # Copy the wrapper script for better Qt environment setup
    # Note: MSIX doesn't support .bat entry points, but we'll include it for reference
    $WrapperScript = Join-Path $PSScriptRoot "kiwix-desktop-wrapper.bat"
    if (Test-Path $WrapperScript) {
        Copy-Item $WrapperScript $StagingDir -Force
        Write-Host "Copied wrapper script (for reference)" -ForegroundColor Gray
    }

    # Copy Qt diagnostics tool for troubleshooting
    $DiagnosticsScript = Join-Path $PSScriptRoot "qt-diagnostics.bat"
    if (Test-Path $DiagnosticsScript) {
        Copy-Item $DiagnosticsScript $StagingDir -Force
        Write-Host "Copied Qt diagnostics (batch)" -ForegroundColor Gray
    }

    # Copy PowerShell diagnostics tool (better for MSIX environment)
    $DiagnosticsPowerShell = Join-Path $PSScriptRoot "qt-diagnostics.ps1"
    if (Test-Path $DiagnosticsPowerShell) {
        Copy-Item $DiagnosticsPowerShell $StagingDir -Force
        Write-Host "Copied Qt diagnostics (PowerShell)" -ForegroundColor Gray
    }

    # Copy MSIX debugging helper
    $DebugHelper = Join-Path $PSScriptRoot "debug-msix-app.ps1"
    if (Test-Path $DebugHelper) {
        Copy-Item $DebugHelper $StagingDir -Force
        Write-Host "Copied MSIX debugging helper" -ForegroundColor Gray
    }

    # Create qt.conf to help Qt find plugins in MSIX package
    $QtConfContent = @"
[Paths]
Plugins = .
Imports = qml
Qml2Imports = qml
Binaries = .
Data = .
Translations = .

[Platforms]
WindowsArguments = platforms

[WebEngine]
LocalesPath = locales
ResourcesPath = resources
BrowserSubprocessPath = QtWebEngineProcess.exe
"@
    $QtConfPath = Join-Path $StagingDir "qt.conf"
    Set-Content -Path $QtConfPath -Value $QtConfContent -Encoding UTF8
    Write-Host "Created enhanced qt.conf for Qt and WebEngine" -ForegroundColor Yellow

    # Copy Qt DLLs and dependencies
    $QtBinPath = $null

    # Try different Qt path detection methods
    if (-not [string]::IsNullOrEmpty($env:QT_ROOT_DIR)) {
        $QtBinPath = Join-Path $env:QT_ROOT_DIR "bin"
    } elseif (-not [string]::IsNullOrEmpty($env:Qt6_Dir)) {
        $QtBinPath = Join-Path $env:Qt6_Dir "bin"
    } elseif (-not [string]::IsNullOrEmpty($env:Qt5_Dir)) {
        $QtBinPath = Join-Path $env:Qt5_Dir "bin"
    } else {
        # Try to find Qt installation in GitHub Actions environment
        $possiblePaths = @(
            "D:\a\kiwix-desktop\Qt\6.8.1\msvc2022_64\bin",
            "C:\Qt\6.8.1\msvc2022_64\bin",
            "${env:RUNNER_WORKSPACE}\Qt\6.8.1\msvc2022_64\bin",
            "D:\a\kiwix-desktop\Qt\5.15.2\msvc2019_64\bin",
            "C:\Qt\5.15.2\msvc2019_64\bin",
            "${env:RUNNER_WORKSPACE}\Qt\5.15.2\msvc2019_64\bin"
        )

        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $QtBinPath = $path
                break
            }
        }
    }

    if (-not $QtBinPath -or -not (Test-Path $QtBinPath)) {
        Write-Warning "Qt bin path not found. Trying to locate qmake..."
        try {
            $qmakePath = Get-Command qmake -ErrorAction Stop
            $QtBinPath = Split-Path $qmakePath.Source
        } catch {
            Write-Warning "Could not locate Qt installation. Qt libraries will not be copied."
        }
    }

    Write-Host "Looking for Qt libraries in: $QtBinPath" -ForegroundColor Yellow

    # Required Qt libraries for kiwix-desktop
        # Detect Qt version based on available DLLs
    $QtVersion = 5
    if ($QtBinPath -and (Test-Path (Join-Path $QtBinPath "Qt6Core.dll"))) {
        $QtVersion = 6
        Write-Host "Detected Qt6 installation" -ForegroundColor Green
    } elseif ($QtBinPath -and (Test-Path (Join-Path $QtBinPath "Qt5Core.dll"))) {
        $QtVersion = 5
        Write-Host "Detected Qt5 installation" -ForegroundColor Yellow
    }

    # Essential Qt DLLs for a Qt WebEngine application
    if ($QtVersion -eq 6) {
        $RequiredQtDlls = @(
            "Qt6Core.dll", "Qt6Gui.dll", "Qt6Widgets.dll", "Qt6Network.dll",
            "Qt6WebEngineCore.dll", "Qt6WebEngineWidgets.dll", "Qt6WebEngineQuick.dll",
            "Qt6Quick.dll", "Qt6QuickWidgets.dll", "Qt6Qml.dll", "Qt6QmlModels.dll",
            "Qt6Positioning.dll", "Qt6PrintSupport.dll", "Qt6Sql.dll", "Qt6Svg.dll",
            "Qt6TextToSpeech.dll", "Qt6Multimedia.dll", "Qt6MultimediaWidgets.dll",
            "Qt6OpenGL.dll", "Qt6Concurrent.dll", "Qt6WebChannel.dll"
        )

        # Additional Qt6 support DLLs that might be needed
        $OptionalQtDlls = @(
            "Qt6DBus.dll", "Qt6Designer.dll", "Qt6Help.dll", "Qt6Location.dll",
            "Qt6Sensors.dll", "Qt6SerialPort.dll", "Qt6WebSockets.dll",
            "Qt6Xml.dll", "Qt6QmlWorkerScript.dll", "Qt6QmlLocalStorage.dll",
            "libEGL.dll", "libGLESv2.dll", "d3dcompiler_47.dll", "opengl32sw.dll"
        )
    } else {
        $RequiredQtDlls = @(
            "Qt5Core.dll", "Qt5Gui.dll", "Qt5Widgets.dll", "Qt5Network.dll",
            "Qt5WebEngine.dll", "Qt5WebEngineCore.dll", "Qt5WebEngineWidgets.dll",
            "Qt5Quick.dll", "Qt5QuickWidgets.dll", "Qt5Qml.dll", "Qt5QmlModels.dll",
            "Qt5Positioning.dll", "Qt5PrintSupport.dll", "Qt5Sql.dll", "Qt5Svg.dll",
            "Qt5TextToSpeech.dll", "Qt5Multimedia.dll", "Qt5MultimediaWidgets.dll",
            "Qt5OpenGL.dll", "Qt5WinExtras.dll", "Qt5Concurrent.dll", "Qt5Test.dll"
        )

        # Additional Qt5 support DLLs that might be needed
        $OptionalQtDlls = @(
            "Qt5DBus.dll", "Qt5Designer.dll", "Qt5Help.dll", "Qt5Location.dll",
            "Qt5Sensors.dll", "Qt5SerialPort.dll", "Qt5WebChannel.dll", "Qt5WebSockets.dll",
            "Qt5Xml.dll", "Qt5XmlPatterns.dll", "libEGL.dll", "libGLESV2.dll",
            "d3dcompiler_47.dll", "opengl32sw.dll"
        )
    }

    # Combine all Qt DLLs for copying
    $QtLibs = $RequiredQtDlls + $OptionalQtDlls

    $copiedLibs = 0
    if ($QtBinPath -and (Test-Path $QtBinPath)) {
        Write-Host "Found Qt installation at: $QtBinPath" -ForegroundColor Green
        foreach ($lib in $QtLibs) {
            $libPath = Join-Path $QtBinPath $lib
            if (Test-Path $libPath) {
                Copy-Item $libPath $StagingDir -Force
                if ($RequiredQtDlls -contains $lib) {
                    Write-Host "  Copied required: $lib" -ForegroundColor Green
                } else {
                    Write-Host "  Copied optional: $lib" -ForegroundColor Gray
                }
                $copiedLibs++
            } else {
                if ($RequiredQtDlls -contains $lib) {
                    Write-Host "  WARNING: Missing required Qt library: $lib" -ForegroundColor Yellow
                } else {
                    Write-Host "  Skipping optional: $lib (not found)" -ForegroundColor DarkGray
                }
            }
        }

        if ($copiedLibs -eq 0) {
            Write-Warning "No Qt libraries found. The application may not run without Qt dependencies."
        } else {
            Write-Host "  Copied $copiedLibs Qt libraries" -ForegroundColor Green
        }
    } else {
        Write-Warning "Qt binary path not accessible: $QtBinPath"
    }

    # Copy Qt platforms plugin (CRITICAL for Qt applications)
    if ($QtBinPath -and (Test-Path $QtBinPath)) {
        $PlatformsDir = Join-Path $StagingDir "platforms"
        New-Item -ItemType Directory -Path $PlatformsDir -Force | Out-Null
        $QtPlatformsPath = Join-Path (Split-Path $QtBinPath) "plugins\platforms"
        if (Test-Path $QtPlatformsPath) {
            # Copy all platform plugins, not just qwindows.dll
            Get-ChildItem $QtPlatformsPath -Filter "*.dll" | ForEach-Object {
                Copy-Item $_.FullName $PlatformsDir -Force
                if ($_.Name -eq "qwindows.dll") {
                    Write-Host "  Copied CRITICAL platform plugin: $($_.Name)" -ForegroundColor Green
                } else {
                    Write-Host "  Copied platform plugin: $($_.Name)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  ERROR: Qt platforms plugin directory not found at: $QtPlatformsPath" -ForegroundColor Red
        }

        # Copy other Qt plugins
        $PluginDirs = @("imageformats", "iconengines", "styles", "bearer", "audio", "mediaservice", "playlistformats")
        foreach ($pluginDir in $PluginDirs) {
            $SourcePluginDir = Join-Path (Split-Path $QtBinPath) "plugins\$pluginDir"
            if (Test-Path $SourcePluginDir) {
                $DestPluginDir = Join-Path $StagingDir $pluginDir
                New-Item -ItemType Directory -Path $DestPluginDir -Force | Out-Null
                $pluginFiles = Get-ChildItem $SourcePluginDir -Filter "*.dll" -ErrorAction SilentlyContinue
                if ($pluginFiles) {
                    $pluginFiles | ForEach-Object { Copy-Item $_.FullName $DestPluginDir -Force }
                    Write-Host "  Copied Qt $pluginDir plugins ($($pluginFiles.Count) files)" -ForegroundColor Gray
                }
            }
        }

        # Copy Qt WebEngine support files (resources and locales)
        $QtWebEngineDir = Join-Path (Split-Path $QtBinPath) "resources"
        if (Test-Path $QtWebEngineDir) {
            $DestWebEngineDir = Join-Path $StagingDir "resources"
            New-Item -ItemType Directory -Path $DestWebEngineDir -Force | Out-Null
            Get-ChildItem $QtWebEngineDir -File -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName $DestWebEngineDir -Force
                Write-Host "  Copied WebEngine resource: $($_.Name)" -ForegroundColor Gray
            }
        }

        # Copy Qt WebEngine locales directory
        $QtLocalesDir = Join-Path (Split-Path $QtBinPath) "translations\qtwebengine_locales"
        if (-not (Test-Path $QtLocalesDir)) {
            # Try alternative location
            $QtLocalesDir = Join-Path (Split-Path $QtBinPath) "resources\locales"
        }
        if (Test-Path $QtLocalesDir) {
            $DestLocalesDir = Join-Path $StagingDir "locales"
            New-Item -ItemType Directory -Path $DestLocalesDir -Force | Out-Null
            Get-ChildItem $QtLocalesDir -File "*.pak" -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName $DestLocalesDir -Force
                Write-Host "  Copied WebEngine locale: $($_.Name)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  WARNING: Qt WebEngine locales directory not found" -ForegroundColor Yellow
        }

        # Copy QtWebEngineProcess.exe - try multiple locations
        $QtWebEngineProcessLocations = @(
            (Join-Path (Split-Path $QtBinPath) "QtWebEngineProcess.exe"),
            (Join-Path $QtBinPath "QtWebEngineProcess.exe"),
            (Join-Path (Split-Path (Split-Path $QtBinPath)) "bin\QtWebEngineProcess.exe")
        )

        $QtWebEngineProcessFound = $false
        foreach ($location in $QtWebEngineProcessLocations) {
            if (Test-Path $location) {
                Copy-Item $location $StagingDir -Force
                Write-Host "  Copied QtWebEngineProcess.exe from: $location" -ForegroundColor Green
                $QtWebEngineProcessFound = $true
                break
            }
        }

        if (-not $QtWebEngineProcessFound) {
            Write-Host "  WARNING: QtWebEngineProcess.exe not found - WebEngine will fail" -ForegroundColor Red
        }
    }

    # Copy VC++ Redistributables if available
    $VCRedistPath = Join-Path $BuildPath "vcruntime*.dll"
    Get-ChildItem $VCRedistPath -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName $StagingDir -Force
        Write-Host "  Copied VC++ runtime: $($_.Name)" -ForegroundColor Gray
    }

    # Also look for additional VC++ redistributable DLLs
    $AdditionalVCLibs = @("MSVCP140.dll", "MSVCP140_1.dll", "VCRUNTIME140.dll", "VCRUNTIME140_1.dll", "api-ms-win-crt-*.dll")
    foreach ($pattern in $AdditionalVCLibs) {
        # Try to find in system directories or Qt installation
        $systemPaths = @(
            "${env:WINDIR}\System32",
            "${env:WINDIR}\SysWOW64",
            $(if ($QtBinPath) { Split-Path $QtBinPath }),
            $(if ($QtBinPath) { $QtBinPath })
        )

        foreach ($sysPath in $systemPaths) {
            if ($sysPath -and (Test-Path $sysPath)) {
                Get-ChildItem (Join-Path $sysPath $pattern) -ErrorAction SilentlyContinue | ForEach-Object {
                    $destPath = Join-Path $StagingDir $_.Name
                    if (-not (Test-Path $destPath)) {
                        Copy-Item $_.FullName $destPath -Force
                        Write-Host "  Copied VC++ redistributable: $($_.Name)" -ForegroundColor Gray
                    }
                }
            }
        }
    }

    # Copy kiwix libraries from the build
    $KiwixLibPath = Join-Path $BuildPath "BUILD_win-amd64\INSTALL\bin"
    if (Test-Path $KiwixLibPath) {
        Get-ChildItem (Join-Path $KiwixLibPath "*.dll") -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName $StagingDir -Force
            Write-Host "  Copied Kiwix library: $($_.Name)" -ForegroundColor Gray
        }
    }

    # Create Assets directory and copy icons
    $AssetsDir = Join-Path $StagingDir "Assets"
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null

    # Try to find the best icon source
    $BaseDir = Split-Path $PSScriptRoot
    $IconSources = @(
        (Join-Path $BaseDir "resources\icons\kiwix\512\kiwix-desktop.png"),
        (Join-Path $BaseDir "resources\icons\kiwix\256\kiwix-desktop.png"),
        (Join-Path $BaseDir "resources\icons\kiwix\128\kiwix-desktop.png"),
        (Join-Path $BaseDir "resources\icons\kiwix\app_icon.ico")
    )

    $BestIcon = $null
    foreach ($source in $IconSources) {
        if (Test-Path $source) {
            $BestIcon = $source
            break
        }
    }

    # Required MSIX assets
    $RequiredAssets = @(
        "StoreLogo.png",
        "Square150x150Logo.png",
        "Square44x44Logo.png",
        "Wide310x150Logo.png",
        "LargeTile.png",
        "SmallTile.png",
        "SplashScreen.png",
        "ZimFileIcon.png"
    )

    if ($BestIcon) {
        Write-Host "Using icon source: $BestIcon" -ForegroundColor Yellow
        foreach ($asset in $RequiredAssets) {
            $assetPath = Join-Path $AssetsDir $asset
            Copy-Item $BestIcon $assetPath -Force
            Write-Host "  Created $asset" -ForegroundColor Gray
        }
        Write-Host "Copied icon assets" -ForegroundColor Yellow
    } else {
        Write-Warning "No suitable icon source found. Creating minimal placeholder assets."
        # Create minimal placeholder PNG files (1x1 pixel transparent)
        $placeholderContent = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
        foreach ($asset in $RequiredAssets) {
            $assetPath = Join-Path $AssetsDir $asset
            [IO.File]::WriteAllBytes($assetPath, $placeholderContent)
            Write-Host "  Created placeholder $asset" -ForegroundColor DarkGray
        }
    }

    # Copy the manifest file
    $ManifestSource = Join-Path (Split-Path $PSScriptRoot) "Package.appxmanifest"
    $ManifestDest = Join-Path $StagingDir "AppxManifest.xml"
    Copy-Item $ManifestSource $ManifestDest -Force

    # Update version in manifest if different
    if ($Version -ne "2.4.1.0") {
        $manifestContent = Get-Content $ManifestDest -Raw
        $manifestContent = $manifestContent -replace 'Version="2\.4\.1\.0"', "Version=`"$Version`""
        Set-Content $ManifestDest $manifestContent -Encoding UTF8
    }

    Write-Host "Copied application manifest" -ForegroundColor Yellow

    # Create the MSIX package
    Write-Host "Creating MSIX package..." -ForegroundColor Green

    # Ensure output directory exists
    $OutputDir = Split-Path $OutputPath
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Use MakeAppx.exe to create the package
    $MakeAppxPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\makeappx.exe"
    if (-not (Test-Path $MakeAppxPath)) {
        # Try to find MakeAppx.exe in Windows SDK
        $WindowsKitsPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
        $MakeAppxPath = Get-ChildItem -Path $WindowsKitsPath -Recurse -Filter "makeappx.exe" |
                       Where-Object { $_.Directory.Name -like "*x64*" } |
                       Sort-Object Name -Descending |
                       Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $MakeAppxPath -or -not (Test-Path $MakeAppxPath)) {
        throw "MakeAppx.exe not found. Please install Windows 10/11 SDK."
    }

    Write-Host "Using MakeAppx: $MakeAppxPath" -ForegroundColor Cyan

    $MakeAppxArgs = @(
        "pack",
        "/d", $StagingDir,
        "/p", $OutputPath,
        "/l"  # Enable file logging
    )

    Write-Host "Running: $MakeAppxPath $($MakeAppxArgs -join ' ')" -ForegroundColor Cyan
    & $MakeAppxPath $MakeAppxArgs

    if ($LASTEXITCODE -ne 0) {
        throw "MakeAppx failed with exit code: $LASTEXITCODE"
    }

    Write-Host "MSIX package created successfully: $OutputPath" -ForegroundColor Green

    # Display package information
    if (Test-Path $OutputPath) {
        $FileInfo = Get-Item $OutputPath
        Write-Host "Package size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    }

} finally {
    # Cleanup staging directory
    if (Test-Path $StagingDir) {
        Remove-Item $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up staging directory" -ForegroundColor Yellow
    }
}

Write-Host "MSIX build completed!" -ForegroundColor Green
