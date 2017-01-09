# About

Simple script to create equirectangular panorama from Samsung Gear 360.

![Samsung Gear 360](http://www.samsung.com/us/explore/gear-360/assets/images/gear360.jpg)

# Latest Changes

Latest Changes:

- 2016-11-07: added sound to final video (contribution by OWKenobi), some small fixes.
- 2016-10-23: experimental (read: slow and not tested well) support for video stiching.
- 2016-09-29: removed bash dependency on Windows, one script for Linux & Windows, script can be run outside its original/installation directory.
- 2016-07-31: removed dependency on ImageMagick, optional second parameter as output filename.

# Usage

## Requirements

Requirements:

* Linux, Windows (native & cygwin), should work on Mac.
* [Hugin](http://hugin.sourceforge.net/).
* [ffmpeg](https://ffmpeg.org/download.html) (optional, needed for video stitching).

## Installation

### Linux

Use your distributions' package manager to install [Hugin](http://hugin.sourceforge.net/). Example for Ubuntu:

    apt-get install hugin
    
Do the same for ```ffmpeg``` if you want video stitching. It is usually installed on many systems.

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

    ./gear360pano.cmd 360_0010.JPG

Output (example for Linux):

    Processing input images (nona)
    Stiching input images (enblend)
    enblend: info: loading next image: ./tmp.xdyE0bQFMb/out0000.tif 1/1
    enblend: info: loading next image: ./tmp.xdyE0bQFMb/out0001.tif 1/1
    enblend: info: writing final output
    enblend: warning: must fall back to export image without alpha channel
    Panorama written to 360_0010_pano.jpg, took: 16 s

This will produce a file `360_0010_pano.jpg`.

To process all panorama files in current directory:

    for i in 360*.JPG; do ./gear360pano.sh $i; done

Script has some simple error checking routines but don't expect any magic. Script can be run outside of its original directory.

Few remarks (not videos):

* ensure that you have something like 150 MB of free disk space for intermediate files. If you're tight on disk space, switch to png format, but the processing time increases to ~90 seconds on my machine,
* on my machine (Intel i7, 12 GB memory) it takes ~16 seconds to produce the panorama,
* for better results stitch panorama manually, it should be possible to use template file from this project,
* script might contain bugs, most possibly running script from weird directories (symbolic links, spaces in paths) or giving image from as weird directory location,
* script might not support some exotic interpreters or not work on some older Windows versions. On Linux it should work with bash and zsh,
* script has Unix line endings.

### Videos

For videos:

    ./gear360video.cmd video.mp4

This should produce ```video_pano.mp4``` file, output file can be given as a second argument.

Don't have any expectations for video stitching to work well, it is higly unoptimised (for the sake of simplicity and to have
something working for now).

What is wrong (loose notes about the script):

* video stitching works by converting it to image files, stitching them and then re-coding,
* to reuse existing panorama template images are being, unnecessarily, upscaled and then downscaled - this slows the whole process
(I suspect by a significant amount), new panorama template would have to be created to speed things up,
* it might require a lot of disk space (gigabytes or even more) as the long videos will result in many image files, this could be
optimised by removing files which are no longer needed, also check for left-over directories that might have not been removed,
* possibly [GNU Parallel](https://www.gnu.org/software/parallel/) could be used for Linux for parallel panorama processing:
```ls *.jpeg | parallel -j+0 --eta '../../gear360pano.sh {} ../stitched/{}'```. But then, Hugin already makes good use of
the cores.

# Links

Links:
* easy to setup HTML panorama viewer [Pannellum](https://pannellum.org/),
* some notes on [Gear360 firmware](https://github.com/ultramango/gear360reveng).

# TODOs

Few things that could be improved:

* included [Hugin](http://hugin.sourceforge.net/) template file is not perfect and bad seams will happen (especially for close objects),
* there's no vignetting correction, better lens correction could be created,
* script could have few parameters added like: jpeg quality, panorama template.
