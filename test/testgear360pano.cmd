@echo off

rem Test script for gear360pano.cmd

rem Install image magic in this path, don't forget to include legacy tools (convert)
set IMGMAGPATH=C:\Program Files\ImageMagick
set IMGMAGCONV=%IMGMAGPATH%\convert.exe
set T=gear360pano.cmd
set DEBUG=""
rem This is used as return value
set RETVAL=
set EXITCODE=0
set VERSION=1

goto MAIN

rem Print debug information
rem params: what to display
:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)
set RETVAL=
exit /b 0

rem Generate test image
rem param1: size (7776x3888 by default)
rem param2: output FILENAME
rem return (as RETVAL), filename
:TEST_IMAGE
set IMGSIZE=%1
set FILENAME=%2

rem Default parameters
if "%IMGSIZE%" == "" set IMGSIZE=7776x3888
if "%FILENAME%" == "" set FILENAME=%TEMP%\testpano.jpg
"%IMGMAGCONV%" -type TrueColor -size %IMGSIZE% pattern:checkerboard -auto-level %FILENAME%
set RETVAL=%FILENAME%
exit /b 0

rem Execute test
rem param1: test command (in quotes)
rem param2: test description (in quotes)
rem param3: expected exit code (optional, default 0)
:EXEC_TEST
set start=%time%
set TESTCMD=%~1
set TESTDESCR=%~2
rem Optional, default: 0
set EXPECTEDEXITCODE=%3
set LOGOUTPUT=%TEMP%\cmdout.log

if "%EXPECTEDEXITCODE%" == "" set EXPECTEDEXITCODE=0

call :PRINT_DEBUG exec_test command: %TESTCMD%, descr: %TESTDESCR%, ^
  expected return code: %EXPECTEDEXITCODE%, log out: %LOGOUTPUT%

echo --------
echo %TESTDESCR%
call %TESTCMD% > %LOGOUTPUT%
set EXITCODE=%ERRORLEVEL%
set end=%time%

if %EXITCODE% neq %EXPECTEDEXITCODE% (
  echo Test failed, exit code: %EXITCODE%, expected: %EXPECTEDEXITCODE%
  echo Check file %LOGOUTPUT% to see program output
) else (
  echo OK
)

set options="tokens=1-4 delims=:.,"
rem Don't try to break lines here, it will most probably not work
for /f %options% %%a in ("%start%") do set start_h=%%a&set /a start_m=100%%b %% 100&set /a start_s=100%%c %% 100&set /a start_ms=100%%d %% 100
for /f %options% %%a in ("%end%") do set end_h=%%a&set /a end_m=100%%b %% 100&set /a end_s=100%%c %% 100&set /a end_ms=100%%d %% 100

set /a hours=%end_h%-%start_h%
set /a mins=%end_m%-%start_m%
set /a secs=%end_s%-%start_s%
set /a ms=%end_ms%-%start_ms%
if %ms% lss 0 set /a secs = %secs% - 1 & set /a ms = 100%ms%
if %secs% lss 0 set /a mins = %mins% - 1 & set /a secs = 60%secs%
if %mins% lss 0 set /a hours = %hours% - 1 & set /a mins = 60%mins%
if %hours% lss 0 set /a hours = 24%hours%
if 1%ms% lss 100 set ms=0%ms%

rem mission accomplished
set /a totalsecs = %hours%*3600 + %mins%*60 + %secs%
echo Test took: %totalsecs% s
set RETVAL=
exit /b 0

:MAIN

rem Test suite version
echo Test suite version: %VERSION%

rem Image magick?
if not exist "%IMGMAGCONV%" goto NOIMGMAG

rem Simple help test
call :EXEC_TEST "%T% /h" "Help test"

rem Simple image test
call :TEST_IMAGE
set IMAGE=%RETVAL%
call :EXEC_TEST "%T% %IMAGE%" "Simple panorama test"

echo Done

goto eof

:NOIMGMAG
echo ImageMagick not installed, download from: https://www.imagemagick.org
echo Install in C:\Program Files\ImageMagick and tick legacy tools
set EXITCODE=1
goto eof

:eof
exit /b %EXITCODE%
