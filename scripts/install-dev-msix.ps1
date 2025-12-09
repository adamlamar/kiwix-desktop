# PowerShell script to install unsigned MSIX packages for development/testing
param(
    [Parameter(Mandatory=$true)]
    [string]$MsixPath,
    [switch]$EnableDeveloperMode,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "Installing MSIX package for development testing..." -ForegroundColor Green
Write-Host "Package: $MsixPath" -ForegroundColor Cyan

# Check if file exists
if (-not (Test-Path $MsixPath)) {
    Write-Error "MSIX package not found: $MsixPath"
    exit 1
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

try {
    # Method 1: Check Developer Mode
    Write-Host "`n🔍 Checking Developer Mode status..." -ForegroundColor Yellow
    $devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue

    if ($devMode -and $devMode.AllowDevelopmentWithoutDevLicense -eq 1) {
        Write-Host "✅ Developer Mode is enabled" -ForegroundColor Green

        try {
            Write-Host "Attempting to install MSIX package..." -ForegroundColor Yellow
            Add-AppxPackage -Path $MsixPath -ForceApplicationShutdown:$Force
            Write-Host "✅ Package installed successfully!" -ForegroundColor Green
            exit 0
        } catch {
            Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Developer Mode is not enabled" -ForegroundColor Red

        if ($EnableDeveloperMode) {
            if ($isAdmin) {
                Write-Host "Enabling Developer Mode..." -ForegroundColor Yellow
                if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock")) {
                    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force | Out-Null
                }
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1
                Write-Host "✅ Developer Mode enabled. Please restart this script." -ForegroundColor Green
                exit 0
            } else {
                Write-Warning "Administrator privileges required to enable Developer Mode"
            }
        }
    }

    # Method 2: Try PowerShell with bypass
    Write-Host "`n🔄 Trying alternative installation methods..." -ForegroundColor Yellow

    try {
        Write-Host "Attempting PowerShell bypass installation..." -ForegroundColor Yellow
        Add-AppxPackage -Path $MsixPath -ForceApplicationShutdown:$Force -ErrorAction Stop
        Write-Host "✅ Package installed successfully!" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "❌ PowerShell installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Method 3: Show manual installation steps
    Write-Host "`n📋 Manual Installation Options:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1 - Enable Developer Mode:" -ForegroundColor White
    Write-Host "  1. Open Settings > Update & Security > For developers" -ForegroundColor Gray
    Write-Host "  2. Enable 'Developer mode'" -ForegroundColor Gray
    Write-Host "  3. Restart this script" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2 - Install Certificate (if you have one):" -ForegroundColor White
    Write-Host "  1. Double-click the .cer certificate file" -ForegroundColor Gray
    Write-Host "  2. Click 'Install Certificate'" -ForegroundColor Gray
    Write-Host "  3. Choose 'Local Machine' > 'Place in: Trusted Root'" -ForegroundColor Gray
    Write-Host "  4. Also install to 'Trusted People'" -ForegroundColor Gray
    Write-Host "  5. Try installing MSIX again" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3 - Use App Installer:" -ForegroundColor White
    Write-Host "  1. Right-click the .msix file" -ForegroundColor Gray
    Write-Host "  2. Select 'Open with App Installer'" -ForegroundColor Gray
    Write-Host "  3. Click 'Install' (may show security warning)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 4 - Create and install development certificate:" -ForegroundColor White
    Write-Host "  1. Run: .\scripts\create-dev-cert.ps1" -ForegroundColor Gray
    Write-Host "  2. Sign the package with the generated certificate" -ForegroundColor Gray
    Write-Host "  3. Install the signed package" -ForegroundColor Gray

} catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n⚠️  Note: Unsigned packages may show security warnings" -ForegroundColor Yellow
Write-Host "For production distribution, use a trusted code signing certificate." -ForegroundColor Yellow
