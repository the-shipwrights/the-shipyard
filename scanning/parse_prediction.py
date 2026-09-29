"""
Turn prediction results into boat data.
Produce visual feedback in case of faliure.

Todo:
- I/O data
- Perspective correction?
- Collect data
- Error handling
- Parsing logic
- TUI integration
- Verbose errors
- Image feedback
"""

from boat import Boat
# import numpy as np


symbol_ratio_threshold = 0.1
scale_threshold = 0.1

piece_sizes = [
    (10.5, 8.0),
    (5.9, 4.2)
]
symbol_sizes = [
    (2.3, 4.8),
    (1.1, 2.2)
]
symbol_positions = [
    (3.7, 1.3),
    (6.2, 0.9)
]


def parse(prediction: dict) -> Boat:

    "{ class: int, width: float, height: float, x_position: float, y_position: float, scale: float }"
    symbols:          list[dict] = []
    hull_pieces:      list[dict] = []
    middle_pieces:    list[dict] = []
    accessory_pieces: list[dict] = []

    # Symbol data collection
    for match in prediction:
        symbol_data = {
            "class": match["class"],
            "width": match["x2"] - match["x1"],
            "height": match["y2"] - match["y1"],
            "x_position": (match["x2"] + match["x1"]) / 2,
            "y_position": (match["y2"] + match["y1"]) / 2,
            "scale": (match["x2"] - match["x1"]) / symbol_sizes[match["class"]][0]
        }

        symbols.append(symbol_data)
        average_width_diff += symbol_data["scale"]
    
    average_scale /= len(symbol_data)

    # Plane alignment
    for symbol in symbols:
        symbol_size = symbol_sizes[symbol["class"]]
        symbol_ratio = symbol_size[0] / symbol_size[1]
        piece_ratio = symbol["width"] / symbol["height"]
        if abs(symbol_ratio - piece_ratio) > symbol_ratio_threshold:
            # Error
            print("Ratio " + piece_ratio + " deviates too much from symbol " + symbol["class"] + " ratio of " + symbol_ratio)

        if abs(average_scale - symbol["scale"]) > scale_threshold:
            # Error
            print("Scale " + symbol["scale"] + " deviates too much from average of " + average_scale)

    # Piece data collection
    for symbol in symbols:
        piece_data["x_position"] -= symbol["scale"] * symbol_positions[symbol["class"]][0]
        piece_data = {
                    "class": symbol["class"],
                    "width": piece_sizes[symbol["class"]][0],
                    "height": piece_sizes[symbol["class"]][1],
                    "x_position": symbol["x_position"] - symbol["scale"] * symbol_positions[symbol["class"]][0],
                    "y_position": symbol["y_position"] - symbol["scale"] * symbol_positions[symbol["class"]][1],
                    "scale": symbol["scale"]
                }

        # if symbols["class"] < 3
        hull_pieces.append(piece_data)

    # Hull validation
    sorted_hull_pieces = sorted(hull_pieces, key = lambda piece: piece["x_position"])
    origin = (sorted_hull_pieces[0], sorted_hull_pieces[1])

    for piece in sorted_hull_pieces[1:]:
        print("")

        # Iterate
            # Distance
            # Angle
        # Construct
    # Middle piece validation
        # Iterate
            # Distance
            # x alignment
        # Construct
    # Accessory validation
        # Iterate
            # y alignment
            # x alignment
        # Construct
    # Package and return

    return Boat()