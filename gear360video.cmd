:<<"::IGNORE_THIS_LINE"
@ECHO OFF
GOTO :CMDSCRIPT
::IGNORE_THIS_LINE

# This is a small script to stitch panorama videos produced
# by Samsung Gear360
#
# TODOs:
# - output file name is currently static
# - add check for gear360pano script
# - ffmpeg and jpg or png?
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
# Or dirname `dirname $0`
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Clean-up function
function clean_up {
    echo "Removing temporary directories..."
    if [ -d "FRAMESTMPDIR" ]; then
        rm -rf "FRAMESTMPDIR"
    fi
    if [ -d "OUTTEMPDIR" ]; then
        rm -rf "OUTTEMPDIR"
    fi
}

# Function to check if a command fails
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
function run_command {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error while running $1" >&2
        clean_up
        exit 1
    fi
    return $status
}

# Do stuff to make this thing run on various operating systems
# http://stackoverflow.com/questions/3466166/how-to-check-if-running-in-cygwin-mac-or-linux
function os_check {
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
    echo "Small script to stitch video panorama files."
    echo -e "Script originally writen for Samsung Gear 360.\n"
    echo -e "Usage:\n$0 inputdir [outputfile]\n"
    echo "Where inputfile is a panorama file from camera,"
    echo "output parameter is optional."
    exit 1
fi

# Output name as second argument
if [ -z "$2" ]; then
    OUTNAME=`basename "${1%.*}"`_pano.mp4
    echo "DEBUG: output filename: $OUTNAME"
fi

# OS check, custom settings for various OSes
os_check

# Check if we have the software to do it
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
type ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg required but it's not installed. Aborting."; exit 1; }
# TODO: add check for gear360pano.cmd script

# Create temporary directory locally to stay compatible with other OSes
FRAMESTEMPDIR=`mktemp -d -p .`
OUTTEMPDIR=`mktemp -d -p .`
IMAGETMPL="image%05d.jpg"
STARTTS=`date +%s`

# Stitch panorama (same file twice as input)
echo "Extracting frames from video (this might take a while..."
cmd="ffmpeg -i $1 -vf scale=7776:3888 $FRAMESTEMPDIR/$IMAGETMPL"
run_command $cmd

echo "Stitching frames..."
for i in $FRAMESTEMPDIR/*.jpg; do
    echo Frame: $i
    OUTFILENAME=`basename $i`
    cmd="/bin/bash ./gear360pano.cmd $i $OUTTEMPDIR/$OUTFILENAME"
        run_command $cmd
done

echo "Recoding the video..."
cmd="ffmpeg -f image2 -i $OUTTEMPDIR/$IMAGETMPL -r 30 -s 3840:1920 -vcodec libx264 $OUTNAME"
run_command $cmd
        
# Remove temporary directories
clean_up

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo Video written to $OUTNAME, took: $RUNTIME s

exit 0

################################ Windows part here

:CMDSCRIPT

set FFMPEGPATH=c:/Program Files/ffmpeg/bin
set FRAMESTEMPDIR=frames
set OUTTEMPDIR=frames_stitched
:: %% is an escape character
set IMAGETMPL=image%%05d.jpg

:: Check arguments
IF [%1] == [] GOTO NOARGS

:: Check if second argument present, if not, set some default for output filename
IF NOT [%2] == [] GOTO SETNAMEOK
set OUTNAME="%~n1_pano.mp4"

:SETNAMEOK

:: Where's enblend? Prefer 64 bits
if exist "%FFMPEGPATH%/ffmpeg.exe" goto FFMPEGOK
:: 64 bits not found? Check x86
goto NOFFMPEG

:FFMPEGOK

:: Create temporary directories
mkdir %FRAMESTEMPDIR%
mkdir %OUTTEMPDIR%

:: Execute commands (as simple as it is)
echo Converting video to images...
"%FFMPEGPATH%/ffmpeg.exe" -i %1 -vf scale=7776:3888 %FRAMESTEMPDIR%/%IMAGETMPL%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

:: Stitching
echo Stitching frames...
for %%f in (%FRAMESTEMPDIR%/*.jpg) do (
:: For whatever reason (this has to be at the beginning of the line!)
  echo Processing frame %FRAMESTEMPDIR%\%%f
:: There should be some error checking
  call gear360pano.cmd %FRAMESTEMPDIR%\%%f %OUTTEMPDIR%\%%f
)

"%FFMPEGPATH%/ffmpeg.exe" -f image2 -i %OUTTEMPDIR%/%IMAGETMPL% -r 30 -s 3840:1920 -vcodec libx264 %OUTNAME%
if %ERRORLEVEL% EQU 1 GOTO FFMPEGERROR

:: Clean-up (f - force, read-only & dirs, q - quiet)
del /f /q %FRAMESTEMPDIR%
del /f /q %OUTTEMPDIR%

echo Video written to %OUTNAME%
goto END

:NOARGS

echo Small script to stitch raw video panorama files.
echo Raw meaning two fisheye images side by side.
echo Script originally writen for Samsung Gear 360.
echo.
echo Usage:
echo %0 inputfile [outputfile]
echo.
echo Where inputfile is a panorama file from camera,
echo output parameter is optional
goto END

:NOFFMPEG

echo ffmpeg is found in %FFMPEGPATH%, download from: https://ffmpeg.zeranoe.com/builds/ and
echo unpack to program files directory
goto END

:FFMPEGERROR

echo ffmpeg failed, video not created
goto END

:STITCHINGERROR

echo Stitching failed, video not created
goto END

:END
