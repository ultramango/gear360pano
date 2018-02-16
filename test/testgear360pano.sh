#!/usr/bin/env bash

# Test script for gear360pano.sh

#############
### Constants

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
DIR=$(dirname `which $0`)
T="./gear360pano.sh" # T - for simplicity, it's a test subject
# Debug, yes = print debug messages (might fail some tests due to ret value passing)
DEBUG="no"
VERSION="3"

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
  rm -f ${output}

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
fi
rm -f ${testimage}
rm -f ${outimage}

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
rm -f ${testimage}
rm -rf ${testdir}

# *** 4. No gpu
testimage=$(create_test_image)
exec_test "$T -n ${testimage}" "Single panorama stitching (no gpu)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
fi
rm -f ${testimage}
rm -f ${outimage}

# *** 5. Use multiblend
testimage=$(create_test_image)
exec_test "$T -m ${testimage}" "Single panorama stitching (multiblend)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
fi
rm -f ${testimage}
rm -f ${outimage}

# *** 6. Set jpeg compression
testimage1=$(create_test_image)
exec_test "$T -q 99 ${testimage1}" "Single panorama stitching (set high quality)"
outimage1=html/data/`basename "${testimage1%.*}"`_pano.jpg
if [ ! -f ${outimage1} ]; then
  echo "Extra check failed: output file (${outimage1}) not found"
else
  # For comparison create low quality jpeg
  testimage2=$(create_test_image)
  exec_test "$T -q 5 ${testimage2}" "Single panorama stitching (set low quality)"
  outimage2=html/data/`basename "${testimage2%.*}"`_pano.jpg
  if [ ! -f ${outimage2} ]; then
    echo "Extra check failed: output file (${outimage2}) not found"
  else
    # Check if size of testimage1 is bigger than testimage2
    if ((`stat -c%s "$outimage1"` < `stat -c%s "$outimage2"`)); then
      echo "Extra check failed: low quality image size bigger or equal than high quality"
    fi
  fi
fi
rm -f ${testimage1}
rm -f ${testimage2}
rm -f ${outimage2}
rm -f ${outimage1}

# *** 7. Remove source file
testimage=$(create_test_image)
exec_test "$T -r ${testimage}" "Single panorama stitching (remove source)"
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
if [ ! -f ${outimage} ]; then
  echo "Extra check failed: output file (${outimage}) not found"
fi
if [ -f ${testimage} ]; then
  echo "Extra check failed: source file exists (it shouldn't)"
fi
rm -f ${testimage}
rm -f ${outimage}

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
rm -f ${testimage}
rm -f ${outimage}

# *** 5. Non existing temporary directory
testimage=$(create_test_image)
# Note: we expect exit code 0, as it should recover from non existing temporary directory
exec_test "$T -t ${idonotexist} ${testimage}" "Non-existing temp directory" "0"
rm -f ${testimage}

# *** 6. Bad image size
testimage=$(create_test_image "100x100")
outimage=html/data/`basename "${testimage%.*}"`_pano.jpg
exec_test "$T ${testimage}" "Bad input image size" "1"
rm -f ${testimage}
rm -f ${outimage}

# Summary
totalendts=`date +%s`
totalruntime=$((totalendts-totalstartts))
echo "Test set version: ${VERSION}, total time: ${totalruntime} s"

# TODO: missing hugin, missing multiblend, combination of options

exit 0
