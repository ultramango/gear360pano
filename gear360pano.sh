#!/usr/bin/env bash

# This is a small script to stitch panorama images produced
# by Samsung Gear360
#
# Process is simple: cut in half and stitch using Hugin template.
#
# TODOs:
# - vignetting correction is not there yet
# - could add some parameters for output, jpeg quality, etc.

PTOTMPL="gear360tmpl.pto"
SPLITNAME="split-"
OUTTMPNAME="out"
OUTNAME=`basename "${1%.*}"`_pano.jpg
JPGQUALITY=97

# Clean-up function
function clean_up {
    if [ -d "$TEMPDIR" ]; then
        rm -rf "$TEMPDIR"
    fi
}

# Function to check if a command fails
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
function run_command {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error when running $1" >&2
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
    echo "Provide panorama file as argument."
    exit 1
fi

# OS check, custom settings for various OSes
os_check

# Check if we have the software to do it (Hugin, ImageMagick)
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
type convert >/dev/null 2>&1 || { echo >&2 "I require ImageMagick but it's not installed. Aborting."; exit 1; }
type nona >/dev/null 2>&1 || { echo >&2 "I require Hugin but it's not installed. Aborting."; exit 1; }

# Create temporary directory locally to stay compatible with other OSes
TEMPDIR=`mktemp -d -p .`
STARTTS=`date +%s`

# Split the panorama in two
echo Splitting input image
cmd="convert $1 -compress lzw -crop 50%x100% +repage +adjoin $TEMPDIR/${SPLITNAME}%d.tif"
run_command $cmd

# Stitch panorama
echo Processing input images
cmd="nona -o $TEMPDIR/$OUTTMPNAME \
     -m TIFF_m \
     -z LZW \
     $PTOTMPL \
     $TEMPDIR/${SPLITNAME}0.tif \
     $TEMPDIR/${SPLITNAME}1.tif"
run_command $cmd

echo Stiching input images
cmd="enblend -o $OUTNAME \
     --compression=jpeg:$JPGQUALITY \
     $TEMPDIR/${OUTTMPNAME}0000.tif \
     $TEMPDIR/${OUTTMPNAME}0001.tif"
run_command $cmd
        
# Remove temporary directory
clean_up

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo Panorama written to $OUTNAME, took: $RUNTIME s
