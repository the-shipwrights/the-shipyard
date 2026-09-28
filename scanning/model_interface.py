"""
Model training & prediction entry points.

NOTICE: AI was used to generate parts of the code, but a hefty part is human-written,
and **everything** has been thoroughly tested by a human[1]

[1]: (its python: if its not thoroughly tested, it will break)
"""

import tempfile
from collections.abc import Callable
from pathlib import Path

import cv2 as cv
import yaml
from ultralytics import YOLO


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
def model_predict_single(weights_path: Path, img_path: Path) -> None:
    """
    predict a single image. Display result directly on-screen until user exits.
    input: path to model weights, path to image
    return: a print of that bigass log of detected classes and where they are located.
    """
    model = YOLO(weights_path)
    results = model.predict(
        source=img_path,
        stream=False,  # optimizes memory usage, we dont need it here.
        verbose=False, # skip logging results to terminal
    )

    result = results[0] # a list of results. single image predictions are a 1-item list.


    print(result.verbose()) # this prints a list of detected occurences for each class, i.e "1 front, 2 hull"
    print(result.summary()) # this prints each result object in results, very verbose
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
    weights_path: Path,
    camera_idx: int,
    on_snapshot: Callable[[list[dict]], None],
) -> None:
    """
    -> owns camera, prediction stream, window, key handling
    -> publishes snapshots through callback to App in tui.py
    -> returns when q is pressed.
    predict from camera footage. Given a specific input, take a snapshot of
    the data and output it.
    input: path to model weights, camera index, snapshot callback.
    """

    model = YOLO(weights_path)
    results = model.predict(
        source=camera_idx,
        stream=True,
        verbose=False,
    )
    latest_non_empty_summary: list[dict] = []

    try:
        for result in results:
            cv.imshow("Camera prediction", result.plot())
            key = cv.waitKey(1) & 0xFF
            summary = result.summary()

            if summary:
                latest_non_empty_summary = summary

            if key == ord("p"):
                snapshot = summary or latest_non_empty_summary
                on_snapshot(snapshot)
                print(snapshot)
            elif key == ord("q"):
                break
    finally:
        cv.destroyAllWindows()
