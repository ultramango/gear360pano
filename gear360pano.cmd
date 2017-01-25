:<<"::IGNORE_THIS_LINE"
@echo off
goto :CMDSCRIPT
::IGNORE_THIS_LINE

# This is a small script to stitch panorama images produced
# by Samsung Gear360
#
# TODOs:
# - Windows command script part could have a better coding style
# - vignetting correction is not there yet
# - could add some parameters for output, jpeg quality, etc.
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
PTOTMPL=$3
OUTTMPNAME="out"
OUTNAME=$2
JPGQUALITY=97
PTOJPGFILENAME="dummy.jpg"

# Clean-up function
clean_up() {
    if [ -d "$TEMPDIR" ]; then
        rm -rf "$TEMPDIR"
    fi
}

# Function to check if a command fails
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
run_command() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error while running $1" >&2
        if [ $1 != "notify-send" ]; then 
            # Display error in a nice graphical popup if available
            run_command notify-send "Error while running $1"
        fi 
        clean_up
        exit 1
    fi
    return $status
}

# Check argument(s)
if [ -z "$1" ]; then
    echo "Small script to stitch raw panorama files."
    echo "Raw meaning two fisheye images side by side."
    echo -e "Script originally writen for Samsung Gear 360.\n"
    echo -e "Usage:\n$0 inputfile [outputfile] [hugintemplate]\n"
    echo "Where inputfile is a panorama file from camera,"
    echo "output parameter and hugintemplate are optional."
    exit 1
fi

# Output name as second argument
if [ -z "$2" ]; then
    # The output needs to be done in the folder of the original file if used via nautlius open-with
    OUTNAME=`dirname "$1"`/`basename "${1%.*}"`_pano.jpg
fi

# Template to use as third argument
if [ -z "$3" ]; then
    # Assume default template
    PTOTMPL="$DIR/gear360tmpl.pto"
fi

# Check if we have the software to do it (Hugin, ImageMagick)
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
type nona >/dev/null 2>&1 || { echo >&2 "Hugin required but it's not installed. Aborting."; exit 1; }

# Create temporary directory locally to stay compatible with other OSes
# Not using '-p .' might cause some problems on non-unix systems (cygwin?)
TEMPDIR=`mktemp -d`

STARTTS=`date +%s`
# Stitch panorama (same file twice as input)
echo "Processing input images (nona)"
# We need to use run_command with many parameters, or $1 doesn't get
# quoted correctly and we cannot use filenames with spaces
run_command  "nona" "-o" "$TEMPDIR/$OUTTMPNAME" \
             "-m" "TIFF_m" \
             "-z" "LZW" \
             $PTOTMPL \
             "$1" \
             "$1"

echo "Stitching input images (enblend)"
# We need to use run_command with many parameters,
# or the directories don't get quoted correctly
run_command "enblend" "-o" "$OUTNAME" \
            "--compression=jpeg:$JPGQUALITY" \
            "$TEMPDIR/${OUTTMPNAME}0000.tif" \
            "$TEMPDIR/${OUTTMPNAME}0001.tif"

# TODO: not sure about the tag exclusion list...
# Note: there's no check as exiftool is needed by Hugin
echo "Setting EXIF data (exiftool)"
run_command "exiftool" "-ProjectionType=equirectangular" \
            "-q" \
            "-m" \
            "-TagsFromFile" "$1" \
            "-exif:all" \
            "--FocalLength" \
            "--FieldOfView" \
            "--ThumbnailImage" \
            "--PreviewImage" \
            "--EncodingProcess" \
            "--YCbCrSubSampling" \
            "--Compression" \
            "$OUTNAME"

# Problems with "-delete_original!", manually remove the file
rm ${OUTNAME}_original

# Clean up any files/directories we created on the way
clean_up

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo Panorama written to $OUTNAME, took: $RUNTIME s

# Uncomment this if you don't do videos; otherwise, it is quite annoying
#notify-send "Panorama written to $OUTNAME, took: $RUNTIME s"
exit 0

################################ Windows part here

:CMDSCRIPT

:: http://stackoverflow.com/questions/673523/how-to-measure-execution-time-of-command-in-windows-command-line
set start=%time%

set HUGINPATH1=c:/Program Files/Hugin/bin
set HUGINPATH2=c:/Program Files (x86)/Hugin/bin
set PTOTMPL=%3
set OUTTMPNAME="out"
set OUTNAME=%2
set JPGQUALITY=97
set PTOJPGFILENAME="dummy.jpg"

:: Check arguments
if [%1] == [] goto NOARGS

:: Check if second argument present, if not, set some default for output filename
if not [%2] == [] goto SETNAMEOK
set OUTNAME="%~n1_pano.jpg"

:SETNAMEOK

:: Third argument as Hugin template
if not [%3] == [] goto SETTMPLOK
set PTOTMPL="%~dp0/gear360tmpl.pto"

:SETTMPLOK

:: Where's enblend? Prefer 64 bits
if exist "%HUGINPATH1%/enblend.exe" goto HUGINOK
:: 64 bits not found? Check x86
if not exist "%HUGINPATH2%/enblend.exe" goto NOHUGIN
:: Found x86, overwrite original path
set HUGINPATH1=%HUGINPATH2%

:HUGINOK

:: Execute commands (as simple as it is)
echo Processing input images (nona)
"%HUGINPATH1%/nona.exe" -o %TEMP%/%OUTTMPNAME% -m TIFF_m -z LZW %PTOTMPL% %1 %1
if %ERRORLEVEL% EQU 1 goto NONAERROR

echo Stitching input images (enblend)
"%HUGINPATH1%/enblend.exe" -o %OUTNAME% --compression=jpeg:%JPGQUALITY% %TEMP%/%OUTTMPNAME%0000.tif %TEMP%/%OUTTMPNAME%0001.tif
if %ERRORLEVEL% EQU 1 goto ENBLENDERROR

:: Check if we have exiftool...
echo Setting EXIF data (exiftool)
"%HUGINPATH1%/exiftool.exe" -ProjectionType=equirectangular -m -q -TagsFromFile %1 -exif:all --FocalLength --FieldOfView --ThumbnailImage --PreviewImage --EncodingProcess --YCbCrSubSampling --Compression %OUTNAME%
if %ERRORLEVEL% EQU 1 echo Setting EXIF failed, ignoring

:: There are problems with -delete_original in exiftool, manually remove the file
del %OUTNAME%_original

:: Time calculation
set end=%time%
set options="tokens=1-4 delims=:.,"
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

:: mission accomplished
set /a totalsecs = %hours%*3600 + %mins%*60 + %secs%

echo Panorama written to %OUTNAME%, took: %totalsecs% s

goto END

:NOARGS

echo Script to stitch raw panorama files, raw meaning
echo two fisheye images side by side.
echo.
echo Script originally writen for Samsung Gear 360.
echo.
echo Usage:
echo %0 inputfile [outputfile] [hugintemplate]
echo.
echo Where inputfile is a panorama file from camera,
echo output and hugintemplate are optional
goto END

:NOHUGIN

echo Hugin is not installed or installed in non-standard directory
goto END

:NONAERROR

echo nona failed, panorama not created
goto END

:ENBLENDERROR

echo enblend failed, panorama not created
goto END

:END
