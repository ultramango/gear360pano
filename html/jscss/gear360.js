<!-- https://pannellum.org/documentation/examples/video/ -->

const FILELISTURI = "filelist.txt";
const LISTID = "objList"; // HTML ID of list
const PANOROOT = "panoroot"; // HTML ID to which attach photo or video
const PANOID = "panophoto"; // HTML ID of pano photo/video object
const VIDEOID = "panovideo"; // HTML ID of pano photo/video object

var lastSelection = "";

// https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/Synchronous_and_Asynchronous_Requests
function xhrSuccess () { this.callback.apply(this, this.arguments); }

function xhrError () { console.error(this.statusText); }

function loadFile(sURL, fCallback /*, argumentToPass1, argumentToPass2, etc. */) {
  var oReq = new XMLHttpRequest();
  oReq.callback = fCallback;
  oReq.arguments = Array.prototype.slice.call(arguments, 2);
  oReq.onload = xhrSuccess;
  oReq.onerror = xhrError;
  oReq.open("get", sURL, true);
  oReq.send(null);
}

// Return DOM element that represents a video
// Based on: https://pannellum.org/documentation/examples/video/
function pannellumVideoElem(videoUri) {
  var videoElem = document.createElement("video");
  videoElem.setAttribute("id", VIDEOID);
  videoElem.setAttribute("class", "video-js vjs-default-skin vjs-big-play-centered");
  videoElem.setAttribute("controls", "");
  videoElem.setAttribute("preload", "none");
  videoElem.setAttribute("style", "width:100%;height:400px;");
  // This is if we have somekind of a background photo (we don't)
  //videoElem.setAttribute("poster", "none");
  videoElem.setAttribute("crossorigin", "anonymous");

  var videoSrc = document.createElement("source");
  videoSrc.setAttribute("src", videoUri);

  videoElem.appendChild(videoSrc);

  return videoElem;
}

// Return DOM element that will contain a panoramic photo
function pannellumPhotoElem(photoUri) {
  var photoElem = document.createElement("div");
  photoElem.setAttribute("id", PANOID);

  return photoElem;
}

// Destroy any child elements of our root
// This is to be able to switch between photo and video
// TODO: if we already have a photo then we could reuse
//       if we need a photo container
function resetRootElem(elemId) {
  // Reinit the element displaying panorama
  var root = document.getElementById(elemId);
  if(root.hasChildNodes()) {
    // We'll remove all the childs with special care for
    // video player
    while(root.firstChild) {
      if(root.firstChild.getAttribute("id") == VIDEOID) {
        // Properly delete video object
        videojs(root.firstChild).dispose();
      } else {
        root.removeChild(root.firstChild);
      }
    }
  }
  return root;
}

// Display panoramic photo given by a link
function displayPanoPhoto(photoUri) {
  var root = resetRootElem(PANOROOT);
  root.appendChild(pannellumPhotoElem());
  pannellum.viewer(PANOID, {
    "type": "equirectangular",
    "panorama": photoUri,
    "autoLoad": true
  })
}

// Display panoramic video given by a link
function displayPanoVideo(videoUri) {
  var root = resetRootElem(PANOROOT);
  root.appendChild(pannellumVideoElem(videoUri));
  videojs(VIDEOID, { plugins: { pannellum: {} } });
}

// Update displayed list of files
function updateFileList() {
  var list = this.responseText.split("\n");

  var ulList = document.getElementById(LISTID);

  list.forEach(function(item, index) {
    if(item != "") {
      var liChild = document.createElement("li");
      // Get only the file name, we don't care about the rest of the path
      var fileNameOnly = item.split('/').pop();
      // Add text to li element
      liChild.appendChild(document.createTextNode(fileNameOnly));
      // Set onclick attribute
      liChild.setAttribute("onclick", "onClickFile(\"" + item + "\")");
      ulList.appendChild(liChild);
    }
  });
}

// Handle onclick event from a click on a file (on file list)
function onClickFile(fileItem) {
  // Try to detect file type
  var ext = fileItem.split('.').pop().toLowerCase();
  if(ext == 'mp4') {
    displayPanoVideo(fileItem);
  } else if (ext == "jpg" || ext == "jpeg" || ext == "png") {
    displayPanoPhoto(fileItem);
  }
  updateListHighlight(lastSelection, "normal");
  updateListHighlight(fileItem, "highlight");
  lastSelection = fileItem;
}

// Change class of matching list element
function updateListHighlight(itemName, newClass) {
  var children = [].slice.call(document.getElementById(LISTID).children);
  children.forEach(function(item, index) {
    var onClickAttr = item.getAttribute("onclick");
    if(onClickAttr.indexOf(itemName) !== -1) {
      item.setAttribute("class", newClass);
    }
  });
}

// Start by loading list of files
loadFile(FILELISTURI, updateFileList);
