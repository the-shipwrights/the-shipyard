"""
Turn prediction results into boat data.
Produce visual feedback in case of faliure.

Todo:
- Perspective correction?
- TUI integration
- Verbose ERRORs
- Image feedback
"""

import boat

symbol_ratio_threshold = 0.1
scale_threshold = 0.1
position_thresold = 10

grid_cell_size = 25
hull_height = 100
symbol_sizes = [
    (10, 10),
    (10, 10),
    (10, 10)
]
symbol_positions = [
    (22.5, 22.5),
    (22.5, 22.5),
    (22.5, 22.5)
]


def parse(prediction: dict) -> boat.Boat:

    detections = prediction["detections"]
    scanned_boat = boat.Boat(pieces=[])
    print(detections)

    "{ class: int, width: float, height: float, x_position: float, y_position: float, scale: float }"
    symbols:          list[dict] = []

    "{ class: int, width: float, height: float, x_position: float, y_position: float }"
    hull_pieces:      list[dict] = []
    middle_pieces:    list[dict] = []
    accessory_pieces: list[dict] = []

    # Symbol data collection
    for detection in detections:
        symbol_data = {
            "class": detection["class"],
            "width": detection["x2"] - detection["x1"],
            "height": detection["y2"] - detection["y1"],
            "x_position": (detection["x2"] + detection["x1"]) / 2,
            "y_position": (detection["y2"] + detection["y1"]) / 2,
            "scale": (detection["x2"] - detection["x1"]) / symbol_sizes[detection["class"]][0]
        }

        symbols.append(symbol_data)
        average_scale += symbol_data["scale"]

    average_scale /= len(symbol_data)
    position_thresold_scaled = position_thresold * average_scale

    # Plane alignment
    for symbol in symbols:
        symbol_size = symbol_sizes[symbol["class"]]
        symbol_ratio = symbol_size[0] / symbol_size[1]
        piece_ratio = symbol["width"] / symbol["height"]
        if abs(symbol_ratio - piece_ratio) > symbol_ratio_threshold:
            # ERROR ratio
            print("Ratio: " + piece_ratio + " deviates too much from symbol " + symbol["class"] + " ratio: " + symbol_ratio)
            return scanned_boat

        if abs(average_scale - symbol["scale"]) > scale_threshold:
            # ERROR scale
            print("Scale: " + symbol["scale"] + " deviates too much from average: " + average_scale)
            return scanned_boat

    # Piece data collection
    for symbol in symbols:
        piece_data["x_position"] -= average_scale * symbol_positions[symbol["class"]][0]
        piece_data = {
                    "class": symbol["class"],
                    "width": piece_size(symbol["class"])[0],
                    "height": piece_size(symbol["class"])[1],
                    "x_position": symbol["x_position"] - average_scale * symbol_positions[symbol["class"]][0],
                    "y_position": symbol["y_position"] - average_scale * symbol_positions[symbol["class"]][1]
                }

        category = boat.PIECE_TYPES[symbol["class"]].category
        if category == "hull":
            hull_pieces.append(piece_data)
        elif category == "structure":
            middle_pieces.append(piece_data)
        elif category == "accessory":
            accessory_pieces.append(piece_data)
        else:
            #ERROR category
            print("Invalid category: " + category)

    # Hull validation
    sorted_hull_pieces = sorted(hull_pieces, key = lambda piece: piece["x_position"])
    origin = (sorted_hull_pieces[0]["x_position"], sorted_hull_pieces[0]["y_position"])
    current_x = 0

    for hull_piece in sorted_hull_pieces:
        current_x_scaled = current_x * average_scale + origin[0]
        if abs(current_x_scaled - hull_piece["x_position"]) > position_thresold_scaled:
            # ERROR hull x
            print("X position: " + hull_piece["x_position"] + " of hull piece deviates too much from expectation: " + current_x_scaled)
            return scanned_boat

        if abs(hull_piece["y_position"] - origin[1]) > position_thresold_scaled:
            # ERROR hull y
            print("Y position: " + hull_piece["y_position"] + " of hull piece deviates too much from origin: " + origin[1])
            return scanned_boat

        boat.pieces.append(boat.Piece(len(boat.pieces), hull_piece["class"], current_x, 0))
        current_x += piece_size(hull_piece["class"])[0]

    # Middle piece validation
    for middle_piece in middle_pieces:
        if abs(middle_piece["x_position"] - origin[0]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR middle x
            print("X position: " + middle_piece["x_position"] + " of middle piece deviates too much from origin: " + origin[0] + " with increments of: " + grid_cell_size * average_scale)
            return scanned_boat

        if abs(middle_piece["y_position"] - origin[1] - hull_height * average_scale) > position_thresold_scaled:
            # ERROR middle y
            print("Y position: " + middle_piece["y_position"] + " of middle piece deviates too much from expectation: " + origin[1] + hull_height * average_scale)
            return scanned_boat

        grid_x_position = (middle_piece["x_position"] - origin[0]) / average_scale
        nearest_x_position = round(grid_x_position / grid_cell_size) * grid_cell_size

        # TODO validate middle collision
        # TODO validate middle connection

        boat.pieces.append(boat.Piece(len(boat.pieces), middle_piece["class"], nearest_x_position, hull_height))

    # Accessory validation
    for accessory_piece in accessory_pieces:
        if abs(accessory_piece["x_position"] - origin[0]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR accessory x
            print("X position: " + accessory_piece["x_position"] + " of accessory piece deviates too much from origin: " + origin[0] + " with increments of: " + grid_cell_size * average_scale)
            return scanned_boat

        if abs(accessory_piece["y_position"] - origin[1]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR accessory y
            print("Y position: " + accessory_piece["y_position"] + " of accessory piece deviates too much from origin: " + origin[1] + " with increments of: " + grid_cell_size * average_scale)
            return scanned_boat

        grid_x_position = (accessory_piece["x_position"] - origin[0]) / average_scale
        grid_y_position = (accessory_piece["y_position"] - origin[1]) / average_scale
        nearest_x_position = round(grid_x_position / grid_cell_size) * grid_cell_size
        nearest_y_position = round(grid_y_position / grid_cell_size) * grid_cell_size

        # TODO validate accessory collision
        # TODO validate accessory connection

        boat.pieces.append(boat.Piece(len(boat.pieces), accessory_piece["class"], nearest_x_position, nearest_y_position))

    return scanned_boat

def piece_size(piece_index: int) -> tuple[int, int]:
    piece_type = boat.PIECE_TYPES[piece_index]
    return (piece_type.width, piece_type.height)
