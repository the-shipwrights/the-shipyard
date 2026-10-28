"""
Turn prediction results into boat data.
Produce visual feedback in case of faliure.

TODO:
- Perspective correction
- Cleanup
- Image feedback
"""

from . import boat

sqrt2 = 1.4142

confidence_threshold = 0.6
symbol_ratio_threshold = 1
scale_threshold = 10
position_thresold = 20
hull_height = 4


def parse(prediction: dict) -> boat.Boat | None:

    detections = prediction["detections"]
    image_width = prediction["image_width"]
    image_height = prediction["image_height"]

    scanned_boat = boat.Boat(pieces=[])

    "{ id: int, width: float, height: float, x_position: float, y_position: float, scale: float }"
    symbols:          list[dict] = []

    "{ id: int, flipped: bool, width: float, height: float, x_position: float, y_position: float }"
    hull_pieces:      list[dict] = []
    middle_pieces:    list[dict] = []
    accessory_pieces: list[dict] = []

    average_scale = 0

    print("Don't forget to fix these at some point")
    for detection in detections:
        if detection["confidence"] > confidence_threshold:
            print(str(detection["class"]) + " -> " + str(class_to_id(detection["class"])[0]))

    # Symbol data collection
    for detection in detections:
        if detection["confidence"] > confidence_threshold:
            (id, flipped) = class_to_id(detection["class"])
            try:
                symbol_type = boat.SYMBOL_TYPES[id]
                piece_type  = boat.PIECE_TYPES[id]
            except:
                # ERROR ID
                print(str(id) + " does not correspond to both a piece type and a symbol type")
                print("Skipping symbol")
                continue
            symbol_data = {
                "id": id,
                "flipped": flipped,
                "width": detection["box"]["x2"] - detection["box"]["x1"],
                "height": detection["box"]["y2"] - detection["box"]["y1"],
                "x_position": (detection["box"]["x2"] + detection["box"]["x1"]) / 2,
                "y_position": image_height - (detection["box"]["y2"] + detection["box"]["y1"]) / 2,
                "scale": (detection["box"]["x2"] - detection["box"]["x1"]) / symbol_type.width
            }

            if symbol_type.z != 0:
                distance_to_camera = (symbol_type.width * (17/30)) / (symbol_data["width"] / image_width)
                mult = distance_to_camera / (distance_to_camera - symbol_type.z)
                symbol_data["width"] *= mult
                symbol_data["height"] *= mult
                symbol_data["x_position"] = ((symbol_data["x_position"] - (image_width / 2)) * mult) + (image_width / 2)
                symbol_data["y_position"] = ((symbol_data["y_position"] - (image_height / 2)) * mult) + (image_height / 2)

        symbols.append(symbol_data)
        average_scale += symbol_data["scale"]

    if not symbols:
        print("No detections found with confidence above " + str(confidence_threshold))
        print("Boat parsing failed")
        return None

    average_scale /= len(detections)
    position_thresold_scaled = position_thresold * average_scale

    # Plane alignment
    # TODO Move after piece data collection
    for symbol in symbols:
        symbol_type = boat.SYMBOL_TYPES[symbol["id"]]
        symbol_ratio = symbol_type.width / symbol_type.height
        piece_ratio = symbol["width"] / symbol["height"]
        if abs(symbol_ratio - piece_ratio) > symbol_ratio_threshold:
            # ERROR ratio
            print("Ratio: " +
                str(piece_ratio) +
                " of " +
                boat.PIECE_TYPES[symbol["id"]].name +
                " deviates too much from " +
                boat.PIECE_TYPES[symbol["id"]].name +
                " symbol ratio: " +
                str(symbol_ratio)
            )
            print("Boat parsing failed")
            return None

        if abs(average_scale - symbol["scale"]) > scale_threshold:
            # ERROR scale
            print("Scale: " +
                str(symbol["scale"]) +
                " of " +
                boat.PIECE_TYPES[symbol["id"]].name +
                " deviates too much from average: "
                + str(average_scale)
            )
            print("Boat parsing failed")
            return None

    # Piece data collection
    # TODO Correct for depth
    for symbol in symbols:
        piece_type  = boat.PIECE_TYPES[symbol["id"]]
        symbol_type = boat.SYMBOL_TYPES[symbol["id"]]
        flipped_x = piece_type.width - symbol_type.x if symbol["flipped"] else symbol_type.x
        piece_data = {
            "id": symbol["id"],
            "flipped": symbol["flipped"],
            "width": piece_type.width,
            "height": piece_type.height,
            "x_position": symbol["x_position"] - average_scale * flipped_x,
            "y_position": symbol["y_position"] - average_scale * symbol_type.y
        }

        category = piece_type.category
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
            return None

    # Hull validation
    if len(hull_pieces) == 0:
        #ERROR no hull
        print("No hull pieces detected")
        print("Boat parsing failed")
        return None

    sorted_hull_pieces = sorted(hull_pieces, key = lambda piece: piece["x_position"])
    x_origin = sorted_hull_pieces[0]["x_position"]
    y_origin = sorted_hull_pieces[0]["y_position"]
    current_x = 0

    for hull_piece in sorted_hull_pieces:
        current_x_scaled = x_origin + current_x * average_scale
        if abs(current_x_scaled - hull_piece["x_position"]) > position_thresold_scaled:
            # ERROR hull x
            print("X position: " + str(hull_piece["x_position"]) + " of hull piece deviates too much from expectation: " + str(current_x_scaled))
            print("Boat partially parsed")
            return scanned_boat

        if abs(hull_piece["y_position"] - y_origin) > position_thresold_scaled:
            # ERROR hull y
            print("Y position: " + hull_piece["y_position"] + " of hull piece deviates too much from origin: " + y_origin)
            print("Boat partially parsed")
            return scanned_boat

        scanned_boat.pieces.append(boat.Piece(hull_piece["id"], current_x, 0, hull_piece["flipped"]))
        current_x += boat.PIECE_TYPES[hull_piece["id"]].width

    # Middle piece validation
    for middle_piece in middle_pieces:
        if abs(middle_piece["x_position"] - x_origin) % average_scale > position_thresold_scaled:
            # ERROR middle x
            print("X position: " + str(middle_piece["x_position"]) + " of middle piece deviates too much from origin: " + str(x_origin) + " with increments of: " + str(average_scale))
            print("Boat partially parsed")
            return scanned_boat

        if abs(middle_piece["y_position"] - y_origin - hull_height * average_scale) > position_thresold_scaled:
            # ERROR middle y
            print("Y position: " + str(middle_piece["y_position"]) + " of middle piece deviates too much from expectation: " + str(y_origin + hull_height * average_scale))
            print("Boat partially parsed")
            return scanned_boat

        grid_x_position = round((middle_piece["x_position"] - x_origin) / average_scale)

        # TODO validate middle collision
        # TODO validate middle connection

        scanned_boat.pieces.append(boat.Piece(middle_piece["id"], grid_x_position, hull_height, hull_piece["flipped"]))

    # Accessory validation
    for accessory_piece in accessory_pieces:
        if abs(accessory_piece["x_position"] - x_origin) % average_scale > position_thresold_scaled:
            # ERROR accessory x
            print("X position: " + str(accessory_piece["x_position"]) + " of accessory piece deviates too much from origin: " + str(x_origin) + " with increments of: " + str(average_scale))
            print("Boat partially parsed")
            return scanned_boat

        if abs(accessory_piece["y_position"] - y_origin) % average_scale > position_thresold_scaled:
            # ERROR accessory y
            print("Y position: " + str(accessory_piece["y_position"]) + " of accessory piece deviates too much from origin: " + str(y_origin) + " with increments of: " + str(average_scale))
            print("Boat partially parsed")
            return scanned_boat

        grid_x_position = round((accessory_piece["x_position"] - x_origin) / average_scale)
        grid_y_position = round((accessory_piece["y_position"] - y_origin) / average_scale)

        # TODO validate accessory collision
        # TODO validate accessory connection

        scanned_boat.pieces.append(boat.Piece(accessory_piece["id"], grid_x_position, grid_y_position, hull_piece["flipped"]))

    print("Prediction parsed successfully")
    return scanned_boat

# NEW! CLASS TO PIECE ID MAPPER!!!
def class_to_id(prediction_class : int) -> tuple[int, bool]:
    """maps class id to piece id in boat.py."""
    match prediction_class:
        case 0:     # Bow
            return (0, False)
        case 1:     # Bow FLIPPED
            return (0, True)
        case 2:     # Bow DOWN
            return (20, False)
        case 3:     # Bow DOWN FLIPPED
            return (20, True)
        case 9:     # Hull Section
            return (1, False)
        case 8:     # Hull Section DOWN
            return (21, False)
        case 5:     # Stern
            return (2, False)
        case 4:     # Stern FLIPPED
            return (2, True)
        case 7:     # Stern DOWN
            return (22, False)
        case 6:     # Stern DOWN FLIPPED
            return (22, True)
        case 10:    # Cabin
            return (3, False)
        case 11:    # Chimney
            return (10, False)
        case 12:   # Sail
            return (11, False)
        case 13:   # Sail
            return (11, True)
        case _:
            raise ValueError(f"dude wtf are you doing? you CANNOT map {prediction_class} to a boat piece. don't. even. try.")
