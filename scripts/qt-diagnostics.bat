@echo off
REM Simple Qt diagnostics for MSIX troubleshooting
REM This script helps diagnose Qt-related issues in the MSIX package

echo.
echo === Qt MSIX Diagnostics ===
echo.

REM Show current directory and key files
echo Current directory: %CD%
echo.

echo Checking for key Qt files:
if exist "Qt5Core.dll" (
    echo [OK] Qt5Core.dll found
) else (
    echo [FAIL] Qt5Core.dll NOT found - this will cause startup failure
)

if exist "Qt5Gui.dll" (
    echo [OK] Qt5Gui.dll found
) else (
    echo [FAIL] Qt5Gui.dll NOT found
)

if exist "Qt5Widgets.dll" (
    echo [OK] Qt5Widgets.dll found
) else (
    echo [FAIL] Qt5Widgets.dll NOT found
)

if exist "kiwix-desktop.exe" (
    echo [OK] kiwix-desktop.exe found
) else (
    echo [FAIL] kiwix-desktop.exe NOT found
)

echo.
echo Checking Qt configuration files:
if exist "qt.conf" (
    echo [OK] qt.conf found
    echo Contents:
    type qt.conf
) else (
    echo [FAIL] qt.conf NOT found - Qt may not find its plugins
)

echo.
echo Checking for Qt platforms plugin:
if exist "platforms\qwindows.dll" (
    echo [OK] platforms\qwindows.dll found
) else (
    echo [FAIL] platforms\qwindows.dll NOT found - Qt GUI will fail to initialize
)

echo.
echo Platform plugins directory contents:
if exist "platforms" (
    dir /b platforms\*.dll 2>nul
    if errorlevel 1 (
        echo [WARN] No platform plugins found
    )
) else (
    echo [FAIL] platforms directory does not exist
)

echo.
echo Environment variables that might affect Qt:
echo QT_PLUGIN_PATH=%QT_PLUGIN_PATH%
echo QT_QPA_PLATFORM_PLUGIN_PATH=%QT_QPA_PLATFORM_PLUGIN_PATH%

echo.
echo === Diagnostics complete ===
echo.
pause
