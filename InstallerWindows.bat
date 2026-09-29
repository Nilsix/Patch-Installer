@echo off
setlocal EnableExtensions DisableDelayedExpansion
title ReBalance of Souls - installer
rem ===========================================================================
rem  ReBalance of Souls -- Windows installer
rem
rem  1. Finds Git, and Python 3.8+ with tkinter. Installs only what is missing,
rem     with winget, for this Windows user. It never uninstalls anything.
rem  2. Downloads the patch into BROS-Patch\ next to this file: the current
rem     files only, not the full history of every file, which is about half
rem     the download.
rem  3. Puts a "ReBalance of Souls" shortcut on the desktop.
rem
rem  Run it again at any time: it repairs and updates BROS-Patch\ in place,
rem  downloads only what changed, and keeps the launcher's settings
rem  (Json\config.json).
rem
rem  BROS_REPO_URL overrides where the patch is downloaded from, and
rem  BROS_NO_SHORTCUT=1 skips the desktop shortcut.
rem ===========================================================================

cd /d "%~dp0"
set "REPO_URL=https://github.com/reBalance-Of-Souls/BROS-Patch.git"
if defined BROS_REPO_URL set "REPO_URL=%BROS_REPO_URL%"
set "DEST=%~dp0BROS-Patch"
set "LAUNCHER=Bleach Rebirth of Souls Community Patch.py"
rem  Windows' own tools by full path: a PATH that lists another find.exe or
rem  where.exe first (Cygwin, MSYS, some Git setups) must not change them.
set "SYS=%SystemRoot%\System32"

echo.
echo   ReBalance of Souls - installer
echo   ==============================
echo.

rem  Double-clicking the .bat inside the ZIP runs it from a temporary copy that
rem  Windows deletes later -- and the patch would be downloaded there too.
echo "%~dp0" | "%SYS%\find.exe" /i "\Temp1_" >nul && goto in_zip
echo "%~dp0" | "%SYS%\find.exe" /i "\Rar$" >nul && goto in_zip
echo "%~dp0" | "%SYS%\find.exe" /i "\7zO" >nul && goto in_zip

echo "%~dp0" | "%SYS%\find.exe" /i "\OneDrive" >nul && (
    echo   Warning: this folder is inside OneDrive, which would upload the
    echo   whole patch - about 7 GB - to your OneDrive. A folder such as
    echo   C:\Games is a better place for it. Close this window to move it.
    echo.
)

echo   Before your first launch, copy your "BLEACH Rebirth of Souls" game
echo   folder somewhere safe. The launcher's Repair button restores from it.
echo.
pause
echo.

rem --- Git -------------------------------------------------------------------
call :find_git && goto git_ok
echo Git is not installed. Installing it...
call :winget_install Git.Git || goto fail
call :find_git && goto git_ok
echo.
echo error: Git was installed but cannot be found. Close this window and run
echo        the installer again. If it still fails, install Git by hand from
echo        https://git-scm.com/download/win
goto fail
:git_ok
echo Git:    %GIT%

rem --- Python ----------------------------------------------------------------
call :find_python && goto python_ok
echo Python with tkinter is not installed. Installing Python 3.13 for this user...
call :winget_install Python.Python.3.13 --scope user || goto fail
call :find_python && goto python_ok
echo.
echo error: Python was installed but cannot be found. Close this window and
echo        run the installer again.
goto fail
:python_ok
echo Python: %PYEXE%

rem --- The patch -------------------------------------------------------------
if exist "%DEST%\.git\" goto update
if exist "%DEST%\" goto convert

echo.
echo Downloading the patch into "%DEST%"
echo About 1.4 GB. If it gets interrupted, run the installer again.
echo.
"%GIT%" -c core.longpaths=true clone --filter=blob:none --progress "%REPO_URL%" "%DEST%"
if errorlevel 1 goto download_failed
"%GIT%" -C "%DEST%" config core.longpaths true
goto patch_ok

:update
echo.
echo BROS-Patch is already there: updating it in place. Your launcher settings
echo are kept.
echo.
rem  core.longpaths: the patch has Effect\spfx\... paths longer than the
rem  260 characters Windows allows by default.
"%GIT%" -C "%DEST%" config core.longpaths true
"%GIT%" -C "%DEST%" remote set-url origin "%REPO_URL%" 2>nul || "%GIT%" -C "%DEST%" remote add origin "%REPO_URL%"
"%GIT%" -C "%DEST%" fetch --progress origin
if errorlevel 1 goto download_failed
"%GIT%" -C "%DEST%" reset -q --hard origin/main
if errorlevel 1 goto download_failed
rem  The launcher runs "git pull", which needs the branch to follow origin/main.
"%GIT%" -C "%DEST%" branch -q --set-upstream-to=origin/main
goto patch_ok

:convert
rem  A BROS-Patch folder that is not a git download -- copied by hand, or
rem  left by an old installer that was closed halfway. Make it one in place;
rem  a file of the patch that is already there is replaced, anything else
rem  in the folder is left alone.
echo.
echo BROS-Patch exists but was not downloaded with git: turning it into a
echo proper download in place. About 1.4 GB.
echo.
"%GIT%" -C "%DEST%" init -q
"%GIT%" -C "%DEST%" config core.longpaths true
"%GIT%" -C "%DEST%" remote add origin "%REPO_URL%" 2>nul || "%GIT%" -C "%DEST%" remote set-url origin "%REPO_URL%"
"%GIT%" -C "%DEST%" fetch --filter=blob:none --progress origin
if errorlevel 1 goto download_failed
"%GIT%" -C "%DEST%" checkout -q -f -B main --track origin/main
if errorlevel 1 goto download_failed

:patch_ok
echo.
echo Patch:  %DEST%

rem --- Desktop shortcut ------------------------------------------------------
rem  It runs python.exe on the launcher rather than opening the .py file, so
rem  the launcher starts even on a PC where .py files open in a text editor.
rem  python.exe and not pythonw.exe: the launcher shows its console window
rem  when something goes wrong, and needs one to do that.
set "LAUNCHER_PATH=%DEST%\%LAUNCHER%"
if defined BROS_NO_SHORTCUT goto done
"%SYS%\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "$dir = $env:BROS_SHORTCUT_DIR; if (-not $dir) { $dir = [Environment]::GetFolderPath('Desktop') }; $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $dir 'ReBalance of Souls.lnk')); $s.TargetPath = $env:PYEXE; $s.Arguments = [char]34 + $env:LAUNCHER_PATH + [char]34; $s.WorkingDirectory = $env:DEST; $s.IconLocation = (Join-Path $env:DEST 'ressources\pimplin.ico'); $s.Save()" >nul 2>&1
if errorlevel 1 goto no_shortcut
echo Shortcut: "ReBalance of Souls" on your desktop
goto done
:no_shortcut
echo The desktop shortcut could not be created. Start the launcher by
echo double-clicking "%LAUNCHER%" in the BROS-Patch folder.

:done
echo.
echo   Done. Start the launcher from the "ReBalance of Souls" shortcut. It
echo   updates itself every time it starts, so there is no need to run this
echo   installer again unless something is broken.
echo.
pause
exit /b 0

:in_zip
echo   This installer is running from inside the ZIP file. Extract the ZIP
echo   first -- right-click it, "Extract All..." -- then run
echo   InstallerWindows.bat from the extracted folder.
goto fail

:download_failed
echo.
echo error: the download did not finish; git says why just above. Check your
echo        internet connection, then run this installer again.
goto fail

:fail
echo.
echo   The installation did not finish. Fix the problem above, then run this
echo   installer again.
echo.
pause
exit /b 1

rem ===========================================================================
rem  Subroutines
rem ===========================================================================

:find_git
rem  winget puts Git on the PATH of new windows only, never on this one's; so
rem  after installing it, look where its installer puts it.
set "GIT="
for /f "delims=" %%G in ('"%SYS%\where.exe" git 2^>nul') do if not defined GIT set "GIT=%%G"
if not defined GIT if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
if not defined GIT if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" set "GIT=%ProgramFiles(x86)%\Git\cmd\git.exe"
if not defined GIT exit /b 1
exit /b 0

:find_python
rem  Same PATH problem as Git, so the usual install folders are searched too.
call :try_python py -3 && exit /b 0
call :try_python python && exit /b 0
call :try_python "%LOCALAPPDATA%\Programs\Python\Launcher\py.exe" -3 && exit /b 0
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*" "%ProgramFiles%\Python3*" "%LOCALAPPDATA%\Python\pythoncore-3*") do (
    call :try_python "%%~D\python.exe" && exit /b 0
)
exit /b 1

:try_python
rem  %1 = interpreter, %2 = optional version switch. Accepted only when it is
rem  Python 3.8 or newer AND has tkinter, which the launcher's window needs.
rem  PYEXE is the python.exe behind it: py.exe only starts another program,
rem  and the shortcut needs the interpreter itself.
set "PYEXE="
for /f "usebackq delims=" %%E in (`call "%~1" %2 -c "import sys, tkinter; sys.version_info >= (3, 8) and print(sys.executable)" 2^>nul`) do set "PYEXE=%%E"
if defined PYEXE exit /b 0
exit /b 1

:winget_install
rem  %1 = package id, %2 %3 = extra winget arguments
"%SYS%\where.exe" winget >nul 2>&1 || goto no_winget
winget install --id %1 -e --source winget --accept-source-agreements --accept-package-agreements %2 %3
rem  winget's exit code is not a reliable answer ("already installed" is an
rem  error, for one), so the caller looks for the program again instead.
exit /b 0
:no_winget
echo.
echo error: winget is not available on this PC, so %1 cannot be installed
echo        automatically. Install it by hand, then run this installer again:
echo          Git:    https://git-scm.com/download/win
echo          Python: https://www.python.org/downloads/windows/
exit /b 1
