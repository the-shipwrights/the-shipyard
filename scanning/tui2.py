from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal
from textual.widgets import (
    DirectoryTree,
    Footer,
    Header,
    Label,
    ListItem,
    ListView,
    Static,
)


class Tui(App):

    theme = "ansi-dark"
    CSS = """
    #directory_panel {
        display: none;
        width: 1fr;
        height: 1fr;
        border: round $accent;
        padding: 1;
    }
    #directory_panel.visible {
        display: block;
    }
    #directory_tree {
        height: 1fr;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()

        with Horizontal():
            yield ListView(
                ListItem(Label("PRACTICE BOAT VISION")),
                ListItem(Label("OBSERVE BOATS")),
                ListItem(Label("FATHOM OBSERVATION")),
                id="main_menu"
            )
            with Container(id="directory_panel"):
                yield Static("runs/detect")
                yield DirectoryTree("scanning/runs/detect/", id="directory_tree")
        yield Footer()

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Dispatch each main-menu item to its corresponding workflow."""
        if event.index == 0:
            self.query_one("#directory_panel").add_class("visible")
        elif event.index == 1:
            self.notify("Boat observation workflow selected.")
        elif event.index == 2:
            self.notify("Prediction parsing workflow selected.")
        else:
            self.notify(
                f"Unhandled menu selection at index {event.index}.",
                severity="warning",
            )


if __name__ == "__main__":
    app = Tui()
    app.run()
