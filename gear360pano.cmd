@echo off

rem This is a small script to stitch panorama images produced  by Samsung Gear360
rem Could be adopted to use with other cameras after creating pto file (Hugin
rem template)
rem
rem https://github.com/ultramango/gear360pano

rem http://stackoverflow.com/questions/673523/how-to-measure-execution-time-of-command-in-windows-command-line
set start=%time%
set HUGINPATH=C:\Program Files\Hugin\bin
set HUGINPATH32=C:\Program Files (x86)\Hugin\bin
set GALLERYDIR=html
set GALLERYFILELIST=filelist.txt
rem This is to avoid some weird bug (???) %~dp0 doesn't work in a loop (effect of shift?)
set SCRIPTNAME=%0
set SCRIPTPATH=%~dp0
set OUTTMPNAME=out
set PTOTMPL_SM_C200="%SCRIPTPATH%gear360sm-c200.pto"
set PTOTMPL_SM_R210="%SCRIPTPATH%gear360sm-r210.pto"
set INNAME=
set PTOTMPL=
set OUTDIR=%SCRIPTPATH%html\data
set JPGQUALITY=97
set PTOJPGFILENAME=dummy.jpg
set IGNOREPROCESSED=yes
rem Default temporary directory
set MYTEMPDIR=%TEMP%
rem We define default here
set BLENDPROG=enblend.exe
set MULTIBLENDEXE=multiblend_x64.exe
rem By default use gpu
set EXTRANONAOPTIONS="-g"
set EXTRAENBLENDOPTIONS="--gpu"
rem Should we remove source file?
set REMOVESRCFILE=no
rem Debug enable ("yes")/disable
set DEBUG=""
set EXITCODE=0

rem Process arguments
set PARAMCOUNT=0
rem We need this due to stupid parameter substitution
setlocal enabledelayedexpansion
:PARAMLOOP
rem Small hack as substring doesn't work on %1 (need to use delayed sub.?)
set _TMP=%1
set FIRSTCHAR=%_TMP:~0,1%
rem No arguments?
rem call :PRINT_DEBUG Current arg: %_TMP%
if '%_TMP%' == '' goto PARAMDONE
rem This is to fix weird "bug" when passing quoted files
rem https://stackoverflow.com/questions/31358869/problems-checking-if-string-is-quoted-and-adding-quotes-to-string
if !_TMP:~0^,1!!_TMP:~-1! equ "" set FIRSTCHAR="x"
rem Process arguments
if "%FIRSTCHAR%" == "/" (
  set SWITCH=!_TMP:~1,2!
  rem call :PRINT_DEBUG Current switch: !SWITCH!
  rem Switch processing
  if /i "!SWITCH!" == "q" (
    shift
    rem call :PRINT_DEBUG Setting JPEG quality to: %2
    rem shift has no effect (delayed expansion not working on %1?) we have to use %2
    set JPGQUALITY=%2
  )
  if /i "!SWITCH!" == "h" (
    rem call :PRINT_DEBUG Printing help
    goto NOARGS
  )
  if /i "!SWITCH!" == "o" (
    shift
    rem call :PRINT_DEBUG Setting output directory to: %2
    set OUTDIR=%2
  )
  if /i "!SWITCH!" == "g" (
    rem call :PRINT_DEBUG Will update gallery panorama list file
    set CREATEGALLERY=yes
  )
  if /i "!SWITCH!" == "a" (
    rem call :PRINT_DEBUG Forcing processing of all files
    set IGNOREPROCESSED=no
  )
  if /i "!SWITCH!" == "t" (
    shift
    rem call :PRINT_DEBUG Setting temporary dir: %2
    if not exist "%2" (
      echo Directory "%2" does not exist, using system default
    ) else (
      set MYTEMPDIR=%2
    )
  )
  if /i "!SWITCH!" == "r" (
    rem call :PRINT_DEBUG Will remove source file(s)
    set REMOVESRCFILE=yes
  )
  if /i "!SWITCH!" == "m" (
    rem call :PRINT_DEBUG Using multiblend as blending program
    set BLENDPROG=%MULTIBLENDEXE%
  )
  if /i "!SWITCH!" == "n" (
    rem call :PRINT_DEBUG Disabling GPU usage
    rem Clear any options enabling usage of gpu
    set EXTRANONAOPTIONS=
    set EXTRAENBLENDOPTIONS=
  )
) else (
  if !PARAMCOUNT! EQU 0 (
    rem call :PRINT_DEBUG Input file: %_TMP%
    set PROTOINNAME=%_TMP%
  )
  if !PARAMCOUNT! EQU 1 (
    rem call :PRINT_DEBUG Setting PTO: %_TMP%
    set PTOTMPL=%_TMP%
  )
  set /a PARAMCOUNT+=1
)
shift & goto PARAMLOOP
:PARAMDONE

rem Check arguments and assume defaults
if "%PROTOINNAME%" == "" goto NOARGS

rem Where's Hugin? Prefer 64 bits
rem Haha, weird bug, it doesn't work when using brackets (spaces in path)
if exist "%HUGINPATH%/nona.exe" goto HUGINOK
rem 64 bits not found? Check x86
if not exist "%HUGINPATH32%/nona.exe" goto NOHUGIN
rem Found x86, overwrite original path
set HUGINPATH=%HUGINPATH32%
:HUGINOK
rem Check blending software (now it can be different)
if "%BLENDPROG%" == "%MULTIBLENDEXE%" if not exist "%HUGINPATH%/%BLENDPROG%" goto NOBLEND

rem Warn early about the gallery
if "%CREATEGALLERY%" == "yes" if not "%OUTDIR%" == "html\data" (
  if /i not "%OUTDIR%" == "html\data" (
    echo.
    echo Gallery file list will be updated but output directory is not set to html\data
    echo.
  )
)

rem Loop over input files
for %%f in (%PROTOINNAME%) do (
  set INNAME=%%f
  set OUTNAME=%OUTDIR%\%%~nf_pano.jpg

  rem Why a flag? No continue for "for", use goto, labels
  rem inside for break the loop, use if and "and/or", doesn't
  rem work (can't use poorman's and - double if)
  set PROCESSFILE=yes

  rem Check if this file was already processed
  if "%IGNOREPROCESSED%" == "yes" if exist "!OUTNAME!" (
    rem Can't use brackets for "override with /a" - breaks stuff
    echo File !INNAME! already processed, skipping... override with /a
    set PROCESSFILE=no
  )

  if "!PROCESSFILE!" == "yes" (
    "%HUGINPATH%/exiftool.exe" -s -s -s -Model !INNAME! > modelname.tmp
    set /p MODELNAME=<modelname.tmp
    del modelname.tmp
    rem This is default
    set LOCALPTOTMPL=%PTOTMPL_SM_C200%
    if "!PTOTMPL!" == "" (
      rem call :PRINT_DEBUG Detected model: !MODELNAME!
      if "!MODELNAME!" == "SM-C200" set LOCALPTOTMPL=%PTOTMPL_SM_C200%
      if "!MODELNAME!" == "SM-R210" set LOCALPTOTMPL=%PTOTMPL_SM_R210%
    ) else (
      rem call :PRINT_DEBUG Using command line PTO: !PTOTMPL!
      set LOCALPTOTMPL=!PTOTMPL!
    )

    echo Processing file: !INNAME!
    call :PROCESSPANORAMA !INNAME! !OUTNAME! !LOCALPTOTMPL!

    if "%REMOVESRCFILE%" == "yes" (
      rem call :PRINT_DEBUG Removing source file: !INNAME!
      del !INNAME!
    )
  )
)

if "%CREATEGALLERY%" == "yes" (
  rem This could be a bit more elegant, but this is the easiest
  cd $GALLERYDIR
  echo Updating gallery file list
  rem Yep, repetition...
  rem https://superuser.com/questions/1029558/list-files-in-a-subdirectory-and-get-relative-paths-only-with-windows-command-li
  for %%X IN ('data') DO FOR /F "TOKENS=*" %%F IN (
    'dir /B /A-D ".\%%~X\*.jpg"'
  ) do echo .\%%~X\%%~F > "%GALLERYFILELIST%"
  for %%X IN ('data') DO FOR /F "TOKENS=*" %%F IN (
    'dir /B /A-D ".\%%~X\*.jpeg"'
  ) do echo .\%%~X\%%~F >> "%GALLERYFILELIST%"
  for %%X IN ('data') DO FOR /F "TOKENS=*" %%F IN (
    'dir /B /A-D ".\%%~X\*.mp4"'
  ) do echo .\%%~X\%%~F >> "%GALLERYFILELIST%"
  cd ..
)

rem Time calculation
set end=%time%
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

echo Processing took: %totalsecs% s
echo Processed files are in %OUTDIR%

goto eof

:NOARGS

echo.
echo Script to stitch raw panorama files.
echo Raw meaning two fisheye images side by side.
echo Script originally writen for Samsung Gear 360.
echo.
echo Usage:
echo %SCRIPTNAME% [options] infile [hugintemplate]
echo.
echo Where infile is a panorama file from camera, it can
echo be a wildcard (ex. *.JPG). hugintemplate is optional.
echo.
echo Panorama will be written to a file with appended _pano,
echo example: 360_010.JPG -> 360_010_pano.JPG
echo.
echo /a process all files, by default already processed images
echo    are ignored (in output directory)
echo /g update gallery file list
echo /m use multiblend (http://horman.net/multiblend/) instead
echo    of enblend for final image stitching
echo /o sets output directory for stitched panoramas
echo    default: html\data
echo /q sets output jpeg quality
echo /t sets temporary directory (default: use systems' default
echo    temporary directory)
echo /h prints this help
echo.
goto eof

:NOHUGIN
echo.
echo Hugin is not installed or installed in non-standard directory
echo Download and install Hugin from: http://hugin.sourceforge.net/
echo Was looking in: %HUGINPATH%
echo and: %HUGINPATH32%
set EXITCODE=1
goto eof

:NOBLEND
echo.
echo Could not find requested blending program:
echo %HUGINPATH%\%BLENDPROG%
echo Please install missing software
set EXITCODE=1
goto eof

:NONAERROR
echo nona failed, panorama not created
set EXITCODE=1
goto eof

:ENBLENDERROR
echo enblend failed, panorama not created
set EXITCODE=1
goto eof

rem Function to stich panorama, parameters:
rem 1: input (two fisheye)
rem 2: output filename
rem 3: pto (Hugin template) file to use
:PROCESSPANORAMA
set LOCALINNAME=%1
set LOCALOUTNAME=%2
set LOCALPTOTMPL=%3

rem Execute commands (as simple as it is)
echo Processing input images (nona)
rem call :PRINT_DEBUG Extra nona options: %EXTRANONAOPTIONS%
rem call :PRINT_DEBUG Output: %MYTEMPDIR%\%OUTTMPNAME%
rem call :PRINT_DEBUG PTO: %LOCALPTOTMPL%
rem call :PRINT_DEBUG Local input: %LOCALINNAME%
"%HUGINPATH%/nona.exe" ^
              %EXTRANONAOPTIONS% ^
              -o %MYTEMPDIR%\%OUTTMPNAME% ^
              -m TIFF_m ^
              -z LZW ^
              %LOCALPTOTMPL% ^
              %LOCALINNAME% ^
              %LOCALINNAME%
if %ERRORLEVEL% equ 1 goto NONAERROR

rem Extra options for multiblend
if "%BLENDPROG%" == "multiblend_x64.exe" (
  set EXTRABLENDOPTS=--quiet
)
rem Add extra options for enblend (ex. gpu)
if "%BLENDPROG%" == "enblend.exe" (
  set EXTRABLENDOPTS=%EXTRAENBLENDOPTIONS%
)

rem call :PRINT_DEBUG Extra blend prog options: %EXTRABLENDOPTS%

echo Stitching input images
"%HUGINPATH%\%BLENDPROG%" ^
              %EXTRABLENDOPTS% ^
              --compression=%JPGQUALITY% ^
              -o %2 ^
              %MYTEMPDIR%\%OUTTMPNAME%0000.tif ^
              %MYTEMPDIR%\%OUTTMPNAME%0001.tif
if %ERRORLEVEL% equ 1 goto ENBLENDERROR

rem Check if we have exiftool...
echo Setting EXIF data (exiftool)
set IMG_WIDTH=7776
set IMG_HEIGHT=3888
"%HUGINPATH%/exiftool.exe" -ProjectionType=equirectangular ^
                            -q ^
                            -m ^
                            -TagsFromFile "%LOCALINNAME%" ^
                            -exif:all ^
                            -ExifByteOrder=II ^
                            -FullPanoWidthPixels=%IMG_WIDTH% ^
                            -FullPanoHeightPixels=%IMG_HEIGHT% ^
                            -CroppedAreaImageWidthPixels=%IMG_WIDTH% ^
                            -CroppedAreaImageHeightPixels=%IMG_HEIGHT% ^
                            -CroppedAreaLeftPixels=0 ^
                            -CroppedAreaTopPixels=0 ^
                            --FocalLength ^
                            --FieldOfView ^
                            --ThumbnailImage ^
                            --PreviewImage ^
                            --EncodingProcess ^
                            --YCbCrSubSampling ^
                            --Compression ^
                            "%LOCALOUTNAME%"
if "%ERRORLEVEL%" EQU 1 echo Setting EXIF failed, ignoring

rem There are problems with -delete_original in exiftool, manually remove the file
del "%LOCALOUTNAME%_original"
exit /b 0

:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b 0

:eof
exit /b %EXITCODE%
