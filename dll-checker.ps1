# Windows DLL Dependency Checker for Kiwix Desktop
# This script checks for missing DLLs that prevent the executable from starting

param(
    [string]$ExePath = "kiwix-desktop.exe"
)

Write-Host "=== Windows DLL Dependency Checker ===" -ForegroundColor Cyan
Write-Host "This tool helps diagnose why an executable won't start (fails before main())"
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not [System.IO.Path]::IsPathRooted($ExePath)) {
    $ExePath = Join-Path $scriptDir $ExePath
}

if (-not (Test-Path $ExePath)) {
    Write-Host "✗ Executable not found: $ExePath" -ForegroundColor Red
    exit 1
}

Write-Host "Checking executable: $ExePath" -ForegroundColor Green
Write-Host ""

# Function to check if a DLL can be loaded
function Test-DllLoadable {
    param([string]$DllPath)

    try {
        # Try to load the DLL using .NET reflection (safer than LoadLibrary)
        $bytes = [System.IO.File]::ReadAllBytes($DllPath)
        $assembly = [System.Reflection.Assembly]::ReflectionOnlyLoad($bytes)
        return $true
    }
    catch {
        return $false
    }
}

# Use dumpbin to get dependencies if available
$dumpbin = Get-Command "dumpbin.exe" -ErrorAction SilentlyContinue
if ($dumpbin) {
    Write-Host "=== Analyzing DLL Dependencies ===" -ForegroundColor Yellow

    try {
        $output = & dumpbin /dependents $ExePath 2>&1
        $dependencies = $output | Select-String "\.dll" | ForEach-Object {
            $_.Line.Trim() -replace '\s+', ''
        } | Where-Object { $_ -match '^[^.]+\.dll$' }

        Write-Host "Direct dependencies found:" -ForegroundColor Green

        foreach ($dll in $dependencies) {
            $dllPath = Join-Path $scriptDir $dll
            $systemDll = $false

            # Check if it's in the application directory
            if (Test-Path $dllPath) {
                if (Test-DllLoadable $dllPath) {
                    Write-Host "✓ $dll (local)" -ForegroundColor Green
                } else {
                    Write-Host "✗ $dll (local, corrupted)" -ForegroundColor Red
                }
            }
            # Check if it's a system DLL
            else {
                $systemPaths = @(
                    "$env:SystemRoot\System32",
                    "$env:SystemRoot\SysWOW64"
                )

                foreach ($sysPath in $systemPaths) {
                    $sysDllPath = Join-Path $sysPath $dll
                    if (Test-Path $sysDllPath) {
                        Write-Host "✓ $dll (system)" -ForegroundColor Green
                        $systemDll = $true
                        break
                    }
                }

                if (-not $systemDll) {
                    Write-Host "✗ $dll (MISSING)" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "Could not run dumpbin: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "dumpbin.exe not found - cannot analyze dependencies" -ForegroundColor Yellow
    Write-Host "Install Visual Studio Build Tools for detailed analysis" -ForegroundColor Yellow
}

# Check for common Qt6 issues
Write-Host "`n=== Qt6 Specific Checks ===" -ForegroundColor Yellow

# Check for Qt6 platform plugins
$platformsDir = Join-Path $scriptDir "platforms"
if (Test-Path $platformsDir) {
    $qwindows = Join-Path $platformsDir "qwindows.dll"
    if (Test-Path $qwindows) {
        Write-Host "✓ Qt platform plugin (qwindows.dll) found" -ForegroundColor Green
    } else {
        Write-Host "✗ Qt platform plugin (qwindows.dll) MISSING - This will cause silent exit!" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Platforms directory missing - This will cause silent exit!" -ForegroundColor Red
}

# Check for VC++ Redistributables
Write-Host "`n=== VC++ Runtime Check ===" -ForegroundColor Yellow
$vcRuntimes = @(
    @{ Name = "msvcp140.dll"; Description = "C++ Standard Library" },
    @{ Name = "vcruntime140.dll"; Description = "Visual C++ Runtime" },
    @{ Name = "vcruntime140_1.dll"; Description = "Visual C++ Runtime (additional)" }
)

foreach ($runtime in $vcRuntimes) {
    $localPath = Join-Path $scriptDir $runtime.Name
    $systemPath = Join-Path "$env:SystemRoot\System32" $runtime.Name

    if (Test-Path $localPath) {
        Write-Host "✓ $($runtime.Name) (local) - $($runtime.Description)" -ForegroundColor Green
    }
    elseif (Test-Path $systemPath) {
        Write-Host "✓ $($runtime.Name) (system) - $($runtime.Description)" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $($runtime.Name) MISSING - $($runtime.Description)" -ForegroundColor Red
    }
}

# Use Windows Error Reporting to try to catch crash details
Write-Host "`n=== Attempting Controlled Launch ===" -ForegroundColor Yellow

# Create a simple launcher that can catch some initialization errors
$launcherCode = @'
#include <windows.h>
#include <stdio.h>

int main() {
    printf("=== DLL Loader Test ===\n");

    HMODULE hExe = LoadLibrary(L"kiwix-desktop.exe");
    if (hExe == NULL) {
        DWORD error = GetLastError();
        printf("Failed to load executable as library. Error: %lu\n", error);

        switch(error) {
            case ERROR_MOD_NOT_FOUND:
                printf("Error: Module not found (missing dependency DLL)\n");
                break;
            case ERROR_BAD_EXE_FORMAT:
                printf("Error: Bad executable format (architecture mismatch?)\n");
                break;
            case ERROR_ACCESS_DENIED:
                printf("Error: Access denied\n");
                break;
            default:
                printf("Error: Other error occurred\n");
                break;
        }
        return 1;
    } else {
        printf("Executable loaded successfully as library\n");
        FreeLibrary(hExe);
        return 0;
    }
}
'@

$launcherPath = Join-Path $scriptDir "dll_test_launcher.c"
Set-Content -Path $launcherPath -Value $launcherCode -Encoding ASCII

Write-Host "Created C test launcher: dll_test_launcher.c"
Write-Host "To compile and test:"
Write-Host "  cl dll_test_launcher.c /Fe:dll_test.exe"
Write-Host "  .\dll_test.exe"
Write-Host ""

Write-Host "=== Alternative Debugging Approaches ===" -ForegroundColor Cyan
Write-Host "1. Use Process Monitor (ProcMon) to see file access attempts"
Write-Host "2. Use Dependencies.exe (https://github.com/lucasg/Dependencies) for detailed DLL analysis"
Write-Host "3. Use Application Verifier for heap corruption detection"
Write-Host "4. Check Windows Event Viewer for application crashes"
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($dumpbin) {
    Write-Host "✓ Used dumpbin to analyze dependencies"
} else {
    Write-Host "⚠ Install Visual Studio Build Tools for better analysis"
}

Write-Host "`nIf the executable still won't start after fixing missing DLLs,"
Write-Host "the issue might be:"
Write-Host "  - Architecture mismatch (32-bit vs 64-bit)"
Write-Host "  - Corrupted executable"
Write-Host "  - Missing Windows runtime components"
Write-Host "  - Security software blocking execution"

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
