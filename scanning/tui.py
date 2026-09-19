"""
Terminal user interface for the scanning application. I really wanted to write a TUI because
TUIs are awesome. Also this should abstract away a lot of the nitty-griity details of model training,
so everyone else should be able to easily interact with it!

NOTICE: AI was used to generate parts of the code, but a hefty part is human-written,
and everything has been thoroughly tested by a human. (Sep 19, 2026)
"""

# ---------------------------------------------------------------------------
# Imports
# ---------------------------------------------------------------------------

from collections.abc import Callable, Sequence
from enum import Enum, auto
from pathlib import Path

from model_training import model_predict, model_train
from simple_term_menu import TerminalMenu

# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------

DEFAULT_MODEL = "yolo26n.pt"
RUNS_DIRECTORY = Path("runs/detect")
TRAINING_DATA_DIRECTORY = Path("training_data")

MAIN_MENU_OPTIONS = (
    "🕮 TRAIN A MODEL",
    "👁 PREDICT CONTENTS",
    "✖ QUIT",
)
# Backwards-compatible name for callers that import the menu options.
MENU_OPTIONS = MAIN_MENU_OPTIONS


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
    # Training workflow
    # ------------------------------------------------------------------

    def _show_train_menu(self) -> None:
        """Run model selection, dataset selection, and training confirmation."""
        while True:
            model, went_back = self._select_model()
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

    def _select_model(self) -> tuple[str | Path | None, bool]:
        """Select the base model, or return to the main menu."""
        model_paths = sorted(
            path / "weights" / "best.pt"
            for path in self.runs_directory.glob("train*/")
            if (path / "weights" / "best.pt").is_file()
        )
        options = [f"USE DEFAULT MODEL ({DEFAULT_MODEL})"] + [
            str(path) for path in model_paths
        ] + ["GO BACK"]
        selection = self._menu_factory(options).show()

        if selection is None or selection == len(options) - 1:
            return None, True
        if not isinstance(selection, int) or not 0 <= selection < len(options):
            raise RuntimeError(f"Model menu returned invalid selection: {selection!r}")
        return (None if selection == 0 else model_paths[selection - 1], False)

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
        """
        ask the user if they would like to:

            a) show camera stream and allow user input to take a snapshot of current prediction (saves ultralytics bounding boxes and their classes)
            b) predict camera stream in real-time (for demo & testing purposes only)
            c) predict a specific image (for testing purposes only)
                If c) ask the user to input path to the specified image, use default if no input.
            d) change current weights
                if d) show user a list of weights and let them select one.
                    if no weights are present, tell them to go back and train a model first.

            once predictions are complete or if the user exists the camera stream, we should return to the main menu.
        """
        model_predict()
        self.state = State.MENU

    # ------------------------------------------------------------------
    # Application lifecycle
    # ------------------------------------------------------------------

    def quit(self) -> None:
        """Stop the event loop after an explicit user choice."""
        self.state = State.QUIT


def main() -> None:
    """Start the terminal application."""
    App().run()


if __name__ == "__main__":
    main()
