@echo off

rem Test script for gear360video.cmd

set FFMPEGPATH=c:\Program Files\ffmpeg\bin
set FFMPEGEXE="%FFMPEGPATH%\ffmpeg.exe"
set T=gear360video.cmd
set DEBUG=""
rem This is used as a return value from functions
set RETVAL=
set EXITCODE=0
set VERSION=1

goto MAIN

:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)
set RETVAL=
exit /b 0

rem Create test video
rem param1 - video size (in pixels, optional)
rem param2 - duration (in seconds, optional)
rem param3 - frame rate (fps, optional)
rem param4 - no sound (0 - sound /default/, 1 - no sound)
rem returns test file full path in RETVAL variable
:TEST_VIDEO
set VIDEOFORMAT=mp4
set VIDEOSIZE=%1
set DURATION=%2
set FRAMERATE=%3
set NOSOUND=%4
rem This is to reset the value, session might store those between runs
set FILENAME=

if "%VIDEOSIZE%" == "" set VIDEOSIZE=3840x1920
if "%DURATION%" == "" set DURATION=1
if "%FRAMERATE%" == "" set FRAMERATE=29.97
if "%NOSOUND%" == "" set NOSOUND=0
if "%FILENAME%" == "" set FILENAME=%TEMP%\testvideo.%VIDEOFORMAT%

rem echo "create_test_video args: size: ${videosize}, duration: ${duration}, fps: ${framerate}, nosound: ${nosound}, out filename: ${filename}"

set SOUNDOPT=
if %NOSOUND% == 0 (
  set SOUNDOPT=-f lavfi -i sine=frequency=1000:sample_rate=48000:duration=%DURATION%
)
%FFMPEGEXE% -loglevel quiet -y -f lavfi -i testsrc=duration=%DURATION%:size=%VIDEOSIZE%:rate=%FRAMERATE% %SOUNDOPT% -f %VIDEOFORMAT% %FILENAME%
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

rem Trick to create output filename (one with _pano)
:ADDPANOTOFILENAME
set RETVAL=%~n1_pano.mp4
exit /b 0

:MAIN

rem Test suite version
echo Test suite version: %VERSION%

rem Simple help test
call :EXEC_TEST "%T% /h" "Help test"

rem Simple video test
call :TEST_VIDEO
set VIDEOFILE=%RETVAL%
call :EXEC_TEST "%T% %VIDEOFILE%" "Simple video test"
rem Check if panorama video has been created
call :ADDPANOTOFILENAME %VIDEOFILE%
set EXPECTEDVIDEO=html\data\%RETVAL%
if not exist %EXPECTEDVIDEO% echo "Output video file %EXPECTEDVIDEO% does not exits"

echo Done
goto eof

:eof
exit /b %EXITCODE%
