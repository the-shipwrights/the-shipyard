from dataclasses import asdict, dataclass, field
from typing import Literal

# ------------------------------------------------------------------
# Type definitions
# ------------------------------------------------------------------

PieceCategory = Literal[
    "hull",
    "middle",
    "accessory"
]

AttachmentType = Literal[
    "to_hull",
    "to_middle_left",
    "to_middle_right",
    "from_middle",
    "to_accessory",
    "from_accessory"
]

# ------------------------------------------------------------------
# Attachment point
# ------------------------------------------------------------------

@dataclass(frozen=True)
class AttachmentPoint:
    type: AttachmentType
    x: int
    y: int

    def width(self) -> int:
        return ATTACHMENT_POINT_WIDTH.get(self.type)

ATTACHMENT_POINT_WIDTH: dict[AttachmentType, int] = {
    "to_hull": 1,
    "to_middle_left": 2,
    "to_middle_right": 2,
    "from_middle": 4,
    "to_accessory": 2,
    "from_accessory": 2,
}

# ------------------------------------------------------------------
# Piece type
# ------------------------------------------------------------------

@dataclass(frozen=True)
class PieceType:
    id: int
    name: str
    category: PieceCategory
    width: int
    height: int
    attachmentPoints: tuple[AttachmentPoint, ...] = ()

# Piece type catalogue
# ------------------------------------------------------------------

HULL_BOW = PieceType(
    id=0, name="hull_bow", category="hull", width=6, height=4,
    attachmentPoints=(
        AttachmentPoint("to_hull", 3, 0),
        AttachmentPoint("to_middle_right", 0, 3),
        AttachmentPoint("to_accessory", 0, 3),
        AttachmentPoint("to_accessory", 1, 3),
        AttachmentPoint("to_accessory", 2, 3)
    ),
)

HULL_SECTION = PieceType(
    id=1, name="hull_section", category="hull", width=4, height=4,
    attachmentPoints=(
        AttachmentPoint("to_hull", 3, 0),
        AttachmentPoint("to_hull", 3, 2),
        AttachmentPoint("to_middle_left", 0, 3),
        AttachmentPoint("to_middle_right", 2, 3),
        AttachmentPoint("to_accessory", 0, 3),
        AttachmentPoint("to_accessory", 1, 3),
        AttachmentPoint("to_accessory", 2, 3)
    ),
)

HULL_STERN = PieceType(
    id=2, name="hull_stern", category="hull", width=4, height=4,
    attachmentPoints=(
        AttachmentPoint("to_hull", 3, 2),
        AttachmentPoint("to_middle_left", 2, 3),
        AttachmentPoint("to_accessory", 0, 3),
        AttachmentPoint("to_accessory", 1, 3),
        AttachmentPoint("to_accessory", 2, 3)
    ),
)

CABIN = PieceType(
    id=3, name="cabin", category="middle", width=4, height=3,
    attachmentPoints=(
        AttachmentPoint("from_middle", 0, 0),
        AttachmentPoint("to_accessory", 0, 2),
        AttachmentPoint("to_accessory", 1, 2),
        AttachmentPoint("to_accessory", 2, 2)
    ),
)

# TODO define attachmentpoints better @fra ?
BIG_CABIN = PieceType(
    id=4, name="big_cabin", category="middle", width=4, height=6,
    attachmentPoints=(
        AttachmentPoint("from_middle", 0, 0),
        AttachmentPoint("to_accessory", 0, 2),
        AttachmentPoint("to_accessory", 1, 2),
        AttachmentPoint("to_accessory", 2, 2)
    ),
)


# Accessories have IDs starting from 10

CHIMNEY = PieceType(
    id=10, name="chimney", category="accessory", width=2, height=4,
    attachmentPoints=(

    ),
)

SAIL = PieceType(
    id=11, name="sail", category="accessory", width=8, height=8,
    attachmentPoints=(

    ),
)

# Piece type from id
# ------------------------------------------------------------------

PIECE_TYPES: dict[int, PieceType] = {
    HULL_BOW.id: HULL_BOW,
    HULL_SECTION.id: HULL_SECTION,
    HULL_STERN.id: HULL_STERN,
    CABIN.id: CABIN,
    BIG_CABIN.id: BIG_CABIN,
    CHIMNEY.id: CHIMNEY,
    SAIL.id: SAIL,
}

# ------------------------------------------------------------------
# Piece instances
# ------------------------------------------------------------------

@dataclass
class Piece:
    id: int
    x: int
    y: int
    flipped: bool = False
    colors: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    def piece_text(self) -> list[str]:
        piece_type = PIECE_TYPES.get(self.id)

        if piece_type is None:
            return "?"

        return PIECE_TEXT.get(piece_type.name, "?")

# Piece text catalogue
# ------------------------------------------------------------------

PIECE_TEXT: dict[str, list[str]] = {
    "hull_bow": ["└────────   ", "│         ╱ ", "│          │", "┌──────────┐"],
    "hull_section": ["└──────┘", "│      │", "│      │", "┌──────┐"],
    "hull_stern": [" ──────┘", "╲      │", "│      │", "┌──────┐"],
    "cabin": ["└──────┘", "│  []  │", "┌──────┐"],
    "big_cabin":["┌──────┐","│      │","│      │","│      │","│      │","└──────┘"],
    "chimney":["┌───┐", "│   │", "│   │", "│   │"],
}

# ------------------------------------------------------------------
# Symbol types
# ------------------------------------------------------------------

@dataclass
class SymbolType:
    id: int
    x: float
    y: float
    z: float
    width: float
    height: float

# Symbol type catalogue
# ------------------------------------------------------------------

HULL_BOW      = SymbolType(id=0, x=0.9, y=3, z=0, width=1.333, height=0.8)
HULL_SECTION  = SymbolType(id=1, x=2, y=3, z=0, width=1.333, height=0.267)
HULL_STERN    = SymbolType(id=2, x=3.1, y=3, z=0, width=1.333, height=1.333)
CABIN         = SymbolType(id=3, x=2, y=1.5, z=1, width=1.333, height=1.156)
# Accessories have IDs starting from 10
CHIMNEY       = SymbolType(id=10, x=1, y=2.578, z=2, width=0.889, height=0.889)
SAIL          = SymbolType(id=11, x=4.650, y=4.023, z=3, width=1.156, height=0.729)
# Extras have IDs starting from 20
EXTRA_BOW     = SymbolType(id=20, x=0.9, y=1, z=0, width=1.333, height=0.8)
EXTRA_SECTION = SymbolType(id=21, x=2, y=1, z=0, width=1.333, height=0.267)
EXTRA_STERN   = SymbolType(id=22, x=3.1, y=1, z=0, width=1.333, height=1.333)

# Symbol type from id
# ------------------------------------------------------------------

SYMBOL_TYPES: dict[int, SymbolType] = {
    HULL_BOW.id:      HULL_BOW,
    HULL_SECTION.id:  HULL_SECTION,
    HULL_STERN.id:    HULL_STERN,
    CABIN.id:         CABIN,
    CHIMNEY.id:       CHIMNEY,
    SAIL.id:          SAIL,
    EXTRA_BOW.id:     EXTRA_BOW,
    EXTRA_SECTION.id: EXTRA_SECTION,
    EXTRA_STERN.id:   EXTRA_STERN
}

# ------------------------------------------------------------------
# Boat
# ------------------------------------------------------------------

@dataclass
class Boat:
    """
    A boat consists only of piece instances.

    Connections can be derived from the positions of the pieces with
    the attachment points defined by their piece types.
    """
    pieces: list[Piece] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {"pieces": [piece.to_dict() for piece in self.pieces]}

    @classmethod
    def from_list(cls, data: list[Piece]) -> "Boat":
        return cls(
            pieces=data,
        )

    # Boat validation
    # ------------------------------------------------------------------

    # TODO Make not broken?
    def validate(self) -> list[str]:
        return []
        errors = []
        piece_map = {p.id: p for p in self.pieces}

        # 1. Piece duplicate and type checks
        if len(piece_map) < len(self.pieces):
            errors.append("Duplicate piece id detected.")

        for piece in self.pieces:
            if piece.type_id not in PIECE_TYPES:
                errors.append(f"Unknown piece type id: {piece.type_id}")

        # 2. Edge validation
        for edge in self.edges:
            p_from = piece_map.get(edge.from_piece_id)
            p_to = piece_map.get(edge.to_piece_id)

            if not p_from or not p_to:
                errors.append(f"Edge references invalid piece: {edge}")
                continue

            # Verify attachments exist on piece types
            from_type = PIECE_TYPES.get(p_from.type_id)
            to_type = PIECE_TYPES.get(p_to.type_id)

            from_att = next((a for a in from_type.attachments if a.name == edge.from_attachment), None)
            to_att = next((a for a in to_type.attachments if a.name == edge.to_attachment), None)

            if not from_att or not to_att:
                errors.append(f"Attachment name missing on piece type in edge: {edge}")
                continue

            # Check kind compatibility
            shared_kinds = set(from_att.kinds).intersection(to_att.kinds)
            if not shared_kinds:
                errors.append(
                    f"Incompatible attachment kinds between {edge.from_attachment} "
                    f"and {edge.to_attachment}"
                )

        return errors

    def is_valid(self) -> bool:
        return not self.validate()

    # String representation
    # ------------------------------------------------------------------

    def __str__(self) -> str:
        """Generate a string representation of all pieces that make up the boat."""
        lines = [f"Boat: {len(self.pieces)} pieces"]

        for piece in self.pieces:
            piece_type = PIECE_TYPES.get(piece.id)

            if piece_type is None:
                lines.append(
                    f"  Unknown piece type {piece.id}, "
                    f"position=({piece.x}, {piece.y}), "
                    f"flipped={piece.flipped}, "
                    f"colors={piece.colors}"
                )
                continue

            lines.append(
                f"  Piece {piece_type.name} "
                f"(id={piece.id}), "
                f"position=({piece.x}, {piece.y}), "
                f"size=({piece_type.width}x{piece_type.height}), "
                f"flipped={piece.flipped}, "
                f"colors={piece.colors}"
            )

        return "\n".join(lines)

    # Text art
    # ------------------------------------------------------------------

    def to_text(self) -> str:
        """
        Generate a text-based image representation of the boat.

        Note: No separate matrix/grid is stored in Boat.
        """
        if not self.pieces:
            return "(empty boat)"

        output_rows: list[str] = [" " * 48] * 20

        boat_width  = 0
        boat_height = 0

        for piece in self.pieces:
            piece_type = PIECE_TYPES.get(piece.id)
            piece_far_x = piece.x + piece_type.width
            piece_far_y = piece.y + piece_type.height
            boat_width  = max(boat_width,  piece_far_x)
            boat_height = max(boat_height, piece_far_y)

            piece_text = PIECE_TEXT[piece_type.name]
            for piece_row_index, piece_row in enumerate(piece_text):
                output_row = output_rows[piece_row_index + piece.y + 2]
                output_rows[piece_row_index + piece.y + 2] = piece_row.join([output_row[:piece.x * 2 + 2], output_row[piece_far_x * 2 + 1:]])

        output_rows = output_rows[:boat_height + 4]
        output_rows.reverse()
        for row_index in range(len(output_rows)):
            output_rows[row_index] = "║" + output_rows[row_index][:boat_width * 2 + 4] + "║"
        output_rows[0]  = "╔" + "═" * (boat_width * 2 + 4) + "╗"
        output_rows[-1] = "╚" + "═" * (boat_width * 2 + 4) + "╝"

        return "\n".join(output_rows)

# ------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------

if __name__ == "__main__":
    myBoat = Boat(pieces=[
        Piece(2, 0, 0),    # stern
        Piece(1, 4, 0),    # hull section
        Piece(0, 8, 0),    # bow
        Piece(3, 2, 4),    # cabin
        # Piece(6, 305, 100),    # flag on end hull
        # Piece(6, 195, 200),    # flag on cabin
    ])

    print(myBoat)
    print(myBoat.to_text())
