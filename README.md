# About

Simple script to create equirectangular panoramic photos or videos from Samsung Gear 360 (generation 1 /SM-C200/ and 2 /SM-R210/).

![Samsung Gear 360](gear360.jpg)

# Latest Changes

Latest Changes:

- 2017-07-09: processed files (in output directory) are skipped, updated help.
- 2017-06-11: added preliminary support for generation 2 of Gear360 (SM-R210), thanks
sfrique for providing files.
- 2017-06-10: support for wildcards, switched gallery to Pannellum, "automatic" gallery creation, no longer possible to set output filename (this is due to acceptance of wildcards/multiple files).
Lots of changes so expect things not to work well (I did basic testing).
- 2017-05-16: small update, added poorman's gallery in html.
- 2017-03-17: added compatibility with Google Photos (contribution by Ry0 and ftoledo).
- 2017-02-04: added tutorial how to manually create initial panorama in Hugin, updated template, now it resembles panorama created by Samsung S7 phone (it is horizontally rotated by 180 deg.).
- 2017-01-25: added EXIF data to output file, Windows has now command timing, cosmetic changes to the file.
- 2017-01-18: improved Hugin template(s), should not be so distorted; new template for video, should speed up video by factor of two (about), fix video size for Linux in script (was 1940, should be 1920).
- 2016-11-07: added sound to final video (contribution by OWKenobi), some small fixes.
- 2016-10-23: experimental (read: slow and not tested well) support for video stiching.
- 2016-09-29: removed bash dependency on Windows, one script for Linux & Windows, script can be run outside its original/installation directory.
- 2016-07-31: removed dependency on ImageMagick, optional second parameter as output filename.

# Usage

## Requirements

Requirements:

* Linux, Windows, should work on Mac.
* [Hugin](http://hugin.sourceforge.net/).
* [ffmpeg](https://ffmpeg.org/download.html) (optional, needed for video stitching).

## Installation

### Linux

Use your distributions' package manager to install [Hugin](http://hugin.sourceforge.net/). Example for Ubuntu:

    apt-get install hugin

Do the same for ```ffmpeg``` if you want video stitching, it is usually installed on many systems.

Clone or download zip of this project then unpack it somewhere.

### Windows

Install [Hugin](http://hugin.sourceforge.net/) in the default location (it's hardcoded in script), both 32 and 64-bit versions will work.

For video stitching install/unzip [ffmpeg](https://ffmpeg.zeranoe.com/builds/) in ```c:\program files\ffmpeg``` (there should be
a subdirectory ```bin``` there with ```ffmpeg.exe``` binary).

Clone or download zip of this project then unpack it somewhere.

## Usage

### Photos

Open console or command line (Win key + R then ```cmd.exe```), go to directory where you cloned/unpacked this project.

Usage (example):

    gear360pano.cmd *.JPG

Output (example for Windows):

    C:\temp>gear360pano.cmd *.JPG
    Processing file: 360_0010.JPG
    Processing input images (nona)
    Stitching input images (enblend)
    enblend: info: loading next image: C:\Users\noone\AppData\Local\Temp/out0000.tif 1/1
    enblend: info: loading next image: C:\Users\noone\AppData\Local\Temp/out0001.tif 1/1
    enblend: info: writing final output
    enblend: warning: must fall back to export image without alpha channel
    Setting EXIF data (exiftool)
    Processing file: 360_00102.JPG
    Processing input images (nona)
    Stitching input images (enblend)
    enblend: info: loading next image: C:\Users\noone\AppData\Local\Temp/out0000.tif 1/1
    enblend: info: loading next image: C:\Users\noone\AppData\Local\Temp/out0001.tif 1/1
    enblend: info: writing final output
    enblend: warning: must fall back to export image without alpha channel
    Setting EXIF data (exiftool)
    Processing took: 47 s
    Processed files should be in html\data

This will produce a panorama files in ```html\data``` directory (default), this can be
changed with -o (Linux) or /o (Windows) paramter.

List of switches (Windows in brackets):

* -o (/o) directory - set output directory
* -q (/q) quality - set JPEG quality
* -g (/g) - update gallery files
* -h (/h) - display help

Script has some simple error checking routines but don't expect any magic.

Few remarks (does not apply for the videos):

* script will support only the highest resolution from the camera (7776x3888),
* ensure that you have something like 150 MB of free disk space for intermediate files. If you're tight on disk space, switch to png format (change inside the script), but the processing time increases about four times,
* on Intel i7, 12 GB memory it takes ~16 seconds to produce the panorama,
* for better results stitch panorama manually: create new project in Hugin, add two times the same (raw) panorama file, then choose from menu "File" and "Apply Template",
add points and optimise,
* script might contain bugs, most possibly running script from weird directories (symbolic links, spaces in paths) or giving image from just as weird directory location,
* script might not support some exotic interpreters or not work on some older Windows versions. On Linux it should work with bash and zsh,
* try not to use current directory as output directory, it will process already processed panorama files which might lead to problems,
* when using zsh, you might need to escape asterisk, otherwise script will hang,
* script has (should have) Unix line endings.

### Videos

For videos:

    ./gear360video.cmd video.mp4

This should produce ```video_pano.mp4``` file, output file can be given as a second argument.

Don't have any expectations for video stitching to work well, it is higly unoptimised but to some degree useable.

What is/might be wrong (loose notes about the script):

* only the highest resolution is currently supported (3840x1920),
* video stitching works by converting it to image files, stitching them and then re-coding,
* it might require a lot of disk space (gigabytes or even more) as the long videos will result in many image files, this could be
optimised by removing files which are no longer needed, also check for left-over directories that might have not been removed,
* possibly [GNU Parallel](https://www.gnu.org/software/parallel/) could be used for Linux for parallel panorama processing:
```ls *.jpeg | parallel -j+0 --eta '../../gear360pano.sh {} ../stitched/{}'```. But then, Hugin already makes good use of
the cores.

# Tutorial

This video shows how to create an initial (no proper stitching) panorama file from one double fisheye photos:

[![Panorama from double fisheye photo](http://img.youtube.com/vi/QKQGT8VUN8g/0.jpg)](http://www.youtube.com/watch?v=QKQGT8VUN8g "Panorama from double fisheye photo")

# Links

Links:
* easy to setup HTML panorama viewer [Pannellum](https://pannellum.org/),
* panorama photo and video viewer: [Valiant360](https://github.com/flimshaw/Valiant360),
* some notes on [Gear360 firmware](https://github.com/ultramango/gear360reveng).

# TODOs

Few things that could be improved:

* there's no vignetting correction, better lens correction could be created,
* panorama seams on stitched video are "flickering",
* script could have few parameters added like: jpeg quality, EXIF tags update.
