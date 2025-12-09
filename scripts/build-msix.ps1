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

    # Copy Qt DLLs and dependencies
    $QtBinPath = $null

    # Try different Qt path detection methods
    if (-not [string]::IsNullOrEmpty($env:QT_ROOT_DIR)) {
        $QtBinPath = Join-Path $env:QT_ROOT_DIR "bin"
    } elseif (-not [string]::IsNullOrEmpty($env:Qt5_Dir)) {
        $QtBinPath = Join-Path $env:Qt5_Dir "bin"
    } else {
        # Try to find Qt installation in GitHub Actions environment
        $possiblePaths = @(
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
    $QtLibs = @(
        "Qt5Core.dll",
        "Qt5Gui.dll", 
        "Qt5Widgets.dll",
        "Qt5Network.dll",
        "Qt5WebEngine.dll",
        "Qt5WebEngineCore.dll",
        "Qt5WebEngineWidgets.dll",
        "Qt5WebChannel.dll",
        "Qt5PrintSupport.dll",
        "Qt5Positioning.dll",
        "Qt5Quick.dll",
        "Qt5QuickWidgets.dll",
        "Qt5Qml.dll",
        "Qt5QmlModels.dll",
        "Qt5TextToSpeech.dll"
    )    $copiedLibs = 0
    if ($QtBinPath -and (Test-Path $QtBinPath)) {
        foreach ($lib in $QtLibs) {
            $libPath = Join-Path $QtBinPath $lib
            if (Test-Path $libPath) {
                Copy-Item $libPath $StagingDir -Force
                Write-Host "  Copied $lib" -ForegroundColor Gray
                $copiedLibs++
            } else {
                Write-Host "  Skipping $lib (not found)" -ForegroundColor DarkGray
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

    # Copy Qt platforms plugin
    if ($QtBinPath -and (Test-Path $QtBinPath)) {
        $PlatformsDir = Join-Path $StagingDir "platforms"
        New-Item -ItemType Directory -Path $PlatformsDir -Force | Out-Null
        $QtPlatformsPath = Join-Path (Split-Path $QtBinPath) "plugins\platforms"
        if (Test-Path $QtPlatformsPath) {
            $qwindowsDll = Join-Path $QtPlatformsPath "qwindows.dll"
            if (Test-Path $qwindowsDll) {
                Copy-Item $qwindowsDll $PlatformsDir -Force
                Write-Host "  Copied Qt platforms plugin" -ForegroundColor Gray
            }
        }

        # Copy other Qt plugins
        $PluginDirs = @("imageformats", "iconengines", "styles")
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
    }

    # Copy VC++ Redistributables if available
    $VCRedistPath = Join-Path $BuildPath "vcruntime*.dll"
    Get-ChildItem $VCRedistPath -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName $StagingDir -Force
        Write-Host "  Copied VC++ runtime: $($_.Name)" -ForegroundColor Gray
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
