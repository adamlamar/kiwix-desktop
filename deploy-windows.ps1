# PowerShell script to deploy Kiwix Desktop for Windows with Qt6
param(
    [string]$BuildPath = "release",
    [string]$QtPath,
    [string]$OutputPath = "dist",
    [string]$DepsPath
)

# Set error action preference to stop on error, but allow some flexibility
$ErrorActionPreference = "Continue"

Write-Host "Starting Kiwix Desktop deployment process..." -ForegroundColor Green
Write-Host "Parameters:" -ForegroundColor Yellow
Write-Host "  BuildPath: $BuildPath"
Write-Host "  QtPath: $QtPath"
Write-Host "  OutputPath: $OutputPath"
Write-Host "  DepsPath: $DepsPath"

# Function to copy file with error handling
function Copy-FileWithCheck {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path $Source) {
        Write-Host "Copying: $Source -> $Destination"
        Copy-Item $Source $Destination -Force
    } else {
        Write-Warning "File not found: $Source"
    }
}

# Create output directory
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Copy main executable
$exeSource = Join-Path $BuildPath "kiwix-desktop.exe"
Write-Host "Looking for executable at: $exeSource" -ForegroundColor Yellow

if (Test-Path $exeSource) {
    Copy-Item $exeSource $OutputPath -Force
    Write-Host "Copied main executable: kiwix-desktop.exe" -ForegroundColor Green
} else {
    # Try alternative paths
    $altPaths = @(
        "kiwix-desktop.exe",
        "debug\kiwix-desktop.exe",
        "Release\kiwix-desktop.exe"
    )

    $found = $false
    foreach ($altPath in $altPaths) {
        if (Test-Path $altPath) {
            Write-Host "Found executable at alternative path: $altPath" -ForegroundColor Yellow
            Copy-Item $altPath $OutputPath -Force
            $found = $true
            break
        }
    }

    if (-not $found) {
        Write-Error "Main executable not found at: $exeSource or alternative locations"
        exit 1
    }
}

# Find Qt installation path if not provided
if (-not $QtPath -or -not (Test-Path $QtPath)) {
    Write-Host "Searching for Qt installation..." -ForegroundColor Yellow

    # Common Qt installation locations (updated with more paths)
    $qtSearchPaths = @(
        "${env:Qt6_DIR}",
        "${env:QT_ROOT_DIR}",
        "${env:QT_INSTALL_PATH}",
        "${env:RUNNER_WORKSPACE}\Qt\6.8.1\msvc2022_64",
        "${env:RUNNER_WORKSPACE}\Qt\6.8.0\msvc2022_64",
        "${env:RUNNER_WORKSPACE}\Qt\6.7.3\msvc2022_64",
        "C:\Qt\6.8.1\msvc2022_64",
        "C:\Qt\6.8.0\msvc2022_64",
        "C:\Qt\6.7.3\msvc2022_64"
    )

    Write-Host "Checking Qt search paths:" -ForegroundColor Cyan
    foreach ($path in $qtSearchPaths) {
        Write-Host "  Checking: $path"
        if ($path -and (Test-Path "$path\bin\windeployqt.exe")) {
            $QtPath = $path
            Write-Host "✓ Found Qt at: $QtPath" -ForegroundColor Green
            break
        }
    }

    # If still not found, try to find Qt installations in common locations
    if (-not $QtPath) {
        Write-Host "Searching for Qt in common installation directories..." -ForegroundColor Yellow

        $searchRoots = @(
            "${env:RUNNER_WORKSPACE}\Qt",
            "C:\Qt"
        )

        foreach ($root in $searchRoots) {
            if (Test-Path $root) {
                Write-Host "Searching in: $root"
                $qtDirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "6\.\d+\.\d+" }
                foreach ($qtDir in $qtDirs) {
                    $msvcPath = Join-Path $qtDir.FullName "msvc2022_64"
                    if (Test-Path "$msvcPath\bin\windeployqt.exe") {
                        $QtPath = $msvcPath
                        Write-Host "✓ Found Qt at: $QtPath" -ForegroundColor Green
                        break
                    }
                }
                if ($QtPath) { break }
            }
        }
    }

    if (-not $QtPath) {
        Write-Error "Qt installation not found. Please specify QtPath parameter or ensure Qt is installed."
        exit 1
    }
}# Run windeployqt
$windeployqt = Join-Path $QtPath "bin\windeployqt.exe"
if (Test-Path $windeployqt) {
    $targetExe = Join-Path $OutputPath "kiwix-desktop.exe"
    Write-Host "Running windeployqt on: $targetExe" -ForegroundColor Yellow
    Write-Host "Using windeployqt: $windeployqt" -ForegroundColor Yellow

    $deployArgs = @(
        "--qmldir", ".",
        "--compiler-runtime",
        "--no-translations",
        "--no-system-d3d-compiler",
        "--no-opengl-sw",
        "--force",
        "--verbose", "2",
        $targetExe
    )

    Write-Host "windeployqt arguments: $($deployArgs -join ' ')" -ForegroundColor Cyan

    try {
        & $windeployqt @deployArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "windeployqt completed with exit code $LASTEXITCODE"
        } else {
            Write-Host "windeployqt completed successfully" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "windeployqt encountered an error: $($_.Exception.Message)"
        Write-Host "Continuing with manual deployment..." -ForegroundColor Yellow
    }
} else {
    Write-Error "windeployqt not found at: $windeployqt"
    exit 1
}# Copy additional dependencies from kiwix-build if available
if ($DepsPath -and (Test-Path $DepsPath)) {
    Write-Host "Copying additional dependencies from: $DepsPath"

    $libPath = Join-Path $DepsPath "lib"
    $binPath = Join-Path $DepsPath "bin"

    # Copy DLLs
    if (Test-Path $binPath) {
        Get-ChildItem -Path $binPath -Filter "*.dll" | ForEach-Object {
            Copy-FileWithCheck $_.FullName (Join-Path $OutputPath $_.Name)
        }
    }

    # Copy specific kiwix and zim libraries
    $requiredLibs = @(
        "kiwix*.dll",
        "zim*.dll",
        "pugixml*.dll",
        "xapian*.dll",
        "icu*.dll"
    )

    foreach ($pattern in $requiredLibs) {
        if (Test-Path $libPath) {
            Get-ChildItem -Path $libPath -Filter $pattern | ForEach-Object {
                Copy-FileWithCheck $_.FullName (Join-Path $OutputPath $_.Name)
            }
        }
        if (Test-Path $binPath) {
            Get-ChildItem -Path $binPath -Filter $pattern | ForEach-Object {
                Copy-FileWithCheck $_.FullName (Join-Path $OutputPath $_.Name)
            }
        }
    }
}

# Copy Visual C++ Redistributable (if available)
$vcredistPaths = @(
    "${env:VCToolsRedistDir}x64\Microsoft.VC143.CRT",
    "${env:VCINSTALLDIR}Redist\MSVC\*\x64\Microsoft.VC143.CRT"
)

foreach ($vcPath in $vcredistPaths) {
    if ($vcPath -and (Test-Path $vcPath)) {
        Write-Host "Copying Visual C++ Redistributable from: $vcPath"
        Get-ChildItem -Path $vcPath -Filter "*.dll" | ForEach-Object {
            Copy-FileWithCheck $_.FullName (Join-Path $OutputPath $_.Name)
        }
        break
    }
}

# Copy other important files
$additionalFiles = @(
    "LICENSE",
    "README.md",
    "COPYING",
    "debug-kiwix-desktop.ps1",
    "debug-kiwix-desktop.bat"
)

foreach ($file in $additionalFiles) {
    if (Test-Path $file) {
        Copy-Item $file $OutputPath -Force
        Write-Host "Copied: $file"
    }
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Output directory: $OutputPath" -ForegroundColor Cyan

# List deployed files
Write-Host "`nDeployed files:" -ForegroundColor Yellow
Get-ChildItem $OutputPath -Recurse | ForEach-Object {
    Write-Host "  $($_.FullName.Replace((Resolve-Path $OutputPath).Path, ''))"
}
