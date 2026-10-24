"""
Turn prediction results into boat data.
Produce visual feedback in case of faliure.

TODO:
- Perspective correction
- Cleanup
- Image feedback
"""

import boat

symbol_ratio_threshold = 1
scale_threshold = 0.1
position_thresold = 20

grid_cell_size = 11.25
hull_height = 4
symbol_sizes = [
    (16, 27),
    (25, 6),
    (17, 22),
    (18, 27)
]
symbol_positions = [
    (8.5, 28),
    (23.5, 29),
    (32, 30),
    (21.5, 16.5)
]


def parse(prediction: dict) -> boat.Boat | None:

    detections = prediction["detections"]
    image_height = prediction["image_height"]
    if not detections:
        print("No detections found, Returning None")
        return None

    scanned_boat = boat.Boat(pieces=[])

    "{ class: int, width: float, height: float, x_position: float, y_position: float, scale: float }"
    symbols:          list[dict] = []

    "{ class: int, width: float, height: float, x_position: float, y_position: float }"
    hull_pieces:      list[dict] = []
    middle_pieces:    list[dict] = []
    accessory_pieces: list[dict] = []

    average_scale = 0

    # Symbol data collection
    for detection in detections:
        symbol_data = {
            "class": detection["class"],
            "width": detection["box"]["x2"] - detection["box"]["x1"],
            "height": detection["box"]["y2"] - detection["box"]["y1"],
            "x_position": (detection["box"]["x2"] + detection["box"]["x1"]) / 2,
            "y_position": image_height - (detection["box"]["y2"] + detection["box"]["y1"]) / 2,
            "scale": (detection["box"]["x2"] - detection["box"]["x1"]) / symbol_sizes[detection["class"]][0]
        }

        symbols.append(symbol_data)
        average_scale += symbol_data["scale"]

    average_scale /= len(detections)
    position_thresold_scaled = position_thresold * average_scale

    # Plane alignment
    # TODO Move after piece data collection
    for symbol in symbols:
        symbol_size = symbol_sizes[symbol["class"]]
        symbol_ratio = symbol_size[0] / symbol_size[1]
        piece_ratio = symbol["width"] / symbol["height"]
        if abs(symbol_ratio - piece_ratio) > symbol_ratio_threshold:
            # ERROR ratio
            print("Ratio: " + str(piece_ratio) + " deviates too much from " + boat.PIECE_TYPES[symbol["class"]].name + " symbol ratio: " + str(symbol_ratio))
            print("Boat parsing failed")
            return scanned_boat

        if abs(average_scale - symbol["scale"]) > scale_threshold:
            # ERROR scale
            print("Scale: " + str(symbol["scale"]) + " deviates too much from average: " + str(average_scale))
            print("Boat parsing failed")
            return scanned_boat

    # Piece data collection
    # TODO Correct for depth
    for symbol in symbols:
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
        elif category == "middle":
            middle_pieces.append(piece_data)
        elif category == "accessory":
            accessory_pieces.append(piece_data)
        else:
            #ERROR category
            print("Scanned piece is of invalid category: " + str(category))
            print("Boat parsing failed")
            return scanned_boat

    # Hull validation
    if len(hull_pieces) == 0:
        #ERROR no hull
        print("No hull pieces detected")
        print("Boat parsing failed")
        return None

    sorted_hull_pieces = sorted(hull_pieces, key = lambda piece: piece["x_position"])
    origin = (sorted_hull_pieces[0]["x_position"], sorted_hull_pieces[0]["y_position"])
    current_x = 0

    for hull_piece in sorted_hull_pieces:
        current_x_scaled = origin[0] + current_x * grid_cell_size * average_scale
        if abs(current_x_scaled - hull_piece["x_position"]) > position_thresold_scaled:
            # ERROR hull x
            print("X position: " + str(hull_piece["x_position"]) + " of hull piece deviates too much from expectation: " + str(current_x_scaled))
            print("Boat partially parsed")
            return None

        if abs(hull_piece["y_position"] - origin[1]) > position_thresold_scaled:
            # ERROR hull y
            print("Y position: " + hull_piece["y_position"] + " of hull piece deviates too much from origin: " + origin[1])
            print("Boat partially parsed")
            return None

        scanned_boat.pieces.append(boat.Piece(hull_piece["class"], current_x, 0))
        current_x += piece_size(hull_piece["class"])[0]

    # Middle piece validation
    for middle_piece in middle_pieces:
        if abs(middle_piece["x_position"] - origin[0]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR middle x
            print("X position: " + str(middle_piece["x_position"]) + " of middle piece deviates too much from origin: " + str(origin[0]) + " with increments of: " + str(grid_cell_size * average_scale))
            print("Boat partially parsed")
            return scanned_boat

        if abs(middle_piece["y_position"] - origin[1] - hull_height * grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR middle y
            print("Y position: " + str(middle_piece["y_position"]) + " of middle piece deviates too much from expectation: " + str(origin[1] + hull_height * grid_cell_size * average_scale))
            print("Boat partially parsed")
            return scanned_boat

        grid_x_position = round((middle_piece["x_position"] - origin[0]) / (grid_cell_size * average_scale))

        # TODO validate middle collision
        # TODO validate middle connection

        scanned_boat.pieces.append(boat.Piece(middle_piece["class"], grid_x_position, hull_height))

    # Accessory validation
    for accessory_piece in accessory_pieces:
        if abs(accessory_piece["x_position"] - origin[0]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR accessory x
            print("X position: " + str(accessory_piece["x_position"]) + " of accessory piece deviates too much from origin: " + str(origin[0]) + " with increments of: " + str(grid_cell_size * average_scale))
            print("Boat partially parsed")
            return scanned_boat

        if abs(accessory_piece["y_position"] - origin[1]) % (grid_cell_size * average_scale) > position_thresold_scaled:
            # ERROR accessory y
            print("Y position: " + str(accessory_piece["y_position"]) + " of accessory piece deviates too much from origin: " + str(origin[1]) + " with increments of: " + str(grid_cell_size * average_scale))
            print("Boat partially parsed")
            return scanned_boat

        grid_x_position = round((accessory_piece["x_position"] - origin[0]) / (grid_cell_size * average_scale))
        grid_y_position = round((accessory_piece["y_position"] - origin[1]) / (grid_cell_size * average_scale))

        # TODO validate accessory collision
        # TODO validate accessory connection

        scanned_boat.pieces.append(boat.Piece(accessory_piece["class"], grid_x_position, grid_y_position))

    print("Prediction parsed successfully")
    return scanned_boat

def piece_size(piece_index: int) -> tuple[int, int]:
    piece_type = boat.PIECE_TYPES[piece_index]
    return (piece_type.width, piece_type.height)
