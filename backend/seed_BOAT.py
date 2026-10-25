import json

from backend.main import (
    get_connection,
    initialize_database,
    timestamp,
)
from scanning.boat import Boat, Piece


def main():
    myBoat = Boat(pieces=[
        Piece(2, 0, 0),    # stern
        Piece(1, 4, 0),    # hull section
        Piece(0, 8, 0),    # bow
        Piece(3, 2, 4),    # cabin
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
                color,
                status,
                created_at,
                updated_at,
                launched_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                structure_json = excluded.structure_json,
                color = excluded.color,
                status = excluded.status,
                updated_at = excluded.updated_at,
                launched_at = excluded.launched_at
            """,
            (
                "BOAT",
                json.dumps(myBoat.to_dict()),
                "#2f7fff",
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