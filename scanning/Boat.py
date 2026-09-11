from dataclasses import dataclass, field
from typing import Literal

# ------------------------------------------------------------------
# Type definitions
# ------------------------------------------------------------------

PieceCategory = Literal["hull", "structure", "accessory"]
Direction = Literal["left", "right", "up", "down"]
ConnectionKind = Literal["hull", "structure", "half_structure", "accessory"]

# ------------------------------------------------------------------
# Piece type definitions
# ------------------------------------------------------------------

@dataclass(frozen=True)
class AttachmentPoint:
    name: str
    kinds: tuple[ConnectionKind, ...]
    x: int
    y: int
    direction: Direction
    
@dataclass(frozen=True)
class PieceType:
    id: int
    name: str
    category: PieceCategory
    width: int
    height: int
    attachments: tuple[AttachmentPoint, ...] = ()

# ------------------------------------------------------------------
# Piece type catalogue
# ------------------------------------------------------------------

HULL_FRONT = PieceType(
    id=0, name="hull_front", category="hull", width=150, height=100,
    attachments=(
        AttachmentPoint(
            name="hull_right_connection", kinds=("hull",),
            x=150, y=50, direction="right",
        ),
        AttachmentPoint(
            name="top_accessory_only", kinds=("accessory",),
            x=50, y=100, direction="up",
        ),
        AttachmentPoint(
            name="top_half_structure_or_accessory",
            kinds=("half_structure", "accessory"),
            x=110, y=100, direction="up",
        ),
    ),
)

HULL_MIDDLE = PieceType(
    id=1, name="hull_middle", category="hull", width=100, height=100,
    attachments=(
        AttachmentPoint(
            name="hull_left_connection", kinds=("hull",),
            x=0, y=50, direction="left",
        ),
        AttachmentPoint(
            name="hull_right_connection", kinds=("hull",),
            x=100, y=50, direction="right",
        ),
        AttachmentPoint(
            name="top_structure_or_accessory",
            kinds=("structure", "accessory"),
            x=50, y=100, direction="up",
        ),
    ),
)

HULL_BACK = PieceType(
    id=2, name="hull_back", category="hull", width=150, height=100,
    attachments=(
        AttachmentPoint(
            name="hull_left_connection", kinds=("hull",),
            x=0, y=50, direction="left",
        ),
        AttachmentPoint(
            name="top_accessory_only", kinds=("accessory",),
            x=60, y=100, direction="up",
        ),
        AttachmentPoint(
            name="top_half_structure_or_accessory",
            kinds=("half_structure", "accessory"),
            x=10, y=100, direction="up",
        ),
    ),
)

CABIN = PieceType(
    id=3, name="cabin", category="structure", width=100, height=100,
    attachments=(
        AttachmentPoint(
            name="bottom", kinds=("structure",),
            x=50, y=0, direction="down",
        ),
        AttachmentPoint(
            name="roof", kinds=("accessory",),
            x=50, y=100, direction="up",
        ),
    ),
)

SHARED_CABIN = PieceType(
    id=4, name="shared_cabin", category="structure", width=150, height=100,
    attachments=(
        AttachmentPoint(
            name="end_hull_bottom", kinds=("half_structure",),
            x=25, y=0, direction="down",
        ),
        AttachmentPoint(
            name="middle_hull_bottom", kinds=("structure",),
            x=125, y=0, direction="down",
        ),
        AttachmentPoint(
            name="roof", kinds=("accessory",),
            x=75, y=100, direction="up",
        ),
    ),
)

TENT = PieceType(
    id=5, name="tent", category="structure", width=100, height=80,
    attachments=(
        AttachmentPoint(
            name="bottom", kinds=("structure",),
            x=50, y=0, direction="down",
        ),
    ),
)

FLAG = PieceType(
    id=6, name="flag", category="structure", width=10, height=80,
    attachments=(
        AttachmentPoint(
            name="bottom", kinds=("structure", "hull"),
            x=5, y=0, direction="down",
        ),
    ),
)

PIECE_TYPES: dict[int, PieceType] = {
    HULL_FRONT.id: HULL_FRONT,
    HULL_MIDDLE.id: HULL_MIDDLE,
    HULL_BACK.id: HULL_BACK,
    CABIN.id: CABIN,
    SHARED_CABIN.id: SHARED_CABIN,
    TENT.id: TENT,
    FLAG.id: FLAG,
}

# ------------------------------------------------------------------
# Placed pieces
# ------------------------------------------------------------------

@dataclass
class Piece:
    id: int
    type_id: int
    x: int
    y: int
    flipped: bool = False
    colors: list[str] = field(default_factory=list)

# ------------------------------------------------------------------
# ASCII representation
# ------------------------------------------------------------------

PIECE_SYMBOLS: dict[str, str] = {
    "hull_front": "◥",
    "hull_back": "◤",
    "hull_middle": "■",
    "cabin": "⌒",
    "shared_cabin": "⌒",
    "tent": "⋏",
    "flag": "⚑",
}

def piece_symbol(piece: Piece) -> str:
    piece_type = PIECE_TYPES.get(piece.type_id)

    if piece_type is None:
        return "?"

    return PIECE_SYMBOLS.get(piece_type.name, "?")

# ------------------------------------------------------------------
# Boat
# ------------------------------------------------------------------

@dataclass
class Boat:
    """
    A boat consists only of placed pieces.

    Connections can be derived from the positions of the pieces and
    the attachment points defined by their PieceTypes.
    """
    pieces: list[Piece] = field(default_factory=list)

    def __str__(self) -> str:
        """String representation of the boat and all placed pieces."""
        lines = [f"Boat: {len(self.pieces)} pieces"]

        for piece in self.pieces:
            piece_type = PIECE_TYPES.get(piece.type_id)

            if piece_type is None:
                lines.append(
                    f"  Piece {piece.id}: "
                    f"unknown type {piece.type_id}, "
                    f"position=({piece.x}, {piece.y}), "
                    f"flipped={piece.flipped}, "
                    f"colors={piece.colors}"
                )
                continue

            lines.append(
                f"  Piece {piece.id}: "
                f"{piece_type.name} "
                f"(type_id={piece.type_id}), "
                f"position=({piece.x}, {piece.y}), "
                f"size=({piece_type.width}x{piece_type.height}), "
                f"flipped={piece.flipped}, "
                f"colors={piece.colors}"
            )

        return "\n".join(lines)

    def ascii(self, cell_width: int = 25) -> str:
        """
        Generate an ASCII representation directly from the runtime pieces.

        x determines horizontal position.
        y determines vertical level.

        No separate matrix/grid is stored in Boat.
        """
        if not self.pieces:
            return "(empty boat)"

        # Find the visual center of every piece.
        positions: list[tuple[Piece, int, int]] = []

        for piece in self.pieces:
            piece_type = PIECE_TYPES.get(piece.type_id)

            if piece_type is None:
                center_x = piece.x
            else:
                center_x = piece.x + piece_type.width // 2

            positions.append((piece, center_x, piece.y))

        # Use all actual Y levels present in the boat.
        y_levels = sorted({y for _, _, y in positions}, reverse=True)

        min_x = min(x for _, x, _ in positions)
        max_x = max(x for _, x, _ in positions)

        # Convert physical X coordinates into printable columns.
        column_count = round((max_x - min_x) / cell_width) + 1

        rows: list[str] = []

        for y in y_levels:
            row = ["."] * column_count

            for piece, center_x, piece_y in positions:
                if piece_y != y:
                    continue

                column = round((center_x - min_x) / cell_width)
                row[column] = piece_symbol(piece)

            rows.append(" ".join(row))

        return "\n".join(rows)
 
myBoat = Boat(pieces=[
    Piece(0, 0,   0,   0),    # left/end hull
    Piece(1, 1, 150,   0),    # middle hull
    Piece(2, 2, 250,   0),    # right/end hull
    Piece(3, 3, 150, 100),    # cabin
    Piece(4, 6, 305, 100),    # flag on end hull
    Piece(5, 6, 195, 200),    # flag on cabin
])

print(myBoat)
print(myBoat.ascii(100))
