import cv2 as cv
import numpy as np
from typing import overload


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
    #
    # For that reason, we are going to look at
