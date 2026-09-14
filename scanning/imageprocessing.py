import cv2 as cv
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


# For sending the boat to the api
"""
import requests

response = requests.post(
    "http://localhost:8000/api/boats",
    json=boat.to_dict(),
    timeout=10,
)

response.raise_for_status()

result = response.json()
boat_id = result["id"]

print(f"Open: http://localhost:5173/boat/{boat_id}")
"""
