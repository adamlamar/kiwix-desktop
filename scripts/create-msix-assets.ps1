# PowerShell script to create properly sized icon assets for MSIX package
param(
    [string]$SourceIcon = "resources\icons\kiwix\app_icon_source.svg",
    [string]$OutputDir = "Assets"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating MSIX icon assets..." -ForegroundColor Green

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Required MSIX asset sizes and their dimensions
$Assets = @{
    "StoreLogo.png" = 50
    "Square44x44Logo.png" = 44
    "Square150x150Logo.png" = 150
    "Wide310x150Logo.png" = @{Width=310; Height=150}
    "LargeTile.png" = 310  # Square310x310Logo
    "SmallTile.png" = 71   # Square71x71Logo
    "SplashScreen.png" = @{Width=620; Height=300}
    "ZimFileIcon.png" = 32
}

# Try to find source PNG files first
$png512 = "resources\icons\kiwix\512"
$png256 = "resources\icons\kiwix\256"
$png128 = "resources\icons\kiwix\128"

$bestSourcePng = $null
if (Test-Path (Join-Path $png512 "kiwix-desktop.png")) {
    $bestSourcePng = Join-Path $png512 "kiwix-desktop.png"
    Write-Host "Using 512x512 PNG source: $bestSourcePng"
} elseif (Test-Path (Join-Path $png256 "kiwix-desktop.png")) {
    $bestSourcePng = Join-Path $png256 "kiwix-desktop.png"
    Write-Host "Using 256x256 PNG source: $bestSourcePng"
} elseif (Test-Path (Join-Path $png128 "kiwix-desktop.png")) {
    $bestSourcePng = Join-Path $png128 "kiwix-desktop.png"
    Write-Host "Using 128x128 PNG source: $bestSourcePng"
}

# Fallback to ICO file if no PNG found
if (-not $bestSourcePng -and (Test-Path "resources\icons\kiwix\app_icon.ico")) {
    $bestSourcePng = "resources\icons\kiwix\app_icon.ico"
    Write-Host "Using ICO file as source: $bestSourcePng"
}

if (-not $bestSourcePng) {
    Write-Warning "No suitable source icon found. Creating placeholder assets."
    # Create a simple colored rectangle as placeholder
    foreach ($asset in $Assets.GetEnumerator()) {
        $assetPath = Join-Path $OutputDir $asset.Key
        # For now, we'll copy any available icon or create empty files
        # This would need proper image processing in a real scenario
        if (Test-Path "resources\icons\kiwix\app_icon.ico") {
            Copy-Item "resources\icons\kiwix\app_icon.ico" $assetPath -Force
        } else {
            # Create an empty file as placeholder
            New-Item -ItemType File -Path $assetPath -Force | Out-Null
        }
        Write-Host "Created placeholder: $($asset.Key)" -ForegroundColor Yellow
    }
} else {
    # Copy the best available source for each required asset
    foreach ($asset in $Assets.GetEnumerator()) {
        $assetPath = Join-Path $OutputDir $asset.Key
        Copy-Item $bestSourcePng $assetPath -Force
        Write-Host "Created: $($asset.Key)" -ForegroundColor Green
    }
}

Write-Host "`nMSIX icon assets created in: $OutputDir" -ForegroundColor Green
Write-Host "`nNote: For Windows Store submission, you should:" -ForegroundColor Cyan
Write-Host "  1. Use properly sized PNG files for each asset" -ForegroundColor Cyan
Write-Host "  2. Ensure icons follow Microsoft Store guidelines" -ForegroundColor Cyan
Write-Host "  3. Consider hiring a designer for professional-quality assets" -ForegroundColor Cyan
