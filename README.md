# About

Simple script to create equirectangular panorama from Samsung Gear 360.

![Samsung Gear 360](http://www.samsung.com/us/explore/gear-360/assets/images/gear360.jpg)

# Latest Changes

Latest Changes:

- 2016-07-31: removed dependency on ImageMagick, optinal second parameter as output filename.

# Usage

## Requirements

Requirements:

* Linux, Windows (cygwin), most possibly Mac.
* [Hugin](http://hugin.sourceforge.net/).

## Installation

### Linux

Use your distributions' package manager to install [Hugin](http://hugin.sourceforge.net/). Example for Ubuntu:

    apt-get install hugin

### Windows

Installation steps:

1. Install [cygwin](https://cygwin.com/install.html) (a bit overkill, only bash is needed).
2. Install [Hugin](http://hugin.sourceforge.net/) in the default location (it's hardcoded in script).

## Usage

Usage (example):

    ./gear360pano.sh 360_0010.JPG

Output (example):

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

Script has some simple error checking routines.

# Remarks

Few remarks:

* ensure that you have something like 150 MB of free disk space for intermediate files. If you're tight on disk space, switch to png format, but the processing time increases to ~90 seconds on my machine,
* on my machine (Intel i7, 12 GB memory) it takes ~20 seconds to produce the panorama,
* for better results stitch panorama manually (this is beyond scope of this readme):
  1. Split the input image in two.
  2. Add images to [Hugin](http://hugin.sourceforge.net/), set Lens type to Circular fisheye.
  3. In Masks tab set crop (untick Always centre Crop on d,e).
  4. Add control points manually (auto will not work well or at all).
  5. Optimise, preview and create.
  6. Use masks if you still have problems with bad stitching.

# Links

Links:
* easy to setup HTML panorama viewer [Pannellum](https://pannellum.org/),
* some notes on [Gear360 firmware](https://github.com/ultramango/gear360reveng).

# TODOs

Few things that could be improved:

* included [Hugin](http://hugin.sourceforge.net/) template file is not perfect and bad seams will happen (especially for close objects),
* there's no vignetting correction, better lens correction could be created,
* script could have few parameters added like: jpeg quality.
