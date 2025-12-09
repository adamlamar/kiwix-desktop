# PowerShell script to deploy Kiwix Desktop for Windows with Qt6
param(
    [string]$BuildPath = "release",
    [string]$QtPath,
    [string]$OutputPath = "dist",
    [string]$DepsPath
)

# Set error action preference to stop on error
$ErrorActionPreference = "Stop"

Write-Host "Starting Kiwix Desktop deployment process..." -ForegroundColor Green

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
if (Test-Path $exeSource) {
    Copy-Item $exeSource $OutputPath -Force
    Write-Host "Copied main executable: kiwix-desktop.exe" -ForegroundColor Green
} else {
    Write-Error "Main executable not found at: $exeSource"
}

# Find Qt installation path if not provided
if (-not $QtPath -or -not (Test-Path $QtPath)) {
    Write-Host "Searching for Qt installation..."

    # Common Qt installation locations
    $qtSearchPaths = @(
        "${env:Qt6_DIR}",
        "${env:QT_ROOT_DIR}",
        "${env:RUNNER_WORKSPACE}\Qt\6.8.1\msvc2022_64",
        "${env:RUNNER_WORKSPACE}\Qt\6.8.0\msvc2022_64",
        "${env:RUNNER_WORKSPACE}\Qt\6.7.3\msvc2022_64",
        "C:\Qt\6.8.1\msvc2022_64",
        "C:\Qt\6.8.0\msvc2022_64",
        "C:\Qt\6.7.3\msvc2022_64"
    )

    foreach ($path in $qtSearchPaths) {
        if ($path -and (Test-Path (Join-Path $path "bin\windeployqt.exe"))) {
            $QtPath = $path
            Write-Host "Found Qt at: $QtPath" -ForegroundColor Green
            break
        }
    }

    if (-not $QtPath) {
        Write-Error "Qt installation not found. Please specify QtPath parameter."
    }
}

# Run windeployqt
$windeployqt = Join-Path $QtPath "bin\windeployqt.exe"
if (Test-Path $windeployqt) {
    $targetExe = Join-Path $OutputPath "kiwix-desktop.exe"
    Write-Host "Running windeployqt..." -ForegroundColor Yellow

    $deployArgs = @(
        "--qmldir", ".",
        "--compiler-runtime",
        "--no-translations",
        "--no-system-d3d-compiler",
        "--no-opengl-sw",
        $targetExe
    )

    & $windeployqt @deployArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "windeployqt failed with exit code $LASTEXITCODE"
    }
    Write-Host "windeployqt completed successfully" -ForegroundColor Green
} else {
    Write-Error "windeployqt not found at: $windeployqt"
}

# Copy additional dependencies from kiwix-build if available
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
    "COPYING"
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
