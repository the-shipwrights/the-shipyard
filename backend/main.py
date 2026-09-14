from datetime import datetime, timezone
from pathlib import Path
import json
import secrets
import sqlite3
import string

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator
from scanning.Boat import Boat, Piece

DB_PATH = Path(__file__).with_name("boats.db")
ALPHABET = string.ascii_uppercase

class PiecePayload(BaseModel):
    id: int
    type_id: int
    x: int
    y: int
    flipped: bool = False
    colors: list[str] = Field(default_factory=list)


class BoatPayload(BaseModel):
    pieces: list[PiecePayload]

    @model_validator(mode="after")
    def validate_canonical_boat(self):
        boat = Boat(
            pieces=[
                Piece(**piece.model_dump())
                for piece in self.pieces
            ]
        )

        errors = boat.validate()

        if errors:
            raise ValueError("; ".join(errors))

        return self


class ColorPatch(BaseModel):
    color: str = Field(pattern=r"^#[0-9a-fA-F]{6}$")


app = FastAPI(title="Shipwright API")

# Needed while Vite runs on localhost:5173 and FastAPI runs on localhost:8000.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_connection():
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def timestamp():
    return datetime.now(timezone.utc).isoformat()


def initialize_database():
    connection = get_connection()
    try:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS boats (
                id TEXT PRIMARY KEY,
                structure_json TEXT NOT NULL,
                color TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                launched_at TEXT
            )
            """
        )
        connection.commit()
    finally:
        connection.close()


def generate_boat_id(connection):
    for _ in range(1000):
        boat_id = "".join(
            secrets.choice(ALPHABET)
            for _ in range(4)
        )

        exists = connection.execute(
            "SELECT 1 FROM boats WHERE id = ?",
            (boat_id,),
        ).fetchone()

        if exists is None:
            return boat_id

    raise RuntimeError("Unable to generate a unique boat ID")


def get_boat_row(boat_id):
    connection = get_connection()
    try:
        return connection.execute(
            "SELECT * FROM boats WHERE id = ?",
            (boat_id,),
        ).fetchone()
    finally:
        connection.close()


def serialize_boat(row):
    return {
        "id": row["id"],
        "boat": json.loads(row["structure_json"]),
        "customization": {
            "color": row["color"],
        },
        "status": row["status"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "launched_at": row["launched_at"],
    }


initialize_database()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/boats", status_code=201)
def create_boat(payload: BoatPayload):
    now = timestamp()
    structure = payload.model_dump()

    connection = get_connection()
    try:
        boat_id = generate_boat_id(connection)

        connection.execute(
            """
            INSERT INTO boats (
                id,
                structure_json,
                color,
                status,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                boat_id,
                json.dumps(structure),
                "#2f7fff",
                "customizing",
                now,
                now,
            ),
        )
        connection.commit()
    finally:
        connection.close()

    return serialize_boat(get_boat_row(boat_id))


@app.get("/api/boats/{boat_id}")
def get_boat(boat_id: str):
    row = get_boat_row(boat_id.upper())

    if row is None:
        raise HTTPException(status_code=404, detail="Boat not found")

    return serialize_boat(row)


@app.patch("/api/boats/{boat_id}")
def update_boat(boat_id: str, patch: ColorPatch):
    boat_id = boat_id.upper()
    now = timestamp()

    connection = get_connection()
    try:
        result = connection.execute(
            """
            UPDATE boats
            SET color = ?, updated_at = ?
            WHERE id = ?
            """,
            (patch.color, now, boat_id),
        )
        connection.commit()
    finally:
        connection.close()

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Boat not found")

    return serialize_boat(get_boat_row(boat_id))


@app.post("/api/boats/{boat_id}/launch")
def launch_boat(boat_id: str):
    boat_id = boat_id.upper()
    now = timestamp()

    connection = get_connection()
    try:
        result = connection.execute(
            """
            UPDATE boats
            SET status = ?, launched_at = ?, updated_at = ?
            WHERE id = ?
            """,
            ("launched", now, now, boat_id),
        )
        connection.commit()
    finally:
        connection.close()

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Boat not found")

    # Later this is where you can broadcast to the ocean simulation.
    return serialize_boat(get_boat_row(boat_id))