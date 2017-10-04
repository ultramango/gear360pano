:<<"::IGNORE_THIS_LINE"
@echo off
goto :CMDSCRIPT
::IGNORE_THIS_LINE

# Script to stitch panoramic videos produced by Samsung Gear360 (and others?).
#
# For help (hopefully) see:
# https://github.com/ultramango/gear360pano
#
# Names:
# dec, DEC, decoding - means video -> images
# enc, ENC, encoding - means stitched images -> video
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here ################################

#############
### Constants

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
FRAMESTEMPDIRSUFF="frames"
OUTTEMPDIRSUFF="out"
OUTDIR="$DIR/html/data"
# Options, default is the quality option, overridable by speed parameter
FFMPEGQUALITYDEC="-q:v 2"
FFMPEGQUALITYENC="-c:v libx265 -x265-params crf=18"
IMAGETMPLDEC="image%05d.jpg"
IMAGETMPLENC="image%05d_pano.jpg"
PTOTMPL4K="gear360video4k.pto"
PTOTMPL2K="gear360video2k.pto"
# This is a default, it will/should be overwritten anyway
PTOTMPL="$DIR/${PTOTMPL4K}"
TMPAUDIO="tmpaudio.aac"
TMPVIDEO="tmpvideo.mp4"
# Throttle parallel processing to give some room for other processes
# 80% - 0.8 job per core (logical, not physical), 100% one job per core,
# 200% 2 jobs per core, etc. Be careful with >=100% might freeze the machine.
PARALLELTHROTTLE="80%"
# Debug, yes = print debug messages
DEBUG="no"

#############
### Functions

# Debug, arguments:
# 1. Text to print
print_debug() {
  if [ "$DEBUG" == "yes" ]; then
    echo "DEBUG: $@"
  fi
}

# Clean-up function
clean_up() {
  echo "Removing temporary directories..."
  if [ -d "$FRAMESTEMPDIR" ]; then
    print_debug "Removing frames directory: $FRAMESTEMPDIR"
    rm -rf "$FRAMESTEMPDIR"
  fi
  if [ -d "$OUTTEMPDIR" ]; then
    print_debug "Removing output directory: $OUTTEMPDIR"
    rm -rf "$OUTTEMPDIR"
  fi
}

# Function to run a command and check the result
# http://stackoverflow.com/questions/5195607/checking-bash-exit-status-of-several-commands-efficiently
run_command() {
  # Remove empty arguments (it will confuse the executed command)
  local cmd=("$@")
  for i in "${!cmd[@]}"; do
    [ -n "${cmd[$i]}" ] || unset "cmd[$i]"
  done

  print_debug "Running command: " "${cmd[@]}"
  "${cmd[@]}"
  local status=$?
  if [ $status -ne 0 ]; then
    # We failed, inform the user and clean-up
    echo "Error while running $1" >&2
    if [ $1 != "notify-send" ]; then
       # Display error in a nice graphical popup if available
       run_command notify-send -a $0 "Error while running $1"
    fi
    clean_up
    exit 1
  fi
  return $status
}

# Print help for the user
print_help() {
  echo -e "\nSmall script to stitch raw panoramic videos."
  echo "Raw meaning two fisheye images side by side."
  echo -e "Script originally writen for Samsung Gear 360.\n"
  echo -e "Usage:\n$0 [options] infile [outfile]\n"
  echo "Where infile is a panoramic video file, output"
  echo "parameter is optional. Video file will be written"
  echo "to a file with appended _pano, ex.: dummy.mp4 will"
  echo -e "be stitched to dummy_pano.mp4.\n"
  echo "-o|--output DIR will set the output directory of panoramas"
  echo "                default: html/data"
  echo "-p|--parallel   use GNU Parallel to speed-up processing"
  echo "-s|--speed      optimise for speed (lower quality)"
  echo "-t|--temp DIR   set temporary directory (default: system's"
  echo "                temporary directory)"
  echo "-h|--help       prints this help"
}

check_preconditions() {
  # Check if we have the software to do it
  # http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
  local error=0

  type ffmpeg >/dev/null 2>&1 || { echo >&2 "ffmpeg required but it's not installed. Will abort."; error=1; }
  type multiblend >/dev/null 2>&1 || { echo >&2 "multiblend required but it's not installed. Will abort."; error=1; }

  # Use parallel? Check if we have it
  # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
  if [ ! -z "${USEPARALLEL+x}" ]; then
    type parallel >/dev/null 2>&1 || { echo >&2 "GNU Parallel use enabled but it's not installed. Will abort."; error=1; }
  fi

  if [ $error -ne 0 ]; then
    exit 1
  fi
}

######################
### "Main" starts here

# Check required argument(s)
if [ -z "${1+x}" ]; then
  print_help
  run_command notify-send -a $0 "Please provide an input file."
  exit 1
fi

# Process command line options. Source (modified):
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
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
  -p|--parallel)
    # Switch to use parallel
    USEPARALLEL=1
    print_debug "Use of GNU Parallel enabled"
    shift
    ;;
  -t|--temp)
    if [ -d "$2" ]; then
      TEMPDIRPREFIX="$2"
    else
      echo "Given temporary ($2) is not a directory, using default"
    fi
    shift
    shift
    ;;
  -s|--speed)
    FFMPEGQUALITYDEC=""
    FFMPEGQUALITYENC="-vcodec libx264"
    shift
    ;;
  *)
    break
    ;;
esac
done

# Output name as second argument plus output directory
if [ -z "${2+x}" ]; then
  # If invoked by nautilus open-with, we need to remember the proper directory in the outname
  OUTNAME=$OUTDIR/`basename "${1%.*}"`_pano.mp4
  print_debug "Output filename: $OUTNAME"
else
  OUTNAME=$OUTDIR/`basename $2`
fi

# Check if software is installed
check_preconditions

# Start counting time
STARTTS=`date +%s`

# Handle temporary directories
if [ -n "$TEMPDIRPREFIX" ]; then
  # On some systems not using '-p .' (temp in current dir) might cause problems
  FRAMESTEMPDIR=`mktemp -d -p $TEMPDIRPREFIX`
  OUTTEMPDIR=`mktemp -d -p $TEMPDIRPREFIX`
else
  FRAMESTEMPDIR=`mktemp -d`
  OUTTEMPDIR=`mktemp -d`
fi

# Extract frames from video
run_command notify-send -a $0 "Starting panoramic video stitching..."
echo "Extracting frames from video (this might take a while)..."
# Note: anything in quotes will be treated as one single option
run_command "ffmpeg" "-y" "-i" "$1" $FFMPEGQUALITYDEC "$FRAMESTEMPDIR/$IMAGETMPLDEC"

# Detect video size (http://trac.ffmpeg.org/wiki/FFprobeTips)
eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=height,width "$1")
SRCVIDEOSIZE=${streams_stream_0_width}:${streams_stream_0_height}
print_debug "Input video size: ${SRCVIDEOSIZE}"

# Detect video size and select appriopriate pto file
case $SRCVIDEOSIZE in
  3840:1920)
    PTOTMPL=$PTOTMPL4K
    ;;
  2560:1280)
    PTOTMPL=$PTOTMPL2K
    ;;
  *)
    PTOTMPL=$PTOTMPL4K
    ;;
esac
print_debug "PTO template: ${PTOTMPL}"

# Stitch frames
echo "Stitching frames..."
if [ -z "${USEPARALLEL+x}" ]; then
  # No parallel
  for i in $FRAMESTEMPDIR/*.jpg; do
    echo Frame: $i
    run_command "$DIR/gear360pano.cmd" -m -o "$OUTTEMPDIR" "$i" "$PTOTMPL"
  done
else
  # Use parallel
  export -f print_debug
  export -f run_command
  ls -1 $FRAMESTEMPDIR/*.jpg | parallel -j $PARALLELTHROTTLE --bar run_command "$DIR/gear360pano.cmd" -m -o "$OUTTEMPDIR" {} "$PTOTMPL"
fi

# Put stitched frames together
echo "Recoding the video..."
# Detect source FPS
SRCFPSSTR=`ffprobe -v fatal -of default=noprint_wrappers=1:nokey=1 -select_streams 0 -show_entries stream=r_frame_rate "$1"`
print_debug "Input video FPS: ${SRCFPSSTR}"

# Re-encode video back with stitched images
run_command ffmpeg -y -f image2 -i "$OUTTEMPDIR/$IMAGETMPLENC" -r "${SRCFPSSTR}" -s "${SRCVIDEOSIZE}" $FFMPEGQUALITYENC "$OUTTEMPDIR/$TMPVIDEO"

# Check if there's audio present (https://stackoverflow.com/questions/21446804/find-if-video-file-has-audio-present-in-it)
SRCHASAUDIO=`ffprobe -v fatal -of default=nw=1:nk=1 -show_streams -select_streams a -show_entries stream=codec_type "$1"`
print_debug "Input video has audio: ${SRCHASAUDIO}"

if [ -n "$SRCHASAUDIO" ]; then
  echo "Extracting audio..."
  run_command notify-send -a $0 "Extracting audio from source video..."
  run_command ffmpeg -y -i "$1" -vn -acodec copy "$OUTTEMPDIR/$TMPAUDIO"

  echo "Merging audio..."
  run_command notify-send -a $0 "Merging audio with final video..."
  run_command ffmpeg -y -i "$OUTTEMPDIR/$TMPVIDEO" -i "$OUTTEMPDIR/$TMPAUDIO" -c:v copy -c:a aac -strict experimental "$OUTNAME"
else
  print_debug "No audio detected (timelapse video?), continuing..."
  mv "$OUTTEMPDIR/$TMPVIDEO" "$OUTNAME"
fi

# Remove temporary directories
clean_up

# Inform user about the result
ENDTS=`date +%s`
RUNTIME=$((ENDTS-STARTTS))
echo Video written to $OUTNAME, took: $RUNTIME s
run_command notify-send -a $0 "'Conversion complete. Video written to $OUTNAME, took: $RUNTIME s'"
exit 0

################################ Windows part here
# TODO: update to match Linux functionality

:CMDSCRIPT

set FFMPEGPATH=c:\Program Files\ffmpeg\bin
set FRAMESTEMPDIR=frames
set OUTTEMPDIR=frames_stitched
set PTOTMPL=gear360video.pto
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
