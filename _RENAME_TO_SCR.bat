@echo off
set "SOURCE=%~dp0RidbowtDriftClock.exe"
set "TARGET=%~dp0RidbowtDriftClock.scr"

if not exist "%SOURCE%" (
    echo Source file not found:
    echo %SOURCE%
    pause
    exit /b 1
)

copy /Y "%SOURCE%" "%TARGET%" >nul

if errorlevel 1 (
    echo.
    echo Failed to create or overwrite RidbowtDriftClock.scr
    pause
    exit /b 1
)

echo.
echo RidbowtDriftClock.scr successfully updated!
echo Original RidbowtDriftClock.exe was preserved.

pause