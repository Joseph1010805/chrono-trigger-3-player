@echo off
setlocal
title Chrono Trigger FMV kit
cd /d "%~dp0"

if "%~1"=="" goto :usage

where python >nul 2>nul
if errorlevel 1 goto :nopython
where ffmpeg >nul 2>nul
if errorlevel 1 goto :noffmpeg

echo Checking Python packages...
python -m pip install --quiet --disable-pip-version-check numpy pillow
if errorlevel 1 goto :nopip

echo.
echo What is your patched ROM called? Type the file name without .sfc or .smc
echo   Example: Chrono Trigger 3P
set "ROMNAME="
set /p "ROMNAME=> "
if not defined ROMNAME goto :usage

echo.
echo Making the videos. This takes a few minutes...
python make_videos.py "%~1" "%ROMNAME%"
if errorlevel 1 goto :failed

echo.
echo Done. Copy these files into the folder that holds your ROM:
echo   "%ROMNAME%.msu"
echo   "%ROMNAME%-100.pcm" through "%ROMNAME%-109.pcm"
echo They are in: %~dp0
goto :end

:usage
echo Drag your "Final Fantasy Chronicles - Chrono Trigger (USA)" .bin file
echo onto MAKE_VIDEOS.bat to start.
goto :end

:nopython
echo Python 3 isn't installed. Get it from https://www.python.org/downloads/
echo and tick "Add python.exe to PATH" in the installer.
echo Or open a Command Prompt and run:  winget install Python.Python.3.12
goto :end

:noffmpeg
echo ffmpeg isn't installed. Open a Command Prompt and run:
echo   winget install Gyan.FFmpeg
echo then close this window and try again.
goto :end

:nopip
echo Couldn't install numpy and pillow. Try running this yourself:
echo   python -m pip install numpy pillow
goto :end

:failed
echo.
echo Something went wrong - see the message above.

:end
echo.
pause
