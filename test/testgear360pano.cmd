:<<"::IGNORE_THIS_LINE"
@echo off
goto :CMDSCRIPT
::IGNORE_THIS_LINE

# Test script for gear360pano.sh
#
# Trick with Win/Linux from here:
# http://stackoverflow.com/questions/17510688/single-script-to-run-in-both-windows-batch-and-linux-bash

################################ Linux part here ################################

#############
### Constants

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
T="./gear360pano.cmd" # T - for simplicity, it's a test subject
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

# Create test image
# Arguments:
# 1 - image size (in pixels, optional)
# Returns:
# test file full path
create_test_image() {
  local imageformat="jpeg"
  # Default parameter: https://stackoverflow.com/questions/9332802/how-to-write-a-bash-script-that-takes-optional-input-arguments
  local imagesize=${1:-"7776x3888"}
  local filename=$(mktemp --suffix=.${imageformat}) # Mind the dot (extension)

  print_debug "create_test_image args: size: ${imagesize}, out filename: ${filename}"

  # Well... we assume it will not fail
  # Note multiblend does not support 4 spp (samples per pixel), that's why "TrueColor" option
  convert -type TrueColor -size ${imagesize} pattern:checkerboard -auto-level ${filename}

  # A bit naive way of returning, but it will do
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
# *** 1. Simple help
exec_test "$T -h" "Print help"

# *** 2. Simple image
testimage=$(create_test_image)
exec_test "$T ${testimage}" "Single panorama stitching"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
else
  rm ${outimage}
fi
rm ${testimage}

# *** 3. Multiple files with output
testimage=$(create_test_image)
testdir=$(mktemp -d)
testout=$(mktemp -d)
cp ${testimage} ${testdir}/dummypano1.jpeg
cp ${testimage} ${testdir}/dummypano2.jpeg
cp ${testimage} ${testdir}/dummypano3.jpeg
cp ${testimage} ${testdir}/dummypano4.jpeg
# set -f - globbing problem, disable expansion for the moment
set -f
exec_test "$T -o ${testout} ${testdir}/*.jpeg" "Multiple panorama stitching with output directory"
set +f
count=$(ls ${testout} | wc -l)
if [ $count -ne 4 ]; then
  echo "Extra check on output file count file failed, expected: 4, got: ${count}"
fi
rm ${testimage}
rm -rf ${testdir}

# *** 4. No gpu
testimage=$(create_test_image)
exec_test "$T -n ${testimage}" "Single panorama stitching (no gpu)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
else
  rm ${outimage}
fi
rm ${testimage}

# *** 5. Use multiblend
testimage=$(create_test_image)
exec_test "$T -m ${testimage}" "Single panorama stitching (multiblend)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
else
  rm ${outimage}
fi
rm ${testimage}

# *** 6. Set jpeg compression
testimage=$(create_test_image)
exec_test "$T -q 5 ${testimage}" "Single panorama stitching (set quality)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
else
  rm ${outimage}
fi
rm ${testimage}

# *** 7. Remove source file
testimage=$(create_test_image)
exec_test "$T -r ${testimage}" "Single panorama stitching (remove source)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
else
  rm ${outimage}
fi
if [ -f ${testimage} ]; then
  echo "Extra check failed: source file exists (it shouldn't)"
  rm ${testimage}
fi

# Negative tests
idonotexist='ihopeidonotexist' # Something that does not exist
# *** 1. No input filename
exec_test "$T" "No input file" "1"

# *** 2. Non existing input
exec_test "$T ${idonotexist}.jpg" "Non-existing input file" "1"

# *** 3. Bad input
emptyfile=$(mktemp)
exec_test "$T ${emptyfile}" "Bad input file" "1"

# *** 4. Non existing output directory
testimage=$(create_test_image)
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
exec_test "$T -o ${idonotexist} ${testimage}" "Non-existing output directory" "1"
if [ -f ${outimage} ]; then
  rm ${outimage}
fi
rm ${testimage}

# *** 5. Non existing temporary directory
testimage=$(create_test_image)
# Note: we expect exit code 0, as it should recover from non existing temporary directory
exec_test "$T -t ${idonotexist} ${testimage}" "Non-existing temp directory" "0"
rm ${testimage}

# *** 6. Bad image size
testimage=$(create_test_image "100x100")
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
exec_test "$T ${testimage}" "Bad input image size" "1"
if [ -f ${outimage} ]; then
  rm ${outimage}
fi
rm ${testimage}

# Summary
totalendts=`date +%s`
totalruntime=$((totalendts-totalstartts))
echo "Test set version: ${VERSION}, total time: ${totalruntime} s"

# TODO: missing hugin, missing multiblend, combination of options

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
