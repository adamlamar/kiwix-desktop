@echo off
REM Kiwix Desktop MSIX Wrapper
REM This script sets up the Qt environment before launching the application

REM Get the directory where this script is located (MSIX installation directory)
set SCRIPT_DIR=%~dp0

REM Set Qt environment variables for MSIX package
set QT_PLUGIN_PATH=%SCRIPT_DIR%
set QT_QPA_PLATFORM_PLUGIN_PATH=%SCRIPT_DIR%platforms
set QT_MULTIMEDIA_PREFERRED_PLUGINS=windowsmediafoundation
set QTWEBENGINE_RESOURCES_PATH=%SCRIPT_DIR%resources
set QTWEBENGINE_LOCALES_PATH=%SCRIPT_DIR%locales

REM Disable Qt logging to avoid console spam in release builds
set QT_LOGGING_RULES=*.debug=false

REM Launch the actual executable with error handling
"%SCRIPT_DIR%kiwix-desktop.exe" %*
if errorlevel 1 (
    echo Kiwix Desktop encountered an error. Error level: %errorlevel%
    pause
)
