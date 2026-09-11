from typing import overload
import numpy as np
import cv2 as cv
from matplotlib import pyplot as plt


# cv.typing.MatLike is OpenCV's type hint for a NumPy array containing pixel data.
# basically an image.
@overload
def capture_photo(img_name: None = None) -> cv.typing.MatLike:
    ...


@overload
def capture_photo(img_name: str) -> str:
    ...


# it can either take in an img name or it nothing at all. Sending nothing will return
# the raw image as a NumPy array, otherwise it will return the filepath.
def capture_photo(img_name: str | None = None) -> cv.typing.MatLike | str:
    """Capture a photo and return the image or the path it was saved to."""
    # init webcam (0 is default)
    cam = cv.VideoCapture(0)

    try:
        ret, frame = cam.read()

        if not ret:
            raise RuntimeError("Failed to capture image")

        cv.imshow("Captured", frame)
        cv.waitKey(0)  # Await key press before continuing.
        cv.destroyWindow("Captured")

        if img_name is None:
            return frame

        if not cv.imwrite(img_name, frame):
            raise OSError(f"Failed to save image to {img_name}")

        return img_name
    finally:
        cam.release()



def find_feature(img: str | cv.typing.MatLike, feature_path: str, threshold: float = 0.8):
    """Find matching feature in image and return their coordinates."""

    if not 0 <= threshold <= 1:
        raise ValueError("threshold must be clamped between 0 and 1")

    source = cv.imread(img) if isinstance(img, str) else img
    feature = cv.imread(feature_path, cv.IMREAD_GRAYSCALE)

    if source is None:
        raise ValueError(f"Failed to read image from {img}")
    if feature is None:
        raise ValueError(f"Failed to read feature from {feature}")

    source_gray = cv.cvtColor(source, cv.COLOR_BGR2GRAY)
    feature_gray = cv.cvtColor(feature, cv.COLOR_BGR2GRAY)

    # question: matchTemplate or matchShape? We will have to decide...
    # we want to match shape,
    # check for vertex count of a shape
    # classify based on that information
    # Shapes of same vertex count should have something more that's distinct about them


    # For that reason, we should look at hu moments, because shape matching is NOT good enough.
    # Feature matching is also a possible way to do it.


MIN_MATCH_COUNT = 10

# Query is what we're looking for, Scene is where we are looking.
query = cv.imread('matchpic-box.png', cv.IMREAD_GRAYSCALE)       # queryImage
scene = cv.imread('matchpic.png', cv.IMREAD_GRAYSCALE)           # trainImage

## Initiate SIFT detector
sift = cv.SIFT_create()

## find the keypoints and descriptors with SIFT
kp1, des1 = sift.detectAndCompute(query,None)
kp2, des2 = sift.detectAndCompute(scene,None)

FLANN_INDEX_KDTREE = 1
index_params = dict(algorithm = FLANN_INDEX_KDTREE, trees = 5)
search_params = dict(checks = 50)

flann = cv.FlannBasedMatcher(index_params, search_params)

matches = flann.knnMatch(des1,des2,k=2)

## store all the good matches as per Lowe's ratio test.
good = []
for m,n in matches:
    if m.distance < 0.7*n.distance:
        good.append(m)



if len(good)>MIN_MATCH_COUNT:
    src_pts = np.float32([ kp1[m.queryIdx].pt for m in good ]).reshape(-1,1,2)
    dst_pts = np.float32([ kp2[m.trainIdx].pt for m in good ]).reshape(-1,1,2)

    M, mask = cv.findHomography(src_pts, dst_pts, cv.RANSAC,5.0)
    matchesMask = mask.ravel().tolist()

    h,w = query.shape
    pts = np.float32([ [0,0],[0,h-1],[w-1,h-1],[w-1,0] ]).reshape(-1,1,2)
    dst = cv.perspectiveTransform(pts,M)

    scene = cv.polylines(scene,[np.int32(dst)],True,255,3, cv.LINE_AA)

else:
    print( "Not enough matches are found - {}/{}".format(len(good), MIN_MATCH_COUNT) )
    matchesMask = None
    
    

draw_params = dict(matchColor = (0,255,0), # draw matches in green color
                   singlePointColor = None,
                   matchesMask = matchesMask, # draw only inliers
                   flags = 2)

img3 = cv.drawMatches(query,kp1,scene,kp2,good,None,**draw_params)

plt.imshow(img3, 'gray'),plt.show()

print(len(good))