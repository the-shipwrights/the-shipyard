from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Container, Grid, Horizontal, Vertical
from textual.widgets import (
    Button,
    DirectoryTree,
    Footer,
    Header,
    Label,
    ListItem,
    ListView,
    RichLog,
    Static,
)

SNAPSHOT_DIRECTORY = Path("scanning/runs/predict/snapshots")


class Tui(App):

    theme = "ansi-dark"
    CSS = """
    #quadrants {
        layout: grid;
        grid-size: 2 1;
        grid-columns: 1fr 2fr;
        grid-rows: 1fr;
        height: 1fr;
        width: 1fr;
    }
    .quadrant {
        border: round $accent;
        padding: 1;
    }
    #logo_panel {
        border: none;
        padding: 0;
    }
    #left_column {
        height: 1fr;
    }
    #left_column > .quadrant {
        height: 1fr;
    }
    #logo_panel {
        display: none;
    }
    #logo_panel.visible {
        display: block;
    }
    #right_column {
        display: none;
        height: 1fr;
        width: 1fr;
    }
    #right_column.visible {
        display: block;
    }
    #mode_view, #file_selection {
        height: 1fr;
        width: 1fr;
    }
    #state_panel {
        display: none;
    }
    #state_panel.visible {
        display: block;
    }
    #file_selection {
        display: none;
    }
    #file_selection.visible {
        display: block;
    }
    #mode_view.hidden {
        display: none;
    }
    #directory_tree {
        height: 1fr;
    }
    #main_menu {
        width: 1fr;
        height: 1fr;
    }
    #app_state {
        height: auto;
        margin-bottom: 1;
    }
    #action_buttons {
        height: auto;
        layout: horizontal;
    }
    #action_buttons Button {
        width: 1fr;
        margin-right: 1;
    }
    #console_title {
        margin-top: 1;
        text-style: bold;
    }
    #logo {
        width: 1fr;
        height: 1fr;
        content-align: center middle;
        color: $accent;
        text-style: bold;
    }
    #console_log {
        height: 1fr;
        border: round $primary;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._boat_observation_step: str | None = None
        self._available_models: list[Path] = []
        self._selected_model: Path | None = None
        self._use_livecam = False
        self._use_otsu = False

    def compose(self) -> ComposeResult:
        yield Header()

        with Grid(id="quadrants"):
            with Vertical(id="left_column"):
                with Container(classes="quadrant", id="logo_panel"):
                    yield Static(
                        r"""
▗▄▄▖  ▗▄▖  ▗▄▖▗▄▄▄▖     ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▄▖
▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌ █      ▐▌   ▐▌   ▐▌   ▐▌ ▐▌
▐▛▀▚▖▐▌ ▐▌▐▛▀▜▌ █       ▝▀▚▖▐▛▀▀▘▐▛▀▀▘▐▛▀▚▖
▐▙▄▞▘▝▚▄▞▘▐▌ ▐▌ █      ▗▄▄▞▘▐▙▄▄▖▐▙▄▄▖▐▌ ▐▌

interface for boat detection (version 0.1)
                    """.strip("\n"),
                        id="logo",
                    )

                with Container(classes="quadrant", id="menu_panel"):
                    yield Static("Selection menu", classes="panel_title")
                    yield ListView(
                        ListItem(Label("PRACTICE BOAT VISION")),
                        ListItem(Label("OBSERVE BOATS")),
                        ListItem(Label("FATHOM OBSERVATION")),
                        id="main_menu",
                    )

            with Container(id="right_column"):
                with Vertical(id="mode_view"):
                    with Container(classes="quadrant", id="state_panel"):
                        yield Static("App state: Ready", id="app_state")
                        with Horizontal(id="action_buttons"):
                            yield Button("Capture snapshot", id="capture_snapshot_button")
                            yield Button("Exit predict mode", id="exit_predict_button")

                    with Container(classes="quadrant", id="files_and_logs"):
                        yield Static("Console logs", id="console_title")
                        yield RichLog(id="console_log", wrap=True, markup=False)

                with Container(classes="quadrant", id="file_selection"):
                    yield Static("Select a file", id="file_selection_title")
                    yield DirectoryTree(Path.cwd(), id="directory_tree")
                    yield Static("No file selected", id="selected_file")
                    yield Button("Done", id="file_selection_done")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#console_log", RichLog).write("TUI started.")
        self.call_after_refresh(self._update_logo_visibility)

    def on_resize(self, event) -> None:
        self.call_after_refresh(self._update_logo_visibility)

    def _update_logo_visibility(self) -> None:
        """Show the logo only when its panel has enough room to stay legible."""
        left_column = self.query_one("#left_column")
        logo_panel = self.query_one("#logo_panel")

        if left_column.size.width > 46 and self.size.height >= 6:
            logo_panel.add_class("visible")
        else:
            logo_panel.remove_class("visible")

    async def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Dispatch each main-menu item to its corresponding workflow."""
        if self._boat_observation_step is not None:
            await self._handle_boat_observation_choice(event.index)
            return

        if event.index == 0:
            # TODO : Wire the training selections to dataset/epoch setup and model_train.
            self._select_action("Training")
        elif event.index == 1:
            await self._begin_boat_observation()
        elif event.index == 2:
            # TODO : Connect prediction parsing to the latest prediction and boat submission.
            self._select_action("Prediction parsing")
        else:
            self._write_log(f"Unhandled menu selection at index {event.index}.")

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "capture_snapshot_button":
            # TODO : Capture a camera frame, persist it, and notify only after the write succeeds.
            message = f"Captured snapshot to {SNAPSHOT_DIRECTORY}/"
            self.notify(message, title="Snapshot captured")
            self._write_log(message)
            return
        if event.button.id == "exit_predict_button":
            await self._exit_predict_mode()
            return

    async def _begin_boat_observation(self) -> None:
        # TODO: Reuse the configured runs directory instead of assuming this working-directory path.
        self._available_models = sorted(
            path
            for path in Path("scanning/runs/detect").glob("train*/weights/best.pt")
            if path.is_file()
        )
        self._selected_model = None
        self._boat_observation_step = "model"
        choices = (
            [str(path) for path in self._available_models]
            if self._available_models
            else ["No trained models found"]
        )
        choices.append("GO BACK")
        await self._show_choices("Select a model", choices)
        self.query_one("#right_column").add_class("visible")
        self.query_one("#state_panel").remove_class("visible")
        self._write_log("Boat observation: select a model.")

    async def _handle_boat_observation_choice(self, index: int) -> None:
        step = self._boat_observation_step
        if step == "model":
            if not self._available_models:
                if index == 0:
                    self._write_log("No trained models were found.")
                else:
                    await self._cancel_boat_observation()
                return
            if index == len(self._available_models):
                await self._cancel_boat_observation()
                return
            if not 0 <= index < len(self._available_models):
                self._write_log(f"Invalid model selection: {index}.")
                return

            self._selected_model = self._available_models[index]
            self._boat_observation_step = "livecam"
            await self._show_choices(
                "Use livecam footage with snapshotting?",
                ["YES", "NO", "GO BACK"],
            )
            self._write_log(f"Selected model: {self._selected_model}")
            return

        if step == "livecam":
            if index == 2:
                await self._cancel_boat_observation()
                return
            if index not in (0, 1):
                self._write_log(f"Invalid livecam selection: {index}.")
                return
            self._use_livecam = index == 0
            self._boat_observation_step = "otsu"
            await self._show_choices("Use Otsu's thresholding?", ["YES", "NO", "GO BACK"])
            self._write_log(
                f"Livecam snapshotting: {'yes' if self._use_livecam else 'no'}."
            )
            return

        if step == "otsu":
            if index == 2:
                await self._cancel_boat_observation()
                return
            if index not in (0, 1):
                self._write_log(f"Invalid Otsu selection: {index}.")
                return
            self._use_otsu = index == 0
            if self._use_livecam:
                self._boat_observation_step = "livecam_active"
                await self._show_livecam_controls()
            else:
                # TODO: Add image-file selection and run single-image prediction in this branch.
                self._boat_observation_step = "image_active"
                self.query_one("#state_panel").remove_class("visible")
                self.query_one("#app_state", Static).update(
                    "App state: Image prediction mode"
                )
                await self._show_choices("Boat observation", ["GO BACK"])
            self._write_log(
                f"Otsu thresholding: {'enabled' if self._use_otsu else 'disabled'}."
            )
            return

        if step in {"livecam_active", "image_active"}:
            await self._exit_predict_mode()

    async def _show_choices(self, title: str, choices: list[str]) -> None:
        self.query_one("#menu_panel .panel_title", Static).update(title)
        menu = self.query_one("#main_menu", ListView)
        await menu.clear()
        await menu.extend(ListItem(Label(choice)) for choice in choices)
        menu.index = 0 if choices else None

    async def _show_livecam_controls(self) -> None:
        self.query_one("#right_column").add_class("visible")
        self.query_one("#mode_view").remove_class("hidden")
        self.query_one("#file_selection").remove_class("visible")
        self.query_one("#state_panel").add_class("visible")
        self.query_one("#app_state", Static).update(
            "Currently in livecam footage mode\n"
            f"Model: {self._selected_model}\n"
            f"Otsu thresholding: {'used' if self._use_otsu else 'not used'}"
        )
        await self._show_choices("Boat observation", ["GO BACK"])

    async def _cancel_boat_observation(self) -> None:
        self._boat_observation_step = None
        self._selected_model = None
        await self._restore_main_menu()
        self._write_log("Boat observation setup cancelled.")

    async def _exit_predict_mode(self) -> None:
        self.query_one("#state_panel").remove_class("visible")
        self._boat_observation_step = None
        self._selected_model = None
        await self._restore_main_menu()
        self._write_log("Exited prediction mode.")

    async def _restore_main_menu(self) -> None:
        await self._show_choices(
            "Selection menu",
            [
                "PRACTICE BOAT VISION",
                "OBSERVE BOATS",
                "FATHOM OBSERVATION",
            ],
        )

    def _select_action(self, action: str) -> None:
        self.query_one("#right_column").add_class("visible")
        self.query_one("#app_state", Static).update(f"App state: {action}")
        # TODO: Replace the generic action with actual implementation.
        self._write_log(f"Selected {action} workflow.")

    def _show_file_selection(self) -> None:
        self.query_one("#right_column").add_class("visible")
        self.query_one("#mode_view").add_class("hidden")
        self.query_one("#file_selection").add_class("visible")
        self.query_one("#directory_tree", DirectoryTree).focus()

    def _hide_file_selection(self) -> None:
        self.query_one("#file_selection").remove_class("visible")
        self.query_one("#mode_view").remove_class("hidden")

    def on_directory_tree_file_selected(
        self, event: DirectoryTree.FileSelected
    ) -> None:
        self.query_one("#selected_file", Static).update(str(event.path))
        self._write_log(f"Selected file: {event.path}")

    def _write_log(self, message: str) -> None:
        self.query_one("#console_log", RichLog).write(message)


if __name__ == "__main__":
    app = Tui()
    app.run()
