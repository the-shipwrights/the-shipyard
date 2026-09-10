import cv2 as cv

# captures a photo when ran. Will display it in a window when this happens.
def capture_photo(img_name: str = "captured_image.png"):
    # init webcam (0 is default)
    cam = cv.VideoCapture(0)

    ret, frame = cam.read()

    # checks if we successfully captured from webcam
    if ret:
        cv.imshow("Captured", frame)
        cv.imwrite("captured_image.png", frame)
        cv.waitKey(0) #await key press before continuing
        cv.destroyWindow("Captured")
    else:
        print("failed to capture image")

    cam.release()
