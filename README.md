# About

Simple script to create equirectangular panorama from Samsung Gear 360.

![Samsung Gear 360](http://www.samsung.com/us/explore/gear-360/assets/images/gear360.jpg)

# Usage

## Requirements

Requirements:

* Linux,
* [Hugin](http://hugin.sourceforge.net/),
* [ImageMagick](http://www.imagemagick.org/).

## Usage

Usage (example):

    ./gear360pano.sh 360_0010.JPG

Output:

    Splitting input image
    Processing input images
    Stiching input images
    enblend: info: loading next image: /tmp/tmp.hE119D7M9s/out0000.tif 1/1
    enblend: info: loading next image: /tmp/tmp.hE119D7M9s/out0001.tif 1/1
    enblend: info: writing final output
    enblend: warning: must fall back to export image without alpha channel
    Panorama written to 360_0010_pano.jpg, took: 19 s

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
* easy to setup HTML panorama viewer [Pannellum](https://pannellum.org/).

# TODOs

Few things that could be improved:

* included [Hugin](http://hugin.sourceforge.net/) template file is not perfect and bad seams will happen (especially for close objects),
* there's no vignetting correction, better lens correction could be created,
* script could have few parameters added like: set output file/directory.
