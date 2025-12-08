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
    # Copy application files
    $AppDir = Join-Path $StagingDir "App"
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

    # Copy the main executable
    $ExePath = Join-Path $BuildPath "release\kiwix-desktop.exe"
    if (-not (Test-Path $ExePath)) {
        throw "Executable not found at: $ExePath"
    }
    Copy-Item $ExePath $AppDir -Force
    Write-Host "Copied main executable" -ForegroundColor Yellow

    # Copy Qt DLLs and dependencies
    $QtBinPath = $env:QT_ROOT_DIR
    if ([string]::IsNullOrEmpty($QtBinPath)) {
        $QtBinPath = "${env:Qt5_Dir}\bin"
    }
    if ([string]::IsNullOrEmpty($QtBinPath)) {
        $QtBinPath = "C:\Qt\5.15.2\msvc2019_64\bin"
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
        "Qt5QmlModels.dll"
    )

    foreach ($lib in $QtLibs) {
        $libPath = Join-Path $QtBinPath $lib
        if (Test-Path $libPath) {
            Copy-Item $libPath $AppDir -Force
            Write-Host "  Copied $lib" -ForegroundColor Gray
        } else {
            Write-Warning "Qt library not found: $libPath"
        }
    }

    # Copy Qt platforms plugin
    $PlatformsDir = Join-Path $AppDir "platforms"
    New-Item -ItemType Directory -Path $PlatformsDir -Force | Out-Null
    $QtPlatformsPath = Join-Path $QtBinPath "..\plugins\platforms"
    if (Test-Path $QtPlatformsPath) {
        Copy-Item (Join-Path $QtPlatformsPath "qwindows.dll") $PlatformsDir -Force -ErrorAction SilentlyContinue
        Write-Host "  Copied Qt platforms plugin" -ForegroundColor Gray
    }

    # Copy other Qt plugins
    $PluginDirs = @("imageformats", "iconengines", "styles")
    foreach ($pluginDir in $PluginDirs) {
        $SourcePluginDir = Join-Path $QtBinPath "..\plugins\$pluginDir"
        if (Test-Path $SourcePluginDir) {
            $DestPluginDir = Join-Path $AppDir $pluginDir
            New-Item -ItemType Directory -Path $DestPluginDir -Force | Out-Null
            Copy-Item (Join-Path $SourcePluginDir "*") $DestPluginDir -Force -ErrorAction SilentlyContinue
            Write-Host "  Copied Qt $pluginDir plugins" -ForegroundColor Gray
        }
    }

    # Copy VC++ Redistributables if available
    $VCRedistPath = Join-Path $BuildPath "vcruntime*.dll"
    Get-ChildItem $VCRedistPath -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item $_.FullName $AppDir -Force
        Write-Host "  Copied VC++ runtime: $($_.Name)" -ForegroundColor Gray
    }

    # Copy kiwix libraries from the build
    $KiwixLibPath = Join-Path $BuildPath "BUILD_win-amd64\INSTALL\bin"
    if (Test-Path $KiwixLibPath) {
        Get-ChildItem (Join-Path $KiwixLibPath "*.dll") -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName $AppDir -Force
            Write-Host "  Copied Kiwix library: $($_.Name)" -ForegroundColor Gray
        }
    }

    # Create Assets directory and copy icons
    $AssetsDir = Join-Path $StagingDir "Assets"
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null

    # Copy and convert icons for MSIX package
    $IconSourcePath = Join-Path (Split-Path $PSScriptRoot) "resources\icons\kiwix\app_icon.ico"
    $Icon512Path = Join-Path (Split-Path $PSScriptRoot) "resources\icons\kiwix\512\kiwix-desktop.png"

    # For this example, we'll create placeholder assets
    # In a production setup, you'd want to create proper sized icons
    if (Test-Path $IconSourcePath) {
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "StoreLogo.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "Square150x150Logo.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "Square44x44Logo.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "Wide310x150Logo.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "LargeTile.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "SmallTile.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "SplashScreen.png") -Force
        Copy-Item $IconSourcePath (Join-Path $AssetsDir "ZimFileIcon.png") -Force
        Write-Host "Copied icon assets" -ForegroundColor Yellow
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
