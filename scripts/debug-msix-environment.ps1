# MSIX Environment Debugging Script
# This script diagnoses and resolves MSIX packaging issues for Kiwix Desktop

param(
    [switch]$Verbose,
    [switch]$FixIssues
)

Write-Host "=== MSIX Environment Analysis for Kiwix Desktop ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray

# Function to safely execute commands with error handling
function Safe-Execute {
    param([scriptblock]$Command, [string]$Description)
    try {
        Write-Host "`n$Description" -ForegroundColor Yellow
        & $Command
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    return $true
}

# 1. MSIX Package Location Analysis
Safe-Execute {
    Write-Host "1. MSIX Package Location Analysis:"
    
    # Find the correct MSIX installation path
    $msixPackages = Get-ChildItem "C:\Program Files\WindowsApps" -Directory | Where-Object { $_.Name -like "*Kiwix*" }
    
    if ($msixPackages.Count -eq 0) {
        Write-Host "  No Kiwix MSIX packages found in WindowsApps" -ForegroundColor Red
        return
    }
    
    foreach ($package in $msixPackages) {
        Write-Host "  Found package: $($package.Name)" -ForegroundColor Green
        Write-Host "  Path: $($package.FullName)" -ForegroundColor Gray
        
        # Check for executable
        $exePath = Join-Path $package.FullName "kiwix-desktop.exe"
        if (Test-Path $exePath) {
            Write-Host "  ✓ Executable found: $(Get-Item $exePath | Select-Object -ExpandProperty Length) bytes" -ForegroundColor Green
            $script:KiwixExePath = $exePath
            $script:KiwixPackagePath = $package.FullName
        } else {
            Write-Host "  ✗ Executable missing" -ForegroundColor Red
        }
        
        # Check manifest
        $manifestPath = Join-Path $package.FullName "AppxManifest.xml"
        if (Test-Path $manifestPath) {
            Write-Host "  ✓ Manifest found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Manifest missing" -ForegroundColor Red
        }
    }
} "MSIX Package Discovery"

# 2. User Package Data Analysis
Safe-Execute {
    Write-Host "2. User Package Data Analysis:"
    
    $userPackages = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory | Where-Object { $_.Name -like "*Kiwix*" }
    
    if ($userPackages.Count -eq 0) {
        Write-Host "  No user package data found" -ForegroundColor Red
        return
    }
    
    foreach ($userPackage in $userPackages) {
        Write-Host "  Found user data: $($userPackage.Name)" -ForegroundColor Green
        Write-Host "  Path: $($userPackage.FullName)" -ForegroundColor Gray
        
        # Check for writable areas
        $localState = Join-Path $userPackage.FullName "LocalState"
        $roamingState = Join-Path $userPackage.FullName "RoamingState"
        $tempState = Join-Path $userPackage.FullName "TempState"
        
        @($localState, $roamingState, $tempState) | ForEach-Object {
            if (Test-Path $_) {
                $folderName = Split-Path $_ -Leaf
                Write-Host "  ✓ $folderName exists" -ForegroundColor Green
            }
        }
    }
} "User Package Data"

# 3. Qt Configuration Analysis
Safe-Execute {
    Write-Host "3. Qt Configuration Analysis:"
    
    if (-not $script:KiwixPackagePath) {
        Write-Host "  Cannot analyze Qt - package path not found" -ForegroundColor Red
        return
    }
    
    # Check qt.conf
    $qtConfPath = Join-Path $script:KiwixPackagePath "qt.conf"
    if (Test-Path $qtConfPath) {
        Write-Host "  ✓ qt.conf found" -ForegroundColor Green
        $qtConfContent = Get-Content $qtConfPath -Raw
        Write-Host "  Content:" -ForegroundColor Gray
        $qtConfContent.Split("`n") | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ✗ qt.conf missing" -ForegroundColor Red
    }
    
    # Check Qt libraries
    $qtDlls = Get-ChildItem $script:KiwixPackagePath -Filter "Qt*.dll" -ErrorAction SilentlyContinue
    Write-Host "  Qt DLLs found: $($qtDlls.Count)" -ForegroundColor $(if ($qtDlls.Count -gt 0) { "Green" } else { "Red" })
    
    if ($Verbose -and $qtDlls.Count -gt 0) {
        $qtDlls | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Gray }
    }
    
    # Check Qt plugins
    $pluginsDir = Join-Path $script:KiwixPackagePath "plugins"
    if (Test-Path $pluginsDir) {
        $pluginCount = (Get-ChildItem $pluginsDir -Recurse -File).Count
        Write-Host "  ✓ Plugins directory: $pluginCount files" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Plugins directory missing" -ForegroundColor Red
    }
} "Qt Configuration"

# 4. MSIX Execution Context Test
Safe-Execute {
    Write-Host "4. MSIX Execution Context Test:"
    
    if (-not $script:KiwixExePath) {
        Write-Host "  Cannot test execution - executable path not found" -ForegroundColor Red
        return
    }
    
    # Test 1: PowerShell execution from correct directory
    Write-Host "  Test 1: PowerShell from package directory"
    $packageDir = Split-Path $script:KiwixExePath -Parent
    Push-Location $packageDir -ErrorAction SilentlyContinue
    
    try {
        if (Test-Path "kiwix-desktop.exe") {
            Write-Host "    ✓ Executable accessible from package directory" -ForegroundColor Green
            
            # Try to get file version
            try {
                $fileVersion = (Get-Command ".\kiwix-desktop.exe").FileVersionInfo
                Write-Host "    ✓ File version accessible: $($fileVersion.FileVersion)" -ForegroundColor Green
            } catch {
                Write-Host "    ✗ File version not accessible: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "    ✗ Executable not accessible from package directory" -ForegroundColor Red
        }
    } finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
    
    # Test 2: Direct execution attempt
    Write-Host "  Test 2: Direct execution attempt"
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $script:KiwixExePath
        $startInfo.Arguments = "--version"
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.WorkingDirectory = Split-Path $script:KiwixExePath -Parent
        
        $process = [System.Diagnostics.Process]::Start($startInfo)
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        
        if ($process.WaitForExit(10000)) {
            $output = $outputTask.Result
            $error = $errorTask.Result
            
            Write-Host "    Exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Red" })
            if ($output) { Write-Host "    Output: $output" -ForegroundColor Green }
            if ($error) { Write-Host "    Error: $error" -ForegroundColor Red }
        } else {
            Write-Host "    ✗ Process timed out after 10 seconds" -ForegroundColor Red
            $process.Kill()
        }
    } catch {
        Write-Host "    ✗ Execution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} "MSIX Execution Context"

# 5. Windows Event Log Analysis
Safe-Execute {
    Write-Host "5. Windows Event Log Analysis (Last 10 Kiwix-related events):"
    
    $events = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddHours(-24)} -ErrorAction SilentlyContinue |
              Where-Object { $_.LevelDisplayName -eq 'Error' -and ($_.Message -like '*kiwix*' -or $_.Message -like '*Kiwix*') } |
              Select-Object -First 10
    
    if ($events.Count -eq 0) {
        Write-Host "  No recent error events found for Kiwix" -ForegroundColor Yellow
    } else {
        $events | ForEach-Object {
            Write-Host "  Event $($_.Id) at $($_.TimeCreated):" -ForegroundColor Red
            Write-Host "    $($_.Message.Split("`n")[0])" -ForegroundColor Gray
        }
    }
} "Event Log Analysis"

# 6. Dependency Analysis
Safe-Execute {
    Write-Host "6. Dependency Analysis:"
    
    if (-not $script:KiwixExePath) {
        Write-Host "  Cannot analyze dependencies - executable path not found" -ForegroundColor Red
        return
    }
    
    # Check VC++ Redistributable
    $vcRedistPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT\msvcp140.dll",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT\msvcp140.dll",
        "$env:SystemRoot\System32\msvcp140.dll"
    )
    
    $vcRedistFound = $false
    foreach ($path in $vcRedistPaths) {
        $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($resolved) {
            Write-Host "  ✓ VC++ Redistributable found: $($resolved.Path)" -ForegroundColor Green
            $vcRedistFound = $true
            break
        }
    }
    
    if (-not $vcRedistFound) {
        Write-Host "  ✗ VC++ Redistributable not found" -ForegroundColor Red
    }
    
    # Check for critical DLLs in package
    $criticalDlls = @("msvcp140.dll", "vcruntime140.dll", "msvcp140_1.dll", "msvcp140_2.dll")
    $packageDir = Split-Path $script:KiwixExePath -Parent
    
    foreach ($dll in $criticalDlls) {
        $dllPath = Join-Path $packageDir $dll
        if (Test-Path $dllPath) {
            Write-Host "  ✓ $dll found in package" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $dll missing from package" -ForegroundColor Red
        }
    }
} "Dependency Analysis"

# 7. Recommended Fixes
Write-Host "`n=== RECOMMENDED FIXES ===" -ForegroundColor Cyan

if ($script:KiwixExePath) {
    Write-Host "✓ MSIX package is properly installed" -ForegroundColor Green
} else {
    Write-Host "✗ MSIX package installation issue detected" -ForegroundColor Red
    Write-Host "  Recommendation: Reinstall the MSIX package" -ForegroundColor Yellow
}

# Check if fixes should be applied
if ($FixIssues) {
    Write-Host "`nApplying automatic fixes..." -ForegroundColor Yellow
    
    # Fix 1: Create proper qt.conf if missing or incorrect
    if ($script:KiwixPackagePath) {
        $qtConfPath = Join-Path $script:KiwixPackagePath "qt.conf"
        $correctQtConf = @"
[Paths]
Plugins = plugins
"@
        
        try {
            $correctQtConf | Set-Content $qtConfPath -Encoding UTF8 -Force
            Write-Host "  ✓ Fixed qt.conf configuration" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Could not fix qt.conf: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host "For detailed Qt diagnostics, run: qt-diagnostics.ps1 from the package directory" -ForegroundColor Gray
Write-Host "To apply automatic fixes, run this script with -FixIssues parameter" -ForegroundColor Gray