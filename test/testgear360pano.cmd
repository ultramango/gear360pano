@echo off

rem Test script for gear360pano.cmd

set FFMPEGPATH=c:\Program Files\ffmpeg\bin
set DEBUG=""

echo Not implemented

:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)

exit /b 0

:eof
