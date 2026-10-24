"""
Model training & prediction entry points. ANSI codes my beloved.

NOTICE: AI was used to generate parts of the code, but a hefty part is human-written,
and **everything** has been thoroughly tested by a human[1]

[1]: (its python: if its not thoroughly tested, it will break)
"""
import select
import shutil
import sys
import tempfile
from collections.abc import Callable
from datetime import datetime
from pathlib import Path

import cv2 as cv
import yaml
from numpy import ndarray
from ultralytics import YOLO

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PREDICTION_RUNS_DIRECTORY = Path(__file__).resolve().parent / "runs" / "predict"


def _display_path(path: Path) -> str:
    """Format a path relative to the project root for console output."""
    return path.resolve().relative_to(PROJECT_ROOT).as_posix()


# Copilot generated function based on a very verbose description to make it really pretty.
def format_detections(detections: list[dict]) -> str:
    """Format detections on one line each with colored labels and box coordinates."""
    if not detections:
        return "No detections."

    names = [str(detection.get("name", "unknown")) for detection in detections]
    confidences = [
        f"{detection['confidence']:.2%}"
        if detection.get("confidence") is not None
        else ""
        for detection in detections
    ]
    name_width = max(map(len, names))
    confidence_width = max(map(len, confidences))

    lines = []
    for detection, name, confidence_text in zip(
        detections, names, confidences, strict=True
    ):
        confidence = detection.get("confidence")
        line = f"\033[48;2;0;95;95m\033[97m{name.ljust(name_width)}\033[0m"
        if confidence is not None:
            confidence_color = (
                "\033[32m" if confidence > 0.85
                else "\033[33m" if confidence > 0.5
                else "\033[31m"
            )
            line += f" {confidence_color}{confidence_text.rjust(confidence_width)}\033[0m"
        else:
            line += f" {' ' * confidence_width}"

        box = detection.get("box")
        if box is not None:
            coordinates = ", ".join(
                f"{key}={value:8.2f}" if isinstance(value, (int, float))
                else f"{key}={value}"
                for key, value in box.items()
            )
            line += f" \033[90m{{{coordinates}}}\033[0m"
        lines.append(line)
    return "\n".join(lines)


def _prepare_terminal_output(*, scroll: bool = False) -> None:
    """Optionally scroll terminal output and restore default text formatting."""
    if sys.stdout.isatty():
        if scroll:
            sys.stdout.write("\n" * shutil.get_terminal_size().lines)
        sys.stdout.write("\033[0m")
        sys.stdout.flush()


def _terminal_key() -> int | None:
    """Read a pending terminal p/q command without blocking the camera loop."""
    if not sys.stdin.isatty() or not select.select([sys.stdin], [], [], 0)[0]:
        return None
    command = sys.stdin.readline().strip().lower()
    return ord(command) if command in {"p", "q"} else None


def _dataset_yaml(dataset: str | Path) -> Path:
    dataset_path = Path(dataset).expanduser()
    data_file = (
        dataset_path / "data.yaml"
        if dataset_path.is_dir()
        else dataset_path
    )
    if not data_file.is_file():
        raise FileNotFoundError(f"Dataset YAML file does not exist: {data_file}")
    return data_file


# Copilot generated this function. this ensures that the yaml file can work across different devices.
def _portable_dataset_yaml(data_file: Path) -> tuple[Path, tempfile.TemporaryDirectory[str] | None]:
    with data_file.open(encoding="utf-8") as stream:
        configuration = yaml.safe_load(stream)

    if not isinstance(configuration, dict):
        raise TypeError(f"Dataset YAML must contain a mapping: {data_file}")

    configured_root = configuration.get("path")
    if configured_root is None:
        root = data_file.parent
    else:
        root = Path(configured_root).expanduser()
        if not root.is_absolute():
            candidate = data_file.parent / root
            root = candidate if candidate.exists() else data_file.parent

    configuration["path"] = str(root.resolve())
    temporary_directory = tempfile.TemporaryDirectory()
    portable_file = Path(temporary_directory.name) / data_file.name
    portable_file.write_text(
        yaml.safe_dump(configuration, sort_keys=False),
        encoding="utf-8",
    )
    return portable_file, temporary_directory


def _threshold_frame(frame: cv.typing.MatLike) -> cv.typing.MatLike:
    """Convert a color frame to a three-channel binary image using Otsu thresholding. how """
    grayscale = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
    _, binary = cv.threshold(
        grayscale,
        0,
        255,
        cv.THRESH_BINARY | cv.THRESH_OTSU,
    )
    return cv.cvtColor(binary, cv.COLOR_GRAY2BGR)


def model_train(
    model: str | Path | None = None,
    dataset: str | Path = "wooden_block_symbols",
    epochs: int = 10,
    imgsz: int = 640,
) -> str | Path:
    if not isinstance(epochs, int) or epochs <= 0:
        raise ValueError("epochs must be a positive integer")
    if not isinstance(imgsz, int) or imgsz <= 0:
        raise ValueError("imgsz must be a positive integer")

    # quick fix to allow for portability, otherwise ultralytics would complain.
    data_file = _dataset_yaml(dataset)
    portable_data_file, temporary_directory = _portable_dataset_yaml(data_file)

    try:
        yolo_model = YOLO(model or "yolo26n.pt")

        results = yolo_model.train(
            data=str(portable_data_file),
            epochs=epochs,
            imgsz=imgsz,
        )
    finally:
        if temporary_directory is not None:
            temporary_directory.cleanup()

    return Path(results.save_dir) / "weights" / "best.pt"



#  docs: (https://docs.ultralytics.com/modes/predict)
def model_predict_single(
    weights_path: Path | str | None,
    img_path: Path,
    on_snapshot: Callable[[list[dict], ndarray, int], None],
    threshold: bool = False,
) -> None:
    """
    predict a single image. Display result directly on-screen until user exits.
    input: path to model weights, path to image
    return: a print of that bigass log of detected classes and where they are located.
    """

    if weights_path == None:
        raise ValueError("oh no, the weights path is set to None! This is really bad. Don't call model_predict_single unless you have a valid path!!!!")

    model = YOLO(weights_path)
    image = cv.imread(str(img_path))
    if image is None:
        raise FileNotFoundError(f"Could not load image: {img_path}")
    original_image = image.copy()
    if threshold:
        image = _threshold_frame(image)

    results = model.predict(
        source=image,
        stream=False,  # optimizes memory usage, we dont need it here.
        verbose=False, # skip logging results to terminal
    )

    result = results[0] # a list of results. single image predictions are a 1-item list.  # ty: ignore[not-subscriptable]

    snapshot_directory = PREDICTION_RUNS_DIRECTORY
    snapshot_directory.mkdir(parents=True, exist_ok=True)
    snapshot_name = (
        f"{Path(img_path).stem}-{datetime.now():%y%m%d-%H%M%S}"  # noqa: DTZ005
    )
    annotated_path = snapshot_directory / f"{snapshot_name}.jpg"
    original_path = snapshot_directory / f"{snapshot_name}-original.jpg"
    if not cv.imwrite(str(annotated_path), result.plot()):  # ty: ignore[unresolved-attribute]
        raise OSError(f"Failed to save annotated prediction to {annotated_path}")
    if not cv.imwrite(str(original_path), original_image):
        raise OSError(f"Failed to save original input image to {original_path}")

    on_snapshot(result.summary(), image, image.shape[0])  # ty: ignore[unresolved-attribute]

    print(format_detections(result.summary()))  # ty: ignore[unresolved-attribute]
    print(f"\033[90mAnnotated prediction saved to {_display_path(annotated_path)}\033[0m")
    print(f"Original image saved to {_display_path(original_path)}")
    # The naming for these methods makes no sense at all. wtf @ultralytics??

    """result.summary() has this shape (data not representative):
    {
        "name": "boat",
        "class": 0,
        "confidence": 0.93,
        "box": {
            "x1": 120.0,
            "y1": 85.0,
            "x2": 410.0,
            "y2": 300.0,
        },
    }
    """


def model_predict_cam(
    weights_path: str | Path | None,
    camera_idx: int,
    on_snapshot: Callable[[list[dict], ndarray, int], None],
    threshold: bool = False,
) -> None:
    """
    -> owns camera, prediction stream, window, key handling
    -> publishes snapshots through callback to App in tui.py
    -> returns when q is pressed.
    predict from camera footage. Given a specific input, take a snapshot of
    the data and output it.
    input: path to model weights, camera index, snapshot callback.
    """
    if weights_path == None:
        raise ValueError("weights path is empty! Not good... It should be assigned before calling model_predict_cam")

    model = YOLO(weights_path)
    camera = cv.VideoCapture(camera_idx)
    if not camera.isOpened():
        camera.release()
        raise RuntimeError(f"Could not open camera index {camera_idx}")

    latest_non_empty_summary: list[dict] = []
    snapshot_directory = PREDICTION_RUNS_DIRECTORY
    terminal_scrolled = False

    try:
        while True:
            success, original_frame = camera.read()
            if not success:
                raise RuntimeError(
                    f"Failed to read a frame from camera index {camera_idx}"
                )

            model_frame = (
                _threshold_frame(original_frame) if threshold else original_frame
            )
            results = model.predict(source=model_frame, verbose=False)
            result = results[0]  # ty: ignore[not-subscriptable]
            frame = result.plot()  # ty: ignore[unresolved-attribute]
            cv.imshow("Camera prediction", frame)
            key = cv.waitKey(1) & 0xFF
            terminal_key = _terminal_key()
            if terminal_key is not None:
                key = terminal_key
            _prepare_terminal_output(scroll=not terminal_scrolled)
            terminal_scrolled = True
            summary = result.summary()  # ty: ignore[unresolved-attribute]

            if summary:
                latest_non_empty_summary = summary

            if key == ord("p"):
                snapshot = summary or latest_non_empty_summary
                snapshot_directory.mkdir(parents=True, exist_ok=True)
                snapshot_name = (
                    f"{datetime.now():%y%m%d-%H%M%S}"  # noqa: DTZ005
                )
                annotated_path = snapshot_directory / f"{snapshot_name}.jpg"
                original_path = snapshot_directory / f"{snapshot_name}-original.jpg"
                if not cv.imwrite(str(annotated_path), frame):
                    raise OSError(
                        f"Failed to save annotated camera snapshot to {annotated_path}"
                    )
                if not cv.imwrite(str(original_path), original_frame):
                    raise OSError(
                        f"Failed to save original camera snapshot to {original_path}"
                    )
                on_snapshot(snapshot, frame, frame.shape[0])
                print(format_detections(snapshot))
                print(f"\033[90mAnnotated snapshot saved to {_display_path(annotated_path)}\033[0m")
                print(f"Original snapshot saved to {_display_path(original_path)}")

            elif key == ord("q"):
                camera.release()
                break
    finally:
        try:
            camera.release()
        finally:
            cv.destroyAllWindows()
