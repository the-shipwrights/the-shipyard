import math
import sys
from typing import overload

import cv2 as cv
import numpy as np
from matplotlib import pyplot as plt


# cv.typing.MatLike is OpenCV's type hint for a NumPy array containing pixel data.
# basically an image.
@overload
def capture_photo(camera: int = 0, img_name: None = None) -> cv.typing.MatLike:
    ...

# saves the image to a location in the repository instead.
@overload
def capture_photo(camera: int = 0, img_name: str = "captured_photo.png") -> str:
    ...


# it can either take in an img name or it nothing at all. Sending nothing will return
# the raw image as a NumPy array, otherwise it will return the filepath.
def capture_photo(camera: int = 0 , img_name: str | None = None) -> cv.typing.MatLike | str:
    """Capture a photo and return the image or the path it was saved to."""
    # init webcam (0 is default)
    cam = cv.VideoCapture(camera)

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



def find_feature(query_path: str, scene_path: str) -> tuple[float, float, float, float]:

    query = cv.imread(query_path, cv.IMREAD_GRAYSCALE)
    scene = cv.imread(scene_path, cv.IMREAD_GRAYSCALE)

    if query is None or scene is None:
        raise FileNotFoundError("Could not load input images.")

    # Initiate SIFT detector
    sift = cv.SIFT_create()

    kp1, des1 = sift.detectAndCompute(query, None)
    kp2, des2 = sift.detectAndCompute(scene, None)

    FLANN_INDEX_KDTREE = 1
    index_params = {"algorithm": FLANN_INDEX_KDTREE, "trees": 5}
    search_params = {"checks": 50}

    flann = cv.FlannBasedMatcher(index_params, search_params)
    matches = flann.knnMatch(des1, des2, k=2)

    # Lowe's ratio test
    good = []
    for m, n in matches:
        if m.distance < 0.7 * n.distance:
            good.append(m)

    print(f"Matches found - {len(good)}")

    avg_x = 0.0
    avg_y = 0.0
    distance = 0.0
    angle_deg = 0.0

    if len(good) > 0:
        # Extract pixel locations of matches in scene image
        scene_pts = np.float32([kp2[m.trainIdx].pt for m in good])

        # Calculate centroid of matched points
        avg_x = float(np.mean(scene_pts[:, 0]))
        avg_y = float(np.mean(scene_pts[:, 1]))

        # Calculate scene frame center (Reference Point)
        h, w = scene.shape
        center_x, center_y = w / 2.0, h / 2.0

        # Relative coordinates relative to image center
        dx = avg_x - center_x
        dy = avg_y - center_y  # Positive down in standard image space

        # Distance calculation
        distance = math.hypot(dx, dy)

        # Angle calculation (-180 to 180 degrees)
        # 0 deg = Right, 90 deg = Down, -90 deg = Up, 180/-180 deg = Left
        angle_rad = math.atan2(dy, dx)
        angle_deg = math.degrees(angle_rad)

        #print(f"Centroid: ({avg_x:.2f}, {avg_y:.2f})")
        #print(f"Distance from center: {distance:.2f} px")
        #print(f"Angle from center: {angle_deg:.2f}°")

    draw_params = {
        "matchColor": (0, 255, 0),
        "singlePointColor": None,
        "matchesMask": None,
        "flags": 2
    }

    img3 = cv.drawMatches(query, kp1, scene, kp2, good, None, **draw_params)
    plt.imshow(img3, 'gray')
    plt.show()

    return avg_x, avg_y, distance, angle_deg




def main() -> None:
    cap = cv.VideoCapture(0)
    if not cap.isOpened():
        print("Cannot open camera")
        sys.exit()
    while True:
        # Capture frame-by-frame
        ret, frame = cap.read()

        # if frame is read correctly ret is True
        if not ret:
            print("Can't receive frame (stream end?). Exiting ...")
            break
        # Our operations on the frame come here
        gray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
        # Display the resulting frame
        cv.imshow('frame', gray)
        if cv.waitKey(1) == ord('q'):
            break

    # When everything done, release the capture
    cap.release()
    cv.destroyAllWindows()

if __name__ == "__main__":
    main()
