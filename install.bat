@echo off
setlocal enabledelayedexpansion
title FPV Stretcher Installer for DaVinci Resolve

echo ========================================================
echo    FPV Stretcher - One-Click Installer for Windows
echo ========================================================
echo.

set "FUSION_DIR=%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion"

if not exist "%FUSION_DIR%" (
    echo [ERROR] DaVinci Resolve Fusion directory was not found at:
    echo "%FUSION_DIR%"
    echo.
    echo Please make sure DaVinci Resolve is installed on this PC.
    echo.
    pause
    exit /b 1
)

echo [1/2] Installing FPV_Stretcher.fuse ...
if not exist "%FUSION_DIR%\Fuses" mkdir "%FUSION_DIR%\Fuses"
copy /Y "%~dp0FPV_Stretcher.fuse" "%FUSION_DIR%\Fuses\FPV_Stretcher.fuse" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy FPV_Stretcher.fuse to "%FUSION_DIR%\Fuses\"
    pause
    exit /b 1
)
echo       -> Copied to %FUSION_DIR%\Fuses\FPV_Stretcher.fuse

echo [2/2] Installing FPV_Stretcher.drfx ...
if not exist "%FUSION_DIR%\Templates" mkdir "%FUSION_DIR%\Templates"
copy /Y "%~dp0FPV_Stretcher.drfx" "%FUSION_DIR%\Templates\FPV_Stretcher.drfx" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy FPV_Stretcher.drfx to "%FUSION_DIR%\Templates\"
    pause
    exit /b 1
)
echo       -> Copied to %FUSION_DIR%\Templates\FPV_Stretcher.drfx

echo.
echo ========================================================
echo   Installation Successful!
echo ========================================================
echo.
echo NOTE: If DaVinci Resolve is currently open, please RESTART
echo       it so it can compile the new Fuse plugin into memory.
echo.
pause
