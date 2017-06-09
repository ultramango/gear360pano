# About

Poorman's gallery for panoramic videos and photos.

# Latest Changes

Latest Changes:

- 2017-05-16: initial version

# Usage

Usage:
1. Copy files (video and photo) here (```html``` directory).
2. Add files that you want to be in the gallery to ```filelist.txt```, one file per line.

Create file list (Linux):

    ls -1 *.mp4 *.jpg > filelist.txt

Create file list (Windows):

    dir /b *.mp4 *.jpg > filelist.txt

Test (Linux):

    /usr/bin/env python2 -m SimpleHTTPServer

Open link pointing to [localhost](http://localhost:8000/index.html).

Note: this code has literally zero error control and it's ugly JS.

# Libraries

Code used:
* [Valiant360](https://github.com/flimshaw/Valiant360).
* [jQuery](http://jquery.com/).
* [Three.js](http://threejs.org/).
* [Font Awesome](http://fortawesome.github.io/Font-Awesome/).
