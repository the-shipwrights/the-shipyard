"""
Terminal user interface for the scanning application. I really wanted to write a TUI because
TUIs are awesome. Also this should abstract away a lot of the nitty-griity details of model training,
so everyone else should be able to easily interact with it!

NOTICE: AI was used to generate parts of the code, but it is part-human written,
and everything has been thoroughly tested by a human. (Sep 19, 2026)

god i fucking hate writing python when the library im working with is so bad that Ty (lsp) keeps
flagging everything it does as errors (I CANT FIX THEM, LEAVE ME ALONE, TY. ITS NOT IN MY HANDS)
"""

# ---------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path

from numpy import ndarray
from simple_term_menu import TerminalMenu

from .boat import Boat
from .event_links import boat_page_url, print_boat_qr
from .model_interface import model_predict_cam, model_predict_single, model_train
from .parse_prediction import parse
from .submit_boat import submit_scanned_boat

# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------
DEFAULT_MODEL               = "yolo26n.pt"
SCANNING_DIRECTORY          = Path(__file__).resolve().parent
RUNS_DIRECTORY              = SCANNING_DIRECTORY / "runs/detect"
PREDICTION_RUNS_DIRECTORY   = SCANNING_DIRECTORY / "runs/predict"
TRAINING_DATA_DIRECTORY     = SCANNING_DIRECTORY / "training_data"
DEFAULT_IMAGE_PATH          = (
    TRAINING_DATA_DIRECTORY
    / "wooden_block_symbols/images/train/scene_00010.jpg"
)

MAIN_MENU_OPTIONS           = (
    "🕮  PRACTICE BOAT-VISION (train)",
    "👁  BEAR WITNESS TO BOATS (predict)",
    "🖾  FATHOM OBSERVATION (parse)",
    "✖  QUIT",
)


# ---------------------------------------------------------------------------
# Application state
# ---------------------------------------------------------------------------
class State(Enum):
    """The screens handled by the application event loop."""

    MENU = auto()
    TRAINING = auto()
    PREDICTING = auto()
    PARSING = auto()
    QUIT = auto()

@dataclass
class Latest:
    """dataclass for all things related to prediction. contains everything needed. no boats because that is handled by parser"""
    detections  : list      | None = None  # list of predictions from results. It's basically a dict I think.
    image_frame : ndarray   | None = None  # the image itself. Sorta nice to send along. might not get anything done to it.
    image_height: int       | None = None   # image height, as requested by Filip



class App:
    # ------------------------------------------------------------------
    # App Life cycle
    # ------------------------------------------------------------------
    def __init__(
        self,
        *,
        options                 : Sequence[str] = MAIN_MENU_OPTIONS,
        menu_factory            : Callable[..., TerminalMenu] = TerminalMenu,
        current_weights         : str  | Path | None = None,
        runs_directory          : str  | Path = RUNS_DIRECTORY,
        train_data_dir          : str  | Path = TRAINING_DATA_DIRECTORY,
        latest_prediction       : dict | None = None,
        latest_boat             : Boat | None = None,

        # New dataclass here!
        latest                  : Latest | None = None
    ) -> None:
        self.state              = State.MENU
        self.options            = tuple(options)
        self._menu_factory      = menu_factory
        self.current_weights    = (
            Path(current_weights) if current_weights is not None else None
        )
        self.runs_directory     = Path(runs_directory)
        self.train_data_dir     = Path(train_data_dir)
        self.latest_prediction  = latest_prediction
        self.latest_boat        = latest_boat

        # new dataclass here!
        self.latest             = latest
        self._parse_snapshots   = False

    def _on_snapshot(self, detections: list[dict], image_frame, image_height) -> None:
        """Store a snapshot and optionally parse and handle its boat."""

        self.latest_prediction = {"detections": detections, "image_height": image_height}

        # We send detections, image_frame, and image_height.
        self.latest = Latest(detections=detections, image_frame=image_frame, image_height=image_height)
        if self._parse_snapshots:
            self._parse_snapshot_and_choose()

    def run(self) -> None:
        """Run until the user explicitly selects Quit.

        ``TerminalMenu.show`` returns ``None`` when the menu is cancelled
        (for example with Escape).  Cancelling is not the same as choosing
        Quit, so the menu remains active.
        """
        while self.state is not State.QUIT:
            if self.state is State.MENU:
                self._show_main_menu()
            elif self.state is State.TRAINING:
                self._show_train_menu()
            elif self.state is State.PREDICTING:
                self._show_prediction_menu()
            elif self.state is State.PARSING:
                self._show_parsing_menu()

    def quit(self) -> None:
        self.state = State.QUIT
        raise SystemExit

    def _show_main_menu(self) -> None:
        """Display the main menu and transition to the selected screen."""
        menu = self._menu_factory(self.options)
        selection = menu.show()

        if selection is None:
            return
        if not isinstance(selection, int) or not 0 <= selection < len(self.options):
            raise RuntimeError(f"Menu returned invalid selection: {selection!r}")

        if selection == 0:
            self.state = State.TRAINING
        elif selection == 1:
            self.state = State.PREDICTING
        elif selection == 2:
            self.state = State.PARSING
        elif selection == 3:
            self.quit()
        else:
            raise RuntimeError(f"Menu option has no action: {selection}")


    # ------------------------------------------------------------------
    # model selection
    # ------------------------------------------------------------------
    def _select_model(self, *, include_default: bool) -> tuple[str | Path | None, bool]:
        """Select model weights, optionally including the default model."""
        model_paths = self._available_model_paths()
        options = ([f"USE DEFAULT MODEL ({DEFAULT_MODEL})"] if include_default else [])
        project_root = SCANNING_DIRECTORY.parent
        options += [
            str(path.relative_to(project_root)) if path.is_relative_to(project_root)
            else str(path)
            for path in model_paths
        ] + ["GO BACK"]
        selection = self._menu_factory(options).show()

        if selection is None or selection == len(options) - 1:
            return None, True
        if not isinstance(selection, int) or not 0 <= selection < len(options):
            raise RuntimeError(f"Model menu returned invalid selection: {selection!r}")
        if include_default and selection == 0:
            return None, False
        path_index = selection - 1 if include_default else selection
        return model_paths[path_index], False

    def _available_model_paths(self) -> list[Path]:
        """Return unique trained model weights in stable order."""
        paths = (
            [self.current_weights] if self.current_weights is not None else []
        )
        paths.extend(self.runs_directory.glob("*/weights/best.pt"))
        return sorted({path for path in paths if path.is_file()})


    # ------------------------------------------------------------------
    # Training workflow
    # ------------------------------------------------------------------
    def _show_train_menu(self) -> None:
        """Run model selection, dataset selection, and training confirmation."""
        while True:
            model, went_back = self._select_model(include_default=True)
            if went_back:
                self.state = State.MENU
                return

            dataset = self._select_dataset()
            if dataset is None:
                continue

            epochs = self._select_epochs()
            if epochs is None:
                continue

            if not self._confirm_training(model, dataset, epochs):
                continue

            self._run_training(model, dataset, epochs)
            return

    def _select_dataset(self) -> Path | None:
        """Select a dataset, or return to model selection."""
        datasets = sorted(
            path for path in self.train_data_dir.iterdir()
            if path.is_dir()
        ) if self.train_data_dir.is_dir() else []
        if not datasets:
            raise FileNotFoundError(
                f"No training datasets found in {self.train_data_dir}.\nPlease Download one that is formatted for YOLO, and put in the directory."
            )

        options = [str(path) for path in datasets] + ["GO BACK"]
        selection = self._menu_factory(options).show()
        if selection is None or selection == len(datasets):
            return None
        if not isinstance(selection, int) or not 0 <= selection < len(datasets):
            raise RuntimeError(
                f"Dataset menu returned invalid selection: {selection!r}"
            )
        return datasets[selection]

    def _select_epochs(self) -> int | None:
        """Read a positive epoch count, or return to dataset selection."""
        while True:
            raw_value = input(
                "ENTER NUMBER OF EPOCHS (OR 'BACK' TO RETURN): "
            ).strip()

            if raw_value.lower() in {"back", "go back", "b"}:
                return None

            try:
                epochs = int(raw_value)
            except ValueError:
                print("INCORRECT INPUT: ENTER A POSITIVE INTEGER.")
                continue

            if epochs <= 0:
                print("INCORRECT INPUT: ENTER A POSITIVE INTEGER.")
                continue

            return epochs

    def _confirm_training(self,model: str | Path | None, dataset: Path, epochs: int) -> bool:
        model_name = model or DEFAULT_MODEL
        options = (
            f"TRAIN {model_name} WITH {dataset} FOR {epochs} EPOCHS",
            "GO BACK",
        )
        selection = self._menu_factory(options).show()
        if selection is None or selection == 1:
            return False
        if selection != 0:
            raise RuntimeError(
                f"Confirmation menu returned invalid selection: {selection!r}"
            )
        return True

    def _run_training(self, model: str | Path | None, dataset: Path, epochs: int) -> None:
        self.current_weights = Path(
            model_train(model=model, dataset=dataset, epochs=epochs)
        )
        self.state = State.MENU


    # ------------------------------------------------------------------
    # Prediction workflow
    # ------------------------------------------------------------------
    def _show_prediction_menu(self) -> None:
        """Select weights and a prediction mode, then return to the main menu."""
        while True:
            if not self._available_model_paths():
                print("NO MODEL WEIGHTS FOUND. TRAIN A MODEL FIRST.")
                self.state = State.MENU
                return

            model, went_back = self._select_model(include_default=False)
            if went_back:
                self.state = State.MENU
                return

            parse_predictions = self._select_parsing()
            if parse_predictions is None:
                continue

            threshold = self._select_thresholding()
            if threshold is None:
                continue

            while True:
                mode = self._select_prediction_mode()
                if mode is None:
                    break

                if mode == "IMAGE":
                    image_path = self._select_prediction_image()
                    if image_path is None:
                        continue
                    self._parse_snapshots = parse_predictions
                    try:
                        model_predict_single(
                            model,
                            image_path,
                            self._on_snapshot,
                            threshold=threshold
                        )
                    finally:
                        self._parse_snapshots = False
                else:
                    camera_index = self._select_camera_index()
                    if camera_index is None:
                        continue
                    self._parse_snapshots = parse_predictions
                    try:
                        model_predict_cam(
                            model,
                            camera_index,
                            self._on_snapshot,
                            threshold=threshold,
                        )
                    finally:
                        self._parse_snapshots = False

                if self.state is State.PARSING:
                    return

                self.state = State.MENU
                return

    def _select_parsing(self) -> bool | None:
        """Choose whether prediction snapshots should be parsed automatically."""
        options = (
            "YES - PARSE AND REVIEW SNAPSHOTS",
            "NO - PREDICT ONLY",
        )
        selection = self._menu_factory(
            options,
            title="PARSE PREDICTION SNAPSHOTS?",
        ).show()
        if selection is None:
            return None
        if selection == 0:
            return True
        if selection == 1:
            return False
        raise RuntimeError(f"Parsing selection menu returned invalid selection: {selection!r}")

    def _parse_snapshot_and_choose(self) -> None:
        """Parse the latest snapshot and submit the boat or discard it."""
        if self.latest_prediction is None:
            raise RuntimeError("Snapshot callback did not store a prediction")

        self.latest_boat = parse(self.latest_prediction)
        options = (
            "SUBMIT PARSED BOAT",
            "DISCARD PARSED BOAT",
        )
        selection = self._menu_factory(options).show()

        if selection == 0:
            if self.latest_boat is None or not self.latest_boat.pieces:
                print("NO PARSED BOAT TO SUBMIT.")
            else:
                self._submit_boat(self.latest_boat)
            self.latest_boat = None
        elif selection == 1 or selection is None:
            self.latest_boat = None
        else:
            raise RuntimeError(f"Snapshot decision menu returned invalid selection: {selection!r}")

        self.state = State.PARSING

    def _select_thresholding(self) -> bool | None:
        """Ask whether prediction inputs should be thresholded."""
        options = (
            "YES - APPLY OTSU THRESHOLDING",
            "NO - USE ORIGINAL IMAGES",
        )
        selection = self._menu_factory(
            options,
            title="APPLY OTSU THRESHOLDING TO PREDICTION INPUTS?",
        ).show()
        if selection is None:
            return None
        if selection == 0:
            return True
        if selection == 1:
            return False
        raise RuntimeError(
            f"Thresholding menu returned invalid selection: {selection!r}"
        )

    def _select_prediction_mode(self) -> str | None:
        """Select camera snapshot, realtime camera, image, or go back."""
        options = (
            "REALTIME WITH SNAPSHOTTING",
            "SINGLE IMAGE",
            "GO BACK",
        )
        selection = self._menu_factory(options).show()
        if selection is None or selection == 2:
            return None
        if not isinstance(selection, int) or not 0 <= selection < 2:
            raise RuntimeError(
                f"Prediction mode menu returned invalid selection: {selection!r}"
            )
        return ("REALTIME", "IMAGE")[selection]

    def _select_prediction_image(self) -> Path | None:
        """Read an image path, using the default when the input is empty."""
        value = input(
            f"ENTER IMAGE PATH (DEFAULT: {DEFAULT_IMAGE_PATH}) "
            "OR 'GO BACK': "
        ).strip()
        if value.lower() in {"back", "go back", "b"}:
            return None
        return Path(value) if value else DEFAULT_IMAGE_PATH

    def _select_camera_index(self) -> int | None:
        """Read a camera index, using camera 0 when the input is empty."""
        while True:
            value = input(
                "ENTER CAMERA INDEX (DEFAULT: 0) OR 'GO BACK'\n\033[90m-> hint: you can check which idx are available with `python camera_indexing.py`\033[91m\n"
            ).strip()
            if value.lower() in {"back", "go back", "b"}:
                return None

            if not value:
                return 0

            try:
                camera_index = int(value)
            except ValueError:
                print("INCORRECT INPUT: ENTER A NON-NEGATIVE INTEGER.")
                continue

            if camera_index < 0:
                print("INCORRECT INPUT: ENTER A NON-NEGATIVE INTEGER.")
                continue

            return camera_index

    def _submit_boat(self, boat: Boat) -> str:
        """Submit a parsed boat and show the participant's ID and QR link."""
        boat_id = submit_scanned_boat(boat)
        url = boat_page_url(boat_id)
        print(f"Boat submitted successfully with ID: {boat_id}")
        print(f"Participant link: {url}")
        print_boat_qr(url)
        return boat_id

    # ------------------------------------------------------------------
    # Parsing workflow
    # ------------------------------------------------------------------
    def _show_parsing_menu(self) -> None:
        """Parse latest prediciton, then return to the main menu."""
        while True:
            if self.latest_prediction is None:
                print("NO PREDICTION FOUND. RUN A PREDICTION FIRST.")
                self.state = State.MENU
                return

            options = (
                        "PARSE LATEST PREDICTION",
                        "PRINT BOAT",
                        "SEND BOAT",
                        "GO BACK",
                    )
            selection = self._menu_factory(options).show()

            if selection == 0:
                self.latest_boat = parse(self.latest_prediction)
                continue
            elif selection == 1:
                if self.latest_boat is None:
                    print("NO BOAT FOUND. PARSE A PREDICTION FIRST.")
                    continue
                else:
                    print(self.latest_boat.to_text())
                    continue
            elif selection == 2:
                if self.latest_boat is None:
                    print("NO BOAT FOUND. PARSE A PREDICTION FIRST.")
                    continue
                else:
                    self._submit_boat(self.latest_boat)
                    continue

            self.state = State.MENU
            return


# ------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------
def main() -> None:
    App().run()


if __name__ == "__main__":
    main()
