from dataclasses import asdict, dataclass, field
from typing import Literal

# ------------------------------------------------------------------
# Type definitions
# ------------------------------------------------------------------

PieceCategory = Literal["hull", "middle", "accessory"]
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

HULL_STERN = PieceType(
    id=2, name="hull_stern", category="hull", width=4, height=4,
    attachments=(
        
    ),
)

HULL_SECTION = PieceType(
    id=1, name="hull_section", category="hull", width=4, height=4,
    attachments=(
        
    ),
)

HULL_BOW = PieceType(
    id=0, name="hull_bow", category="hull", width=6, height=4,
    attachments=(
        
    ),
)

CABIN = PieceType(
    id=3, name="cabin", category="middle", width=4, height=3,
    attachments=(
        
    ),
)

TARP = PieceType(
    id=1000, name="tarp", category="middle", width=100, height=80,
    attachments=(
        
    ),
)

FLAG = PieceType(
    id=1000, name="flag", category="accessory", width=100, height=100,
    attachments=(
        
    ),
)

CHIMNEY = PieceType(
    id=1000, name="chimney", category="accessory", width=100, height=100,
    attachments=(
        
    ),
)

PIECE_TYPES: dict[int, PieceType] = {
    HULL_BOW.id: HULL_BOW,
    HULL_SECTION.id: HULL_SECTION,
    HULL_STERN.id: HULL_STERN,
    CABIN.id: CABIN,
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

# ------------------------------------------------------------------
# Text representation
# ------------------------------------------------------------------

PIECE_TEXT: dict[str, list[str]] = {
    "hull_bow": ["└────────   ", "│         ╱ ", "│          │", "┌──────────┐"],
    "hull_section": ["└──────┘", "│      │", "│      │", "┌──────┐"],
    "hull_stern": [" ──────┘", "╲      │", "│      │", "┌──────┐"],
    "cabin": ["└──────┘", "│  []  │", "┌──────┐"],
}

def piece_text(piece: Piece) -> list[str]:
    piece_type = PIECE_TYPES.get(piece.id)

    if piece_type is None:
        return "?"

    return PIECE_TEXT.get(piece_type.name, "?")

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

    @classmethod
    def from_list(cls, data: list[Piece]) -> "Boat":
        return cls(
            pieces=data,
        )

    def validate(self) -> list[str]:
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

    def __str__(self) -> str:
        """String representation of the boat and all placed pieces."""
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
                f"(type_id={piece.id}), "
                f"position=({piece.x}, {piece.y}), "
                f"size=({piece_type.width}x{piece_type.height}), "
                f"flipped={piece.flipped}, "
                f"colors={piece.colors}"
            )

        return "\n".join(lines)

    def to_text(self) -> str:
        """
        Generate a text representation directly from the runtime pieces.

        x determines horizontal position.
        y determines vertical level.

        No separate matrix/grid is stored in Boat.
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

        '''
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

        

        for y in y_levels:
            row = ["."] * column_count

            for piece, center_x, piece_y in positions:
                if piece_y != y:
                    continue

                column = round((center_x - min_x) / cell_width)
                row[column] = piece_symbol(piece)

            rows.append(" ".join(row))

        return "\n".join(rows)
        '''


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

"""
{
  "id": "ABCD",
  "boat": {
    "pieces": []
  },
  "customization": {
    "color": "#2f7fff"
  },
  "status": "customizing"
}

{
  "pieces": [
    {"id": 0, "type_id": 0, "x": 0, "y": 0, "flipped": false, "colors": []},
    {"id": 1, "type_id": 1, "x": 150, "y": 0, "flipped": false, "colors": []}
  ],
  "edges": [
    {
      "from_piece_id": 0,
      "from_attachment": "hull_right_connection",
      "to_piece_id": 1,
      "to_attachment": "hull_left_connection"
    }
  ]
}
"""