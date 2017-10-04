:<<"::IGNORE_THIS_LINE"
@echo off
goto :CMDSCRIPT
::IGNORE_THIS_LINE

# Test script for gear360video.sh
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here ################################

#############
### Constants

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
T="./gear360video.cmd" # T - for simplicity, it's a test subject
# Debug, yes = print debug messages
DEBUG="no"
VERSION="2"

#############
### Functions

# Debug, arguments:
# 1. Text to print
print_debug() {
  if [ "$DEBUG" == "yes" ]; then
    echo "DEBUG: $@"
  fi
}

# Create test video
# Arguments:
# 1 - video size (in pixels, optional)
# 2 - duration (in seconds, optional)
# 3 - frame rate (fps, optional)
# 4 - no sound (0 - sound /default/, 1 - no sound)
# Returns:
# test file full path
create_test_video() {
  local videoformat="mp4" # hardcoded for the moment
  # Default parameter: https://stackoverflow.com/questions/9332802/how-to-write-a-bash-script-that-takes-optional-input-arguments
  local videosize=${1:-"3840x1920"} # Other video size: 2560x1280
  local duration=${2:-"1"}
  local framerate=${3:-"29.97"}
  local nosound=${4:-"0"}
  local filename=$(mktemp --suffix=.${videoformat}) # Mind the dot (extension)

  print_debug "create_test_video args: size: ${videosize}, duration: ${duration}, fps: ${framerate}, nosound: ${nosound}, out filename: ${filename}"

  # Well... we assume it will not fail
  local soundopt=""
  if [ ${nosound} -eq 0 ]; then
    soundopt="-f lavfi -i sine=frequency=1000:sample_rate=48000:duration=${duration}"
  fi
  ffmpeg -loglevel quiet -y -f lavfi -i testsrc=duration=${duration}:size=${videosize}:rate=30 ${soundopt} -f ${videoformat} ${filename}

  echo "${filename}"
}

# Simple test execution wrapper. Runs command and
# check exit code if it is something that we expect.
# Executed command output is shown only on error.
# Arguments:
# 1 - command to execute
# 2 - Test description
# 3 - Expected exit code (default: 0)
# 4 - Be quiet (default: 0, if 1 then suppress display of cmd output if failed)
# Returns:
# exit code from the executed command
exec_test() {
  local expected=${3:-0}
  local bequiet=${4:-0}
  local output=$(mktemp)

  print_debug "exec_test args: command: ${1}, descr: ${2}, expected: ${expected}, cmd out: ${output}"

  # Execute command
  echo -e "${2}... \c"
  local startts=`date +%s`
  $1 > ${output} 2>&1
  local exitcode=$?
  local endts=`date +%s`
  local runtime=$((endts-startts))

  if [ $exitcode -ne ${expected} ]; then
    echo -e "Failed, exit code: ${exitcode}, expecting: ${expected}\c"
    if [ $bequiet -eq 0 ]; then
      echo -e "\n--- command output starts here ---"
      cat ${output}
      echo -e "\n---  command output ends here  ---"
    fi
  else
    echo -e "OK\c"
  fi
  echo " (took: ${runtime} s)"

  # Remove stored command output
  print_debug "exec_test removing command output log: ${output}"
  rm ${output}

  # Lets return executed command status
  return $status
}


########
### Main

totalstartts=`date +%s`

# Positive test, just go through options
# *** 1. Help
exec_test "$T -h" "Print help"

# *** 2. 4k video test
testvideo=$(create_test_video "3840x1920")
exec_test "$T ${testvideo}" "4k video stitching"
# Check if the video has been created
outvideo=html/data/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# *** 3. 2k video test
testvideo=$(create_test_video "2560x1280")
exec_test "$T ${testvideo}" "2k video stitching"
# Check if the video has been created
outvideo=html/data/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
  else
    rm ${outvideo}
fi
rm ${testvideo}

# *** 4. Timelapse video (10 fps and no sound)
testvideo=$(create_test_video "3840x1920" "1" "10" "1")
exec_test "$T ${testvideo}" "Timelapse video stitching"
# Check if the video has been created
outvideo=html/data/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# *** 5. Speed option
testvideo=$(create_test_video "3840x1920")
exec_test "$T -s ${testvideo}" "4k video stitching and speed option"
# Check if the video has been created
outvideo=html/data/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# *** 6. Output directory
testvideo=$(create_test_video "3840x1920")
testdir=$(mktemp -d)
exec_test "$T -o ${testdir} ${testvideo}" "4k video stitching with output directory"
# Check if the video has been created
outvideo=${testdir}/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# *** 7. Parallel processing
testvideo=$(create_test_video "3840x1920")
exec_test "$T -p ${testvideo}" "4k video stitching and parallel processing"
# Check if the video has been created
outvideo=html/data/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# Negative tests
idonotexist='ihopeidonotexist' # Something that does not exist
# *** 1. No input
exec_test "$T" "No input file" "1"

# *** 2. Non existing input
exec_test "$T ${idonotexist}" "Non-existing input" "1"

# *** 3. Non existing output directory
testvideo=$(create_test_video "3840x1920")
exec_test "$T -o ${idonotexist} ${testvideo}" "Non-existing output directory" "1"
rm ${testvideo}

# *** 4. Non existing temp directory
testvideo=$(create_test_video "3840x1920")
testdir=$(mktemp -d)
exec_test "$T -o ${testdir} -t ${idonotexist} ${testvideo}" "Non-existing temp directory plus output dir" "0"
# Check if the video has been created
outvideo=${testdir}/`basename "${testvideo%.*}"`_pano.mp4
if [ ! -f ${outvideo} ]; then
  echo "Extra check failed: output file (${outvideo}) not found"
else
  rm ${outvideo}
fi
rm ${testvideo}

# TODO: ffmpeg not installed (modify PATH and link required tools locally?)

# Summary
totalendts=`date +%s`
totalruntime=$((totalendts-totalstartts))
echo "Test set version: ${VERSION}, total time: ${totalruntime} s"

exit 0

################################ Windows part here

:CMDSCRIPT

set FFMPEGPATH=c:\Program Files\ffmpeg\bin
set DEBUG=""

echo Not implemented

:PRINT_DEBUG
if %DEBUG% == "yes" (
  echo DEBUG: %1 %2 %3 %4 %5 %6 %7 %8 %9
)

exit /b 0

:eof
