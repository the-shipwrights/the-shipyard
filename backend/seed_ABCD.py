import json

from backend.main import (
    get_connection,
    initialize_database,
    timestamp,
)
from scanning.Boat import Boat, Piece


def main():
    boat = Boat(pieces=[
        Piece(
            id=0,
            type_id=0,
            x=0,
            y=0,
        ),
        Piece(
            id=1,
            type_id=1,
            x=150,
            y=0,
        ),
        Piece(
            id=2,
            type_id=2,
            x=250,
            y=0,
        ),
        Piece(
            id=3,
            type_id=3,
            x=150,
            y=100,
        ),
    ])

    errors = boat.validate()

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
                "ABCD",
                json.dumps(boat.to_dict()),
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

    print("Seeded boat ABCD")


if __name__ == "__main__":
    main()