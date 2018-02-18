@echo off

rem Script to stitch panoramic videos produced by Samsung Gear360 (and others?).

rem For help (hopefully) see:
rem https://github.com/ultramango/gear360pano

rem Names:
rem dec, DEC, decoding - means video -> images
rem enc, ENC, encoding - means stitched images -> video

set FFMPEGPATH=c:\Program Files\ffmpeg\bin
set FRAMESTEMPDIR=frames
set OUTTEMPDIR=frames_stitched
set PTOTMPL=gear360video3840.pto
rem %% is an escape character (note: this will fail on wine's cmd.exe)
set IMAGETMPLDEC=image%%05d.jpg
set IMAGETMPLENC=image%%05d_pano.jpg
set TMPAUDIO=tmpaudio.aac
set TMPVIDEO=tmpvideo.mp4
set DEBUG=""

rem Check arguments
IF [%1] == [] GOTO NOARGS

:SETNAMEOK
rem Check ffmpeg...
if exist "%FFMPEGPATH%/ffmpeg.exe" goto FFMPEGOK
goto NOFFMPEG

:FFMPEGOK
rem Create temporary directories
mkdir %FRAMESTEMPDIR%
mkdir %OUTTEMPDIR%

rem Execute commands (as simple as it is)
echo Converting video to images...
"%FFMPEGPATH%/ffmpeg.exe" -y -i %1 %FRAMESTEMPDIR%/%IMAGETMPLDEC%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

rem Stitching
echo Stitching frames...
for %%f in (%FRAMESTEMPDIR%/*.jpg) do (
rem For whatever reason (this has to be at the beginning of the line!)
  echo Processing frame %FRAMESTEMPDIR%\%%f
rem TODO: There should be some error checking
  call gear360pano.cmd /m /o %OUTTEMPDIR% %FRAMESTEMPDIR%\%%f %PTOTMPL%
)

echo "Reencoding video..."
"%FFMPEGPATH%/ffmpeg.exe" -y -f image2 -i %OUTTEMPDIR%/%IMAGETMPLENC% -r 30 -s 3840:1920 -vcodec libx264 %OUTTEMPDIR%/%TMPVIDEO%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

echo "Extracting audio..."
"%FFMPEGPATH%/ffmpeg.exe" -y -i %1 -vn -acodec copy %OUTTEMPDIR%/%TMPAUDIO%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

echo "Merging audio..."

rem Check if second argument present, if not, set some default for output filename
rem This is here, because for whatever reason OUTNAME gets overriden by
rem the last iterated filename if this is at the beginning (for loop is buggy?)
if not [%2] == [] goto SETNAMEOK
set OUTNAME="%~n1_pano.mp4"

:SETNAMEOK
"%FFMPEGPATH%/ffmpeg.exe" -y -i %OUTTEMPDIR%/%TMPVIDEO% -i %OUTTEMPDIR%/%TMPAUDIO% -c:v copy -c:a aac -strict experimental %OUTNAME%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

rem Clean-up (f - force, read-only & dirs, q - quiet)
del /f /q %FRAMESTEMPDIR%
del /f /q %OUTTEMPDIR%

echo Video written to %OUTNAME%
goto eof

:NOARGS
echo Script to stitch raw video panorama files, raw
echo meaning two fisheye images side by side.
echo.
echo Script originally writen for Samsung Gear 360.
echo.
echo Usage:
echo %0 [options] inputfile [outputfile]
echo.
echo Where inputfile is a panorama file from camera,
echo output parameter is optional
goto eof

:NOFFMPEG
echo ffmpeg was not found in %FFMPEGPATH%, download from: https://ffmpeg.zeranoe.com/builds/
echo and unpack to program files directory
goto eof

:FFMPEGERROR
echo ffmpeg failed, video not created
goto eof

:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)

exit /b 0

:eof
