:<<"::IGNORE_THIS_LINE"
@ECHO OFF
GOTO :CMDSCRIPT
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
PTOTMPL="$DIR/gear360tmpl.pto"
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

# Do stuff to make this thing run on various POSIX operating systems
# http://stackoverflow.com/questions/3466166/how-to-check-if-running-in-cygwin-mac-or-linux
os_check() {
    case "$(uname -s)" in

    Darwin)
        ;;

    Linux)
        ;;

    CYGWIN*|MINGW32*|MSYS*)
        # Naive approach, should read Hugin installation
        # path from registry or something...
        export PATH=$PATH:"/cygdrive/c/Program Files (x86)/Hugin/bin":"/cygdrive/c/Program Files/Hugin/bin"
        ;;
    *)
        ;;
    esac
}

# Check argument(s)
if [ -z "$1" ]; then
    echo "Small script to stitch raw panorama files."
    echo "Raw meaning two fisheye images side by side."
    echo -e "Script originally writen for Samsung Gear 360.\n"
    echo -e "Usage:\n$0 inputfile [outputfile]\n"
    echo "Where inputfile is a panorama file from camera,"
    echo "output parameter is optional."
    exit 1
fi

# Output name as second argument
if [ -z "$2" ]; then
    #The output needs to be done in the folder of the original file if used via nautlius open-with
    OUTNAME=`dirname "$1"`/`basename "${1%.*}"`_pano.jpg
fi

# OS check, custom settings for various OSes
os_check

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

set HUGINPATH1=c:/Program Files/Hugin/bin
set HUGINPATH2=c:/Program Files (x86)/Hugin/bin
set PTOTMPL="%~dp0/gear360tmpl.pto"
set OUTTMPNAME="out"
set OUTNAME=%2
set JPGQUALITY=97
set PTOJPGFILENAME="dummy.jpg"

:: Check arguments
IF [%1] == [] GOTO NOARGS

:: Check if second argument present, if not, set some default for output filename
IF NOT [%2] == [] GOTO SETNAMEOK
set OUTNAME="%~n1_pano.jpg"

:SETNAMEOK

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
if %ERRORLEVEL% EQU 1 GOTO NONAERROR

echo Stitching input images (enblend)
"%HUGINPATH1%/enblend.exe" -o %OUTNAME% --compression=jpeg:%JPGQUALITY% %TEMP%/%OUTTMPNAME%0000.tif %TEMP%/%OUTTMPNAME%0001.tif
if %ERRORLEVEL% EQU 1 GOTO ENBLENDERROR

echo Panorama written to %OUTNAME%
goto END

:NOARGS

echo Small script to stitch raw panorama files.
echo Raw meaning two fisheye images side by side.
echo Script originally writen for Samsung Gear 360.
echo.
echo Usage:
echo %0 inputfile [outputfile]
echo.
echo Where inputfile is a panorama file from camera,
echo output parameter is optional
goto END

:NOHUGIN

echo Hugin is not installed or installed in non-standard directory
goto END

:NONAERROR

echo Nona failed, panorama not created
goto END

:ENBLENDERROR

echo Enblend failed, panorama not created
goto END

:END
