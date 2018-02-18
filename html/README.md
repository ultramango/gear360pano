# About

Simple gallery for panoramic videos and photos.

# Latest Changes

Latest Changes:

- 2018-02-18: updated Pannellum library to 2.4.0
- 2017-06-09: moved to Pannellum library.
- 2017-05-16: initial version.

# Usage

Usage:
1. Place files (video and photo) in ```data``` directory.
2. Add files that you want to be in the gallery to ```filelist.txt```, one file per line (
  they should contain relative path to photos and videos, e.g. ```data/somefile.jpg```).

Manually create file list (Linux), run from this directory:

    find data -type f -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.mp4" > filelist.txt

Test (Linux):

    /usr/bin/env python2 -m SimpleHTTPServer

Open link pointing to [localhost](http://localhost:8000/index.html).

Note: this code has very little error control.

# video.js Copyright

video.js copyright (https://github.com/videojs/video.js/blob/master/LICENSE)

# Pannellum Copyright (see also COPYING file in jscss directory)

## License
Pannellum is distributed under the MIT License. For more information, read the file `COPYING` or peruse the license [online](https://github.com/mpetroff/pannellum/blob/master/COPYING).

In the past, parts of Pannellum were based on [three.js](https://github.com/mrdoob/three.js) r40, which is licensed under the [MIT License](https://github.com/mrdoob/three.js/blob/44a8652c37e576d51a7edd97b0f99f00784c3db7/LICENSE).

The panoramic image provided with the examples is licensed under the [Creative Commons Attribution-ShareAlike 3.0 Unported License](http://creativecommons.org/licenses/by-sa/3.0/).

## Credits

* [Matthew Petroff](http://mpetroff.net/), Original Author
* [three.js](https://github.com/mrdoob/three.js) r40, Former Underlying Framework
