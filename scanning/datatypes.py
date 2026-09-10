from typing import Literal, TypedDict

Level = Literal["top", "middle", "bottom"]

BottomType = Literal["back", "hull", "front"]
MiddleType = Literal["cabin", "tent"]
AccessoryType = Literal["flag", "sail", "chimney"]


class BottomBlock(TypedDict):
    block_type: Literal["bottom"]
    type: BottomType
    level: Literal["bottom"]


class MiddleBlock(TypedDict):
    block_type: Literal["middle"]
    type: MiddleType
    level: Literal["middle"]


class AccessoryBlock(TypedDict):
    block_type: Literal["accessory"]
    type: AccessoryType
    level: Literal["top", "middle"]


Block = BottomBlock | MiddleBlock | AccessoryBlock


def block_symbol(block: Block | None) -> str:
    if block is None:
        return "."

    symbols = {
        "back": "◥",
        "front": "◤",
        "hull": "■",
        "cabin": "⌒",
        "tent": "⋏",
        "flag": "⚑",
        "sail": "◮",
        "chimney": "ᴛ",
    }

    return symbols[block["type"]]


class Boat:
    def __init__(self, length: int):
        if not 1 <= length <= 5:
            raise ValueError("Boat length must be between 1 and 5")

        self.length = length
        self.matrix: list[list[Block | None]] = [
            [None] * 5 for _ in range(3)
        ]

    def __str__(self) -> str:
        return "\n".join(
            " ".join(block_symbol(cell) for cell in row)
            for row in self.matrix
        )

    # Validation method is generated
    # Should fulfill previously discussed constraints
    def validate(self) -> list[str]:
        errors = []

        # ---------------------------------------------------------
        # 1. Validate that cells beyond the boat's length are empty
        #    for structural blocks.
        # ---------------------------------------------------------
        for row in range(3):
            for col in range(self.length, 5):
                block = self.matrix[row][col]

                if block is None:
                    continue

                if block["block_type"] != "accessory":
                    errors.append(
                        f"Structural block at ({row}, {col}) "
                        f"is outside boat length {self.length}"
                    )

        # ---------------------------------------------------------
        # 2. Validate the bottom row.
        # ---------------------------------------------------------
        bottom = self.matrix[2][:self.length]

        bottom_blocks = [
            block for block in bottom
            if block is not None
        ]

        # Every occupied bottom cell must be a bottom block.
        for col, block in enumerate(bottom):
            if block is not None and block["block_type"] != "bottom":
                errors.append(
                    f"Non-bottom block at bottom position {col}"
                )

        # A boat must have a complete bottom structure.
        if any(block is None for block in bottom):
            errors.append(
                "Bottom row must be completely filled."
            )

        # ---------------------------------------------------------
        # 3. Bottom blocks must have the correct ordering.
        # ---------------------------------------------------------
        bottom_types = [
            block["type"]
            for block in bottom
            if block is not None
        ]

        if self.length == 2:
            # Special smallest boat: back + front.
            if bottom_types != ["back", "front"]:
                errors.append(
                    "A length-2 boat must have bottom "
                    "[back, front]."
                )

        else:
            # Normal boat must begin with back and end with front.
            if bottom_types:
                if bottom_types[0] != "back":
                    errors.append(
                        "Bottom row must start with 'back'."
                    )

                if bottom_types[-1] != "front":
                    errors.append(
                        "Bottom row must end with 'front'."
                    )

                # Everything between back and front must be hull.
                for block_type in bottom_types[1:-1]:
                    if block_type != "hull":
                        errors.append(
                            "Only 'hull' blocks may occur between "
                            "'back' and 'front'."
                        )

        # ---------------------------------------------------------
        # 4. Validate middle row.
        # ---------------------------------------------------------
        for col in range(5):
            block = self.matrix[1][col]

            if block is None:
                continue

            if block["level"] != "middle":
                errors.append(
                    f"Block at middle position ({1}, {col}) "
                    f"has incorrect level '{block['level']}'."
                )

            if block["block_type"] not in ("middle", "accessory"):
                errors.append(
                    f"Invalid block type '{block['block_type']}' "
                    f"in middle row at column {col}."
                )

        # ---------------------------------------------------------
        # 5. Validate top row.
        # ---------------------------------------------------------
        for col in range(5):
            block = self.matrix[0][col]

            if block is None:
                continue

            if block["level"] != "top":
                errors.append(
                    f"Block at top position ({0}, {col}) "
                    f"has incorrect level '{block['level']}'."
                )

            if block["block_type"] != "accessory":
                errors.append(
                    f"Only accessories may occupy the top row "
                    f"(column {col})."
                )

        # ---------------------------------------------------------
        # 6. Validate bottom block levels.
        # ---------------------------------------------------------
        for col in range(self.length):
            block = self.matrix[2][col]

            if block is not None and block["level"] != "bottom":
                errors.append(
                    f"Bottom block at column {col} "
                    f"has level '{block['level']}'."
                )

        # ---------------------------------------------------------
        # 7. Validate cabin/tent placement.
        # ---------------------------------------------------------
        for col in range(self.length):
            block = self.matrix[1][col]

            if block is None or block["block_type"] != "middle":
                continue

            # A middle block needs a bottom surface beneath it.
            below = self.matrix[2][col]

            if below is None:
                errors.append(
                    f"Middle block at column {col} has no "
                    f"bottom block beneath it."
                )

        return errors

    def is_valid(self) -> bool:
        return len(self.validate()) == 0

# Boat
# > length: 1..5
# > > matrix: 3 × 5
#   > None
#   > > Block
#     > block_type
#     > type
#     > level

# Main testing

# top       [ .  .  .  .  . ]
# middle    [ .  .  .  .  . ]
# bottom    [ B  F  .  .  . ]
#            └──┘
#            length = 2

boat = Boat(2)

boat.matrix[2][0] = {
    "block_type": "bottom",
    "type": "back",
    "level": "bottom",
}

boat.matrix[2][1] = {
    "block_type": "bottom",
    "type": "front",
    "level": "bottom",
}

boat.matrix[1][0] = {
    "block_type": "accessory",
    "type": "sail",
    "level": "middle",
}

boat.matrix[1][1] = {
    "block_type": "middle",
    "type": "cabin",
    "level": "middle",
}


boat.matrix[1][2] = {
    "block_type": "accessory",
    "type": "flag",
    "level": "middle",
}

boat.matrix[0][1] = {
    "block_type": "accessory",
    "type": "flag",
    "level": "top",
}

print(boat)
