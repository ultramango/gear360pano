#!/usr/bin/env bash

# This is a small script to stitch panorama images produced  by Samsung Gear360
# Could be adopted to use with other cameras after creating pto file
# (Hugin template)
#
# https://github.com/ultramango/gear360pano


# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
WHICH=`which $0`
DIR=$(dirname `readlink -f $WHICH`)

SCRIPTNAME=$0
GALLERYDIR="html"
OUTDIR="$DIR/$GALLERYDIR/data"
OUTTMPNAME="out"
PTOTMPL_SM_C200="$DIR/gear360sm-c200.pto"
PTOTMPL_SM_R210="$DIR/gear360sm-r210.pto"
JPGQUALITY=97
PTOJPGFILENAME="dummy.jpg"
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
  rm -rf "$TEMPDIR"
}

# Function to check if a command fails, arguments:
# - command to execute
# Source:
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
run_command() {
  print_debug "run_command()"

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

  # Add extra options for enblend (ex. gpu)
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
  # Note: there's no check for exiftool as it is included with Hugin
  IMG_WIDTH=$(exiftool -s -s -s -ImageWidth $1)
  IMG_HEIGHT=$(exiftool -s -s -s -ImageHeight $1)
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

# Process arguments. Source (modified):
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  -a|--process-all)
    IGNOREPROCESSED="no"
    shift
    ;;
  -g|--gallery)
    CREATEGALLERY="yes"
    shift
    ;;
  -h|--help)
    print_help
    shift
    exit 0
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
  -o|--output)
    OUTDIR="$2"
    if [ ! -d "$2" ]; then
      echo "Given output ($2) is not a directory, cannot continue"
      exit 1
    fi
    shift
    shift
    ;;
  -q|--quality)
    JPGQUALITY="$2"
    # Two shifts because there's no shift in the loop
    # otherwise we can't handle just "-h" option
    shift
    shift
    ;;
  -r|--remove)
    # Remove source file after processing
    print_debug "Will remove source file after processing"
    REMOVESOURCE=1
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
type nona >/dev/null 2>&1 || { echo >&2 "Hugin required but it is not installed. Aborting."; exit 1; }

STARTTS=`date +%s`

# Warn early about the gallery if the output directory is somewhere else
if [ "$CREATEGALLERY" == "yes" ] && [ "$OUTDIR" != "html/data" ] && [ "$OUTDIR" != "./html/data" ]; then
  echo -e "\nGallery file list will be updated but output directory not set to html/data\n"
fi

# TODO: add option for parallel
for panofile in $1
do
  OUTNAMEPROTO=`dirname "$panofile"`/`basename "${panofile%.*}"`_pano.jpg
  OUTNAME=`basename $OUTNAMEPROTO`
  OUTNAMEFULL=$OUTDIR/$OUTNAME

  # Skip if this is already processed panorama
  # https://stackoverflow.com/questions/229551/string-contains-in-bash
  if [ $IGNOREPROCESSED == "yes" ] && [ -e "$OUTNAMEFULL" ]; then
    echo "$panofile already processed, skipping... (override with -a)"
    continue
  fi

  # Is there a pto override (second argument)?
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
    print_debug "PTO file: $PTOTMPL"
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
