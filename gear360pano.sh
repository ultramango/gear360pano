#!/bin/sh

# This is a small script to stich panorams produced by Gear360
# TODOs:
# - vignetting correction is not there yet

PTOTMPL="gear360tmpl.pto"
SPLITNAME="split-"
OUTTMPNAME="out"
OUTNAME=`basename "${1%.*}"`_pano.jpg
JPGQUALITY=97

# Function to check if a command fails
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
function run_command {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error when running $1" >&2
        if [ -d "$TEMPDIR" ]; then
            # Not super elegant, but makes the code cleaner
            rm -rf "$TEMPDIR"
        fi
        exit 1
    fi
    return $status
}

# Check arguments
if [ -z "$1" ]; then
    echo "Provide panorama file as argument."
    exit 1
fi

# Check if we have the software to do it (hugin, imagemagick)
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
type convert >/dev/null 2>&1 || { echo >&2 "I require ImageMagick but it's not installed. Aborting."; exit 1; }
type nona >/dev/null 2>&1 || { echo >&2 "I require Hugin but it's not installed. Aborting."; exit 1; }

# Create temporary directory
TEMPDIR=`mktemp -d`
STARTTS=`date +%s`

# Split the panorama in two
echo Splitting input image
cmd="convert $1 -compress lzw -crop 50%x100% +repage +adjoin $TEMPDIR/${SPLITNAME}%d.tif"
run_command $cmd

# Stich panorama
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
rm -rf "$TEMPDIR"

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo Panorama written to $OUTNAME, took: $RUNTIME s
