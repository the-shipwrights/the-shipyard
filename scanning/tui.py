"""
Terminal user interface for the scanning application. I really wanted to write a TUI because
TUIs are awesome. Also this should abstract away a lot of the nitty-griity details of model training,
so everyone else should be able to easily interact with it!

NOTICE: AI was used to generate parts of the code, but it is part-human written,
and everything has been thoroughly tested by a human. (Sep 19, 2026)
"""

# ---------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------

from collections.abc import Callable, Sequence
from enum import Enum, auto
from pathlib import Path

from simple_term_menu import TerminalMenu

if __package__:
    from .model_training import model_predict, model_train
else:
    from model_training import model_predict, model_train

# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------

DEFAULT_MODEL = "yolo26n.pt"
RUNS_DIRECTORY = Path("runs/detect")
PREDICTION_RUNS_DIRECTORY = Path("runs/predict")
TRAINING_DATA_DIRECTORY = Path("training_data")
DEFAULT_IMAGE_PATH = Path("test-image.jpg")

MAIN_MENU_OPTIONS = (
    "🕮  TRAIN BOAT-VISION",
    "👁  BEAR WITNESS TO BOATS",
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
    QUIT = auto()


# ---------------------------------------------------------------------------
# TUI application
# ---------------------------------------------------------------------------

class App:
    """Own application state and coordinate the terminal event loop."""

    def __init__(
        self,
        *,
        options: Sequence[str] = MAIN_MENU_OPTIONS,
        menu_factory: Callable[[Sequence[str]], TerminalMenu] = TerminalMenu,
        current_weights: str | Path | None = None,
        runs_directory: str | Path = RUNS_DIRECTORY,
        training_data_directory: str | Path = TRAINING_DATA_DIRECTORY,
    ) -> None:
        self.state = State.MENU
        self.options = tuple(options)
        self._menu_factory = menu_factory
        self.current_weights = (
            Path(current_weights) if current_weights is not None else None
        )
        self.runs_directory = Path(runs_directory)
        self.training_data_directory = Path(training_data_directory)

    # ------------------------------------------------------------------
    # Main event loop
    # ------------------------------------------------------------------

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

    # ------------------------------------------------------------------
    # Main menu
    # ------------------------------------------------------------------

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
        options += [str(path) for path in model_paths] + ["GO BACK"]
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
        paths.extend(self.runs_directory.glob("train*/weights/best.pt"))
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
            path for path in self.training_data_directory.iterdir()
            if path.is_dir()
        ) if self.training_data_directory.is_dir() else []
        if not datasets:
            raise FileNotFoundError(
                f"No training datasets found in {self.training_data_directory}.\nPlease Download one that is formatted for YOLO, and put in the directory."
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

    def _run_training(self, model: str | Path | None, dataset: Path, epochs: int) -> None:
        self.current_weights = Path(
            model_train(model=model, dataset=dataset, epochs=epochs)
        )
        self.state = State.MENU

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

            while True:
                mode = self._select_prediction_mode()
                if mode is None:
                    break

                if mode == "IMAGE":
                    image_path = self._select_prediction_image()
                    if image_path is None:
                        continue
                    model_predict(model=model, mode="image", path=image_path)
                else:
                    model_predict(model=model, mode="realtime")

                self.state = State.MENU
                return

    def _select_prediction_mode(self) -> str | None:
        """Select camera snapshot, realtime camera, image, or go back."""
        options = (
            "REALTIME WITH SNAPSHOTTING",
            "SINGLE IMAGE",
            "GO BACK",
        )
        selection = self._menu_factory(options).show()
        if selection is None or selection == 3:
            return None
        if not isinstance(selection, int) or not 0 <= selection < 3:
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

    # ------------------------------------------------------------------
    # Application lifecycle
    # ------------------------------------------------------------------

    def quit(self) -> None:
        self.state = State.QUIT


def main() -> None:
    App().run()


if __name__ == "__main__":
    main()
