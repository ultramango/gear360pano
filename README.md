# About

Simple script to create equirectangular panorama from Samsung Gear 360.

![Samsung Gear 360](http://www.samsung.com/us/explore/gear-360/assets/images/gear360.jpg)

# Latest Changes

Latest Changes:

- 2016-09-29: removed bash dependency on Windows, one script for Linux & Windows, script can be run outside its original/installation directory.
- 2016-07-31: removed dependency on ImageMagick, optional second parameter as output filename.

# Usage

## Requirements

Requirements:

* Linux, Windows, should work on Mac.
* [Hugin](http://hugin.sourceforge.net/).

## Installation

### Linux

Use your distributions' package manager to install [Hugin](http://hugin.sourceforge.net/). Example for Ubuntu:

    apt-get install hugin

Clone or download zip of this project then unpack it somewhere.

### Windows

Install [Hugin](http://hugin.sourceforge.net/) in the default location (it's hardcoded in script), both 32 and 64-bit versions will work.

Clone or download zip of this project then unpack it somewhere.

## Usage

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

# Remarks

Few remarks:

* ensure that you have something like 150 MB of free disk space for intermediate files. If you're tight on disk space, switch to png format, but the processing time increases to ~90 seconds on my machine,
* on my machine (Intel i7, 12 GB memory) it takes ~16 seconds to produce the panorama,
* for better results stitch panorama manually, it should be possible to use template file from this project,
* script might contain bugs, most possibly running script from weird directories (symbolic links, spaces in paths) or giving image from as weird directory location,
* script might not support some exotic interpreters or not work on some older Windows versions. On Linux it should work with bash and zsh,
* script has Unix line endings.

# Links

Links:
* easy to setup HTML panorama viewer [Pannellum](https://pannellum.org/),
* some notes on [Gear360 firmware](https://github.com/ultramango/gear360reveng).

# TODOs

Few things that could be improved:

* included [Hugin](http://hugin.sourceforge.net/) template file is not perfect and bad seams will happen (especially for close objects),
* there's no vignetting correction, better lens correction could be created,
* script could have few parameters added like: jpeg quality.
