"""
Model training & prediction entry points.

NOTICE: AI was used to generate parts of the code, but a hefty part is human-written,
and everything has been thoroughly tested by a human. (Sep 19, 2026)
"""

import tempfile
from pathlib import Path

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


# NOTE: we could also not have a mode parameter and instead check if img is path or none instead.
# using mode parameters feels more human-readable though.
def model_predict(model, mode, img: Path | None = None):
    if mode == mode.realtime: # TODO: implement mode enum.
        print("realtime")
    elif mode == mode.image:
        print("single image")
