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

        # cv.imshow("Captured", frame)
        # cv.waitKey(0)  # Await key press before continuing.
       # cv.destroyWindow("Captured")

        if img_name is None:
            return frame

        if not cv.imwrite(img_name, frame):
           raise OSError(f"Failed to save image to {img_name}")

        return img_name
    finally:
      cam.release()



def find_feature(query_path: str, scene_path: str) -> tuple[int, int]:
    MIN_MATCH_COUNT = 10

    # Query is what we're looking for, Scene is where we are looking.
    query = cv.imread(query_path, cv.IMREAD_GRAYSCALE)       # queryImage
    scene = cv.imread(scene_path, cv.IMREAD_GRAYSCALE)           # trainImage

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


    '''
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
    '''
    print( "Matches found - {}".format(len(good)))
    matchesMask = None
        

    draw_params = dict(matchColor = (0,255,0), # draw matches in green color
                    singlePointColor = None,
                    matchesMask = matchesMask, # draw only inliers
                    flags = 2)

    img3 = cv.drawMatches(query,kp1,scene,kp2,good,None,**draw_params)

    avg_x = 0
    avg_y = 0

    if len(good) > 0:
        for match in good:             
            point = kp2[match.trainIdx].pt
            
            avg_x += point[0]
            avg_y += point[1] 
        
        avg_x = avg_x /len(good)
        avg_y = avg_y/len(good)

    print(avg_x, avg_y)

    plt.imshow(img3, 'gray'),plt.show()

    return avg_x, avg_y




capture_photo("selfie.png")

find_feature("matchpic-box.png", "bgscene.png")

find_feature("matchpic-smile.png", "bgscene.png")


