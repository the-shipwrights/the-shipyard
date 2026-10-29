import json

from backend.main import (
    get_connection,
    initialize_database,
    timestamp,
)
from scanning.boat import Boat, Piece


def main():
    myBoat = Boat(pieces=[
        Piece(2, 0, 0),     # stern
        Piece(1, 4, 0),     # hull section
        Piece(1, 8, 0),     # hull section
        Piece(1, 12, 0),    # hull section
        Piece(0, 16, 0),    # bow
        Piece(4, 4, 4),     # cabig
        Piece(3, 8, 4),     # cabin
        Piece(10, 9, 7),    # chimney
        Piece(11, 12, 4),   # Sail
    ])

    errors = myBoat.validate()

    if errors:
        raise RuntimeError(
            "Invalid test boat: " + "; ".join(errors)
        )

    initialize_database()

    now = timestamp()
    connection = get_connection()

    try:
        connection.execute(
            """
            INSERT INTO boats (
                id,
                structure_json,
                primary_color,
                secondary_color,
                accent_color,
                status,
                created_at,
                updated_at,
                launched_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                structure_json = excluded.structure_json,
                primary_color = excluded.primary_color,
                secondary_color = excluded.secondary_color,
                accent_color = excluded.accent_color,
                status = excluded.status,
                updated_at = excluded.updated_at,
                launched_at = excluded.launched_at
            """,
            (
                "BOAT",
                json.dumps({
                    "pieces": [piece.to_dict() for piece in myBoat.pieces]
                }),
                "#2f7fff",  # primary
                "#ffffff",  # secondary
                "#ff8800",  # accent
                "customizing",
                now,
                now,
                None,
            ),
        )

        connection.commit()
    finally:
        connection.close()

    print("Seeded boat BOAT")


if __name__ == "__main__":
    main()