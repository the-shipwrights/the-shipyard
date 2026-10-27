from datetime import datetime, timezone
from pathlib import Path
import json
import secrets
import sqlite3
import string

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator
from scanning.boat import Boat, Piece

DB_PATH = Path(__file__).with_name("boats.db")
ALPHABET = string.ascii_uppercase

class PiecePayload(BaseModel):
    id: int
    x: int
    y: int
    flipped: bool = False
    colors: list[str] = Field(default_factory=list)


class BoatPayload(BaseModel):
    pieces: list[PiecePayload]

    @model_validator(mode="after")
    def validate_canonical_boat(self):
        boat = payload_to_boat(self)
        errors = boat.validate()

        if errors:
            raise ValueError("; ".join(errors))

        return self

def payload_to_boat(payload: BoatPayload) -> Boat:
    return Boat(pieces=[
        Piece(**piece.model_dump())
        for piece in payload.pieces
    ])

class BoatColors(BaseModel):
    primary: str = Field(pattern=r"^#[0-9a-fA-F]{6}$")
    secondary: str = Field(pattern=r"^#[0-9a-fA-F]{6}$")
    accent: str = Field(pattern=r"^#[0-9a-fA-F]{6}$")

DEFAULT_BOAT_COLORS = {
    "primary": "#2f7fff",
    "secondary": "#ffffff",
    "accent": "#ff8800",
}
STATUS_CUSTOMIZING = "customizing"
STATUS_LAUNCHED = "launched"
BOAT_ID_LENGTH = 4


def normalize_boat_id(boat_id: str) -> str:
    return boat_id.strip().upper()


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()

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


def get_connection() -> sqlite3.Connection:
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
                primary_color TEXT NOT NULL DEFAULT '#2f7fff',
                secondary_color TEXT NOT NULL DEFAULT '#ffffff',
                accent_color TEXT NOT NULL DEFAULT '#ff8800',
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


def get_boat_row(boat_id: str) -> sqlite3.Row | None:
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
            "primary": row["primary_color"],
            "secondary": row["secondary_color"],
            "accent": row["accent_color"],
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
                primary_color,
                secondary_color,
                accent_color,
                status,
                created_at,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                boat_id,
                json.dumps(structure),
                DEFAULT_BOAT_COLORS["primary"],
                DEFAULT_BOAT_COLORS["secondary"],
                DEFAULT_BOAT_COLORS["accent"],
                STATUS_CUSTOMIZING,
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
def update_boat(boat_id: str, colors: BoatColors):
    boat_id = boat_id.upper()
    now = timestamp()

    connection = get_connection()
    try:
        row = connection.execute(
            "SELECT status FROM boats WHERE id = ?", (boat_id,)
        ).fetchone()
        
        if row is None:
            raise HTTPException(status_code=404, detail="Boat not found")
        if row["status"] == STATUS_LAUNCHED:
            raise HTTPException(
                status_code=409, 
                detail="Boat has already been launched and cannot be customized"
            )

        connection.execute(
            """
            UPDATE boats
            SET primary_color = ?,
                secondary_color = ?,
                accent_color = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                colors.primary,
                colors.secondary,
                colors.accent,
                now,
                boat_id,
            ),
        )
        connection.commit()
    finally:
        connection.close()

    return serialize_boat(get_boat_row(boat_id))


class SimulationConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        print(f"[WS] Simulation client connected. Total clients: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            print(f"[WS] Simulation client disconnected. Total clients: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)

simulation_manager = SimulationConnectionManager()

# --- 2. WebSocket Endpoint ---
@app.websocket("/ws/simulation")
async def simulation_ws(websocket: WebSocket):
    await simulation_manager.connect(websocket)
    try:
        # Send initial snapshot of launched boats upon connection
        connection = get_connection()
        try:
            rows = connection.execute(
                "SELECT * FROM boats WHERE status = ?",
                (STATUS_LAUNCHED,)
            ).fetchall()
            initial_boats = [serialize_boat(r) for r in rows]
        finally:
            connection.close()

        await websocket.send_json({
            "event": "initial_boats",
            "data": initial_boats
        })

        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        simulation_manager.disconnect(websocket)


# --- 3. Async Launch Endpoint with Broadcast ---
@app.post("/api/boats/{boat_id}/launch")
async def launch_boat(boat_id: str, colors: BoatColors):
    boat_id = boat_id.upper()
    now = timestamp()

    connection = get_connection()
    try:
        row = connection.execute(
            "SELECT status FROM boats WHERE id = ?", (boat_id,)
        ).fetchone()

        if row is None:
            raise HTTPException(status_code=404, detail="Boat not found")
        if row["status"] == STATUS_LAUNCHED:
            raise HTTPException(
                status_code=409, 
                detail="Boat has already been launched"
            )

        connection.execute(
            """
            UPDATE boats
            SET primary_color = ?,
                secondary_color = ?,
                accent_color = ?,
                status = ?,
                launched_at = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (
                colors.primary,
                colors.secondary,
                colors.accent,
                STATUS_LAUNCHED,
                now,
                now,
                boat_id,
            ),
        )
        connection.commit()
    finally:
        connection.close()

    boat_data = serialize_boat(get_boat_row(boat_id))

    # Broadcast single launch event
    await simulation_manager.broadcast({
        "event": "boat_launched",
        "data": boat_data,
    })

    return boat_data

# --- Async boat control endpoint with broadcast ---

@app.websocket("/ws/control/{boat_id}")
async def boat_control_ws(websocket: WebSocket, boat_id: str):
    await websocket.accept()
    normalized_id = normalize_boat_id(boat_id)
    print(f"[WS Control] Controller connected for boat: {normalized_id}")

    try:
        while True:
            payload = await websocket.receive_json()
            command = payload.get("command", "")
            active = bool(payload.get("active", False))

            print(
                f"[WS Control] boat={normalized_id} "
                f"command={command} active={active} "
                f"simulation_clients={len(simulation_manager.active_connections)}"
            )

            # Broadcast control command to the archipelago simulation
            await simulation_manager.broadcast({
                "event": "boat_control",
                "boat_id": normalized_id,
                "command": command,
                "active": active
            })

    except WebSocketDisconnect:
        print(f"[WS Control] Controller disconnected for boat: {normalized_id}")
        # Failsafe: stop active commands if client drops connection
        for command in ("rotate", "accelerate"):
            await simulation_manager.broadcast({
                "event": "boat_control",
                "boat_id": normalized_id,
                "command": command,
                "active": False,
            })