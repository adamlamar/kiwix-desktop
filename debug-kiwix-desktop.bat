@echo off
echo ======================================
echo   Kiwix Desktop Debug Launcher
echo ======================================
echo.

echo Checking environment...
echo Current directory: %CD%
echo Script directory: %~dp0
echo.

echo Checking critical files...
if exist "%~dp0kiwix-desktop.exe" (
    echo [OK] Main executable found
) else (
    echo [ERROR] Main executable NOT found
    goto :error
)

if exist "%~dp0platforms\qwindows.dll" (
    echo [OK] Qt platform plugin found
) else (
    echo [ERROR] Qt platform plugin NOT found
    echo This is likely the cause of silent exit
)

if exist "%~dp0Qt6Core.dll" (
    echo [OK] Qt6Core.dll found
) else (
    echo [ERROR] Qt6Core.dll NOT found
)

if exist "%~dp0Qt6Gui.dll" (
    echo [OK] Qt6Gui.dll found
) else (
    echo [ERROR] Qt6Gui.dll NOT found
)

if exist "%~dp0Qt6Widgets.dll" (
    echo [OK] Qt6Widgets.dll found
) else (
    echo [ERROR] Qt6Widgets.dll NOT found
)

echo.
echo Setting Qt environment...
set QT_DEBUG_LOGGING=1
set QT_LOGGING_RULES=*.debug=true
set QT_QPA_PLATFORM_PLUGIN_PATH=%~dp0platforms
set QT_PLUGIN_PATH=%~dp0

echo.
echo Attempting to launch with verbose Qt logging...
echo If you see this message but no further output, the app is crashing during Qt initialization.
echo.

"%~dp0kiwix-desktop.exe" --platform windows:verbose %*

echo.
echo Exit code: %ERRORLEVEL%
echo.

:error
echo.
echo ======================================
echo Debug complete. Check output above for clues.
echo If the application exits immediately without messages,
echo it's likely missing Qt platform plugins or dependencies.
echo ======================================
pause
