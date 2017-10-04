:<<"::IGNORE_THIS_LINE"
@echo off
goto :CMDSCRIPT
::IGNORE_THIS_LINE

# This is a small script to stitch panorama images produced  by Samsung Gear360
#
# https://github.com/ultramango/gear360pano
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
SCRIPTNAME=$0
OUTDIR="$DIR/html/data"
OUTTMPNAME="out"
PTOTMPL_SM_C200="$DIR/gear360sm-c200.pto"
PTOTMPL_SM_R210="$DIR/gear360sm-r210.pto"
JPGQUALITY=97
PTOJPGFILENAME="dummy.jpg"
GALLERYDIR="html"
# Note, this file is inside GALLERYDIR
GALLERYFILELIST="filelist.txt"
# By default we will ignore files that have been processed
IGNOREPROCESSED="yes"
# Default blending program
BLENDPROG="enblend"
# Default - we use GPU
EXTRANONAOPTIONS="-g"
EXTRAENBLENDOPTIONS="--gpu"
# Debug, yes - print debug, empty - no debug
DEBUG="no"

# Debug, arguments:
# 1. Text to print
print_debug() {
  if [ "$DEBUG" == "yes" ]; then
    echo "DEBUG: $@"
  fi
}

# Clean-up function
clean_up() {
  if [ -d "$TEMPDIR" ]; then
    rm -rf "$TEMPDIR"
  fi
}

# Function to check if a command fails, arguments:
# - command to execute
# Source:
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
run_command() {
  # Remove empty arguments (it will confuse the executed command)
  cmd=("$@")
  local i
  for i in "${!cmd[@]}"; do
    [ -n "${cmd[$i]}" ] || unset "cmd[$i]"
  done

  print_debug "Running command: " "${cmd[@]}"
  "${cmd[@]}"

  local status=$?
  if [ $status -ne 0 ]; then
    echo "Error while running $1" >&2
    if [ $1 != "notify-send" ]; then
      # Display error in a nice graphical popup if available
      run_command notify-send -a $SCRIPTNAME "Error while running $1"
    fi
    clean_up
    exit 1
  fi
  return $status
}

# Function that processes panorama, arguments:
# 1. input filename
# 2. output filename
# 3. template filename
process_panorama() {
  print_debug "process_panorama()"
  print_debug "Args: $@"
  # Create temporary directory
  if [ -n "$TEMPDIRPREFIX" ]; then
    TEMPDIR=`mktemp -d -p $TEMPDIRPREFIX`
  else
    TEMPDIR=`mktemp -d`
  fi

  print_debug "process_panorama: args: in: $1, out: $2, tmpl: $3, tempdir: ${TEMPDIR}"

  # Stitch panorama (same file twice as input)
  echo "Processing input images (nona)"
  # We need to use run_command with many parameters, or $1 doesn't get
  # quoted correctly and we cannot use filenames with spaces
  run_command  "nona" \
               "$EXTRANONAOPTIONS" \
               "-o" "$TEMPDIR/$OUTTMPNAME" \
               "-m" "TIFF_m" \
               "-z" "LZW" \
               "$3" \
               "$1" \
               "$1"

  echo "Stitching input images"

  # TODO: possibly some clean up in extra arguments handling
  if [ "$BLENDPROG" == "multiblend" ]; then
    # Note, there's a weird bug that multiblend will use
    # one space character to separate argument
    EXTRABLENDOPTS="--quiet"
  fi

  # Add extra options for enblend (ex. gpu)/tmp/tmp.ctzbeoCfIn
  if [ "$BLENDPROG" == "enblend" ]; then
    EXTRABLENDOPTS="$EXTRAENBLENDOPTIONS"
  fi

  run_command "$BLENDPROG" \
              "$EXTRABLENDOPTS" \
              "--compression=$JPGQUALITY" \
              "-o" "$2" \
              "$TEMPDIR/${OUTTMPNAME}0000.tif" \
              "$TEMPDIR/${OUTTMPNAME}0001.tif"

  # TODO: not sure about the tag exclusion list...
  # Note: there's no check as exiftool is needed by Hugin
  IMG_WIDTH=7776
  IMG_HEIGHT=3888
  echo "Setting EXIF data (exiftool)"
  run_command "exiftool" "-ProjectionType=equirectangular" \
              "-q" \
              "-m" \
              "-TagsFromFile" "$1" \
              "-exif:all" \
              "-ExifByteOrder=II" \
              "-FullPanoWidthPixels=$IMG_WIDTH" \
              "-FullPanoHeightPixels=$IMG_HEIGHT" \
              "-CroppedAreaImageWidthPixels=$IMG_WIDTH" \
              "-CroppedAreaImageHeightPixels=$IMG_HEIGHT" \
              "-CroppedAreaLeftPixels=0" \
              "-CroppedAreaTopPixels=0" \
              "--FocalLength" \
              "--FieldOfView" \
              "--ThumbnailImage" \
              "--PreviewImage" \
              "--EncodingProcess" \
              "--YCbCrSubSampling" \
              "--Compression" \
              "$2"

  # Problems with "-delete_original!", manually remove the file
  rm ${2}_original

  # Clean up any files/directories we created on the way
  clean_up
}

print_help() {
  echo -e "\nSmall script to stitch raw panorama files."
  echo "Raw meaning two fisheye images side by side."
  echo -e "Script originally writen for Samsung Gear 360.\n"
  echo -e "Usage:\n$0 [options] infile [hugintemplate]\n"
  echo "Where infile is a panorama file from camera, it can"
  echo -e "be a wildcard (ex. *.JPG). hugintemplate is optional.\n"
  echo "Panorama file will be written to a file with appended _pano,"
  echo -e "example: 360_010.JPG -> 360_010_pano.JPG\n"
  echo "-a|--process-all force panorama processing, by default processed"
  echo "             panoaramas are skipped (in output directory)"
  echo "-g|--gallery update gallery file list"
  echo "-m|--multiblend use multiblend (http://horman.net/multiblend/)"
  echo "             instead of enblend for final stitching"
  echo "-n|--no-gpu  do not use GPU (safer but slower)"
  echo "-o|--output  DIR will set the output directory of panoramas"
  echo "             default: html/data"
  echo "-q|--quality QUALITY will set the JPEG quality to quality"
  echo "-r|--remove  remove source file after processing (use with care)"
  echo "-t|--temp DIR set temporary directory (default: use system's"
  echo "             temporary directory)"
  echo "-h|--help    prints this help"
}

create_gallery() {
  GALLERYFILELISTFULL="${GALLERYDIR}/${GALLERYFILELIST}"
  echo "Updating gallery file list in ${GALLERYFILELISTFULL}"
  ls -l *.mp4 *_pano.jpg > ${GALLERYFILELISTFULL}
}

# Source (modified)
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  -q|--quality)
    JPGQUALITY="$2"
    # Two shifts because there's no shift in the loop
    # otherwise we can't handle just "-h" option
    shift
    shift
    ;;
  -h|--help)
    print_help
    shift
    exit 0
    ;;
  -o|--output)
    OUTDIR="$2"
    if [ ! -d "$2" ]; then
      echo "Given output ($2) is not a directory, cannot continue"
      exit 1
    fi
    shift
    shift
    ;;
  -g|--gallery)
    CREATEGALLERY="yes"
    shift
    ;;
  -a|--process-all)
    IGNOREPROCESSED="no"
    shift
    ;;
  -t|--temp)
    if [ -d "$2" ]; then
      TEMPDIRPREFIX="$2"
    else
      echo "Given temporary ($2) is not a directory, using system default"
    fi
    shift
    shift
    ;;
  -m|--multiblend)
    BLENDPROG="multiblend"
    shift
    ;;
  -n|--no-gpu)
    # Clear use GPU options
    EXTRANONAOPTIONS=""
    EXTRAENBLENDOPTIONS=""
    shift
    ;;
  -r|--remove)
    # Remove source file after processing
    print_debug "Will remove source file after processing"
    REMOVESOURCE=1
    shift
    ;;
  *)
    break
    ;;
esac
done

# Check argument(s)
if [ -z "${1+x}" ]; then
  print_help
  exit 1
fi

# Check if we have the software to do it (Hugin, ImageMagick)
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
type nona >/dev/null 2>&1 || { echo >&2 "Hugin required but it's not installed. Aborting."; exit 1; }

STARTTS=`date +%s`

# Warn early about the gallery
if [ "$CREATEGALLERY" == "yes" ] && [ "$OUTDIR" != "html/data" ] && [ "$OUTDIR" != "./html/data" ]; then
  echo -e "\nGallery file list will be updated but output directory not set to html/data\n"
fi

# TODO: add option for parallel
for panofile in $1
do
  OUTNAMEPROTO=`dirname "$panofile"`/`basename "${panofile%.*}"`_pano.jpg
  OUTNAME=`basename $OUTNAMEPROTO`
  OUTNAMEFULL=$OUTDIR/$OUTNAME

  # Check if this already processed panorama
  # https://stackoverflow.com/questions/229551/string-contains-in-bash
  if [ $IGNOREPROCESSED == "yes" ] && [ -e "$OUTNAMEFULL" ]; then
    echo "$panofile already processed, skipping... (override with -a)"
    continue
  fi

  # Is ther a pto override?
  if [ -n "$2" ]; then
    PTOTMPL="$2"
  else
    # Detect camera model for each image
    CAMERAMODEL=`exiftool -s -s -s -Model $panofile`
    print_debug "Camera model: $CAMERAMODEL"
    case $CAMERAMODEL in
      SM-C200)
        PTOTMPL=$PTOTMPL_SM_C200
        ;;
      SM-R210)
        PTOTMPL=$PTOTMPL_SM_R210
        ;;
      *)
        PTOTMPL=$PTOTMPL_SM_C200
        ;;
    esac
  fi

  echo "Processing panofile: $panofile"
  process_panorama $panofile $OUTNAMEFULL $PTOTMPL

  if [ ! -z "${REMOVESOURCE+x}" ]; then
    echo "Removing: $panofile"
    rm $panofile
  fi
done

if [ "$CREATEGALLERY" == "yes" ]; then
  # This could be a bit more elegant, but this is the easiest
  cd $GALLERYDIR
  COUNT=`cat $GALLERYFILELIST | wc -l`
  echo "Updating gallery file list, old file count: $COUNT"
  find data -type f -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.mp4" > $GALLERYFILELIST
  COUNT=`cat $GALLERYFILELIST | wc -l`
  echo "New file count: $COUNT"
  cd ..
fi

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo "Processing took: $RUNTIME s"
echo "Processed file(s) are in $OUTDIR"

# Uncomment this if you don't do videos; otherwise, it is quite annoying
#notify-send "Panorama written to $OUTNAME, took: $RUNTIME s"
exit 0

################################ Windows part here

:CMDSCRIPT

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
rem Debug enable ("yes")/disable
set DEBUG=""

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
if "%_TMP%" == "" goto PARAMDONE
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
  if %PARAMCOUNT% EQU 0 (
    rem call :PRINT_DEBUG Input file: %_TMP%
    set PROTOINNAME=%_TMP%
  )
  if %PARAMCOUNT% EQU 1 (
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
echo Was looking in: %HUGINPATH%
echo and: %HUGINPATH32%
goto eof

:NOBLEND
echo.
echo Could not find requested blending program:
echo %HUGINPATH%\%BLENDPROG%
echo Please install missing software
goto eof

:NONAERROR
echo nona failed, panorama not created
goto eof

:ENBLENDERROR
echo enblend failed, panorama not created
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
                            -m ^
                            -q ^
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
                            --Compression "%LOCALOUTNAME%"
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
