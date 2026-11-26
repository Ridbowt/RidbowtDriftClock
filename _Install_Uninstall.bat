@echo off
setlocal EnableDelayedExpansion

:: ==========================================
:: COLORS SETUP (ANSI)
:: ==========================================
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "YELLOW=%ESC%[93m"
set "CYAN=%ESC%[96m"
set "WHITE=%ESC%[97m"
set "RESET=%ESC%[0m"

:: ==========================================
:: ADMIN RIGHTS (UAC)
:: ==========================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Requesting administrative privileges...%RESET%
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: ==========================================
:: PATH VARIABLES
:: ==========================================
set "SCR_NAME=RidbowtDriftClock.scr"
set "SOURCE_SCR=%~dp0%SCR_NAME%"
set "TARGET_SCR=%WINDIR%\System32\%SCR_NAME%"
set "SETTINGS_DIR=%APPDATA%\RidbowtDriftClock"

:MENU
cls
echo.
echo  %CYAN%=========================================%RESET%
echo  %WHITE%       Ridbowt Drift Clock          %RESET%
echo  %CYAN%=========================================%RESET%
echo.

if exist "%TARGET_SCR%" (
    echo  Status: %GREEN%[Installed]%RESET%
    echo.
    echo  %CYAN%[1]%RESET% Uninstall
) else (
    echo  Status: %RED%[Not installed]%RESET%
    echo.
    echo  %CYAN%[1]%RESET% Install
)

echo  %CYAN%[2]%RESET% Close
echo.
set /p "choice=Select an option (1 or 2): "

if "%choice%"=="1" (
    if exist "%TARGET_SCR%" (
        goto UNINSTALL
    ) else (
        goto INSTALL
    )
) else if "%choice%"=="2" (
    exit
) else (
    goto MENU
)

:INSTALL
echo.
if not exist "%SOURCE_SCR%" (
    echo %RED%[ERROR] File %SCR_NAME% not found next to the installer!%RESET%
    echo Please place it in: %~dp0
    pause
    goto MENU
)

set /p "confirm=Install Ridbowt Drift Clock? (Y/N): "
if /i "!confirm!" neq "Y" goto MENU

echo.
echo %YELLOW%Copying files...%RESET%
copy /Y "%SOURCE_SCR%" "%TARGET_SCR%" >nul

if exist "%TARGET_SCR%" (
    echo %GREEN%[SUCCESS] Screen saver installed successfully!%RESET%
    echo Opening Windows Screen Saver settings...
    timeout /t 2 >nul
    rundll32.exe desk.cpl,InstallScreenSaver "%TARGET_SCR%"
) else (
    echo %RED%[ERROR] Failed to copy the file. Access denied or file in use.%RESET%
)

pause
goto MENU


:UNINSTALL
echo.
set /p "confirm=Uninstall Ridbowt Drift Clock? (Y/N): "
if /i "!confirm!" neq "Y" goto MENU

echo.
echo %YELLOW%What to do with user settings?%RESET%
echo  [1] Remove and DELETE settings
echo  [2] Remove but KEEP settings
echo  [3] Cancel
set /p "opt=Select (1, 2 or 3): "

if "%opt%"=="3" goto MENU

echo.
echo %YELLOW%Closing running screen saver and settings windows...%RESET%

taskkill /F /IM rundll32.exe >nul 2>&1
taskkill /F /IM SystemSettings.exe >nul 2>&1
taskkill /F /IM %SCR_NAME% >nul 2>&1

echo %YELLOW%Resetting screensaver to (None)...%RESET%

:: Applying the "(None)" screensaver via registry
reg add "HKCU\Control Panel\Desktop" /v "SCRNSAVE.EXE" /t REG_SZ /d "(none)" /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v "ScreenSaveActive" /t REG_SZ /d "0" /f >nul 2>&1
:: Force Windows to refresh the settings immediately
rundll32.exe user32.dll,UpdatePerUserSystemParameters >nul 2>&1

echo %YELLOW%Deleting screen saver file...%RESET%

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Sleep -Seconds 1; " ^
  "Remove-Item -LiteralPath '%TARGET_SCR%' -Force -ErrorAction SilentlyContinue; " ^
  "if (Test-Path -LiteralPath '%TARGET_SCR%') { exit 1 } else { exit 0 }"

if %errorlevel% neq 0 (
    echo %RED%[ERROR] Failed to delete the screen saver file.%RESET%
    pause
    goto MENU
)

echo %GREEN%[SUCCESS] Screen saver removed and reset to (None).%RESET%

if "%opt%"=="1" (
    echo %YELLOW%Deleting user settings...%RESET%
    if exist "%SETTINGS_DIR%" (
        rd /S /Q "%SETTINGS_DIR%"
        if exist "%SETTINGS_DIR%" (
            echo %RED%[ERROR] Failed to delete settings folder.%RESET%
        ) else (
            echo %GREEN%[SUCCESS] User settings deleted.%RESET%
        )
    )
) else (
    echo %CYAN%[INFO] User settings were kept.%RESET%
)

pause
goto MENU