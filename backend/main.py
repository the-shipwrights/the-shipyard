from datetime import datetime, timezone
from pathlib import Path
import json
import os
import secrets
import sqlite3
import string
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Response, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel, Field, model_validator
from scanning.boat import Boat, Piece

DB_PATH = Path(
    os.getenv("SHIPYARD_DB_PATH", str(Path(__file__).with_name("boats.db")))
)
WEB_DIST_DIRECTORY = Path(__file__).resolve().parent.parent / "web" / "dist"
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


class AdminBoatUpdate(BaseModel):
    boat: BoatPayload | None = None
    customization: BoatColors | None = None
    status: Literal["customizing", "launched"] | None = None

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
admin_security = HTTPBasic(auto_error=False)

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


def require_admin(
    credentials: HTTPBasicCredentials | None = Depends(admin_security),
) -> str:
    expected_username = os.getenv("SHIPYARD_ADMIN_USER", "")
    expected_password = os.getenv("SHIPYARD_ADMIN_PASSWORD", "")

    if not expected_username or not expected_password:
        raise HTTPException(
            status_code=503,
            detail="Operator access is not configured on this server",
        )

    if credentials is None:
        raise HTTPException(
            status_code=401,
            detail="Operator credentials required",
            headers={"WWW-Authenticate": "Basic"},
        )

    valid_user = secrets.compare_digest(
        credentials.username.encode("utf-8"), expected_username.encode("utf-8")
    )
    valid_password = secrets.compare_digest(
        credentials.password.encode("utf-8"), expected_password.encode("utf-8")
    )
    if not (valid_user and valid_password):
        raise HTTPException(
            status_code=401,
            detail="Invalid operator credentials",
            headers={"WWW-Authenticate": "Basic"},
        )

    return credentials.username


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


@app.get("/api/admin/boats")
def list_boats(_admin: str = Depends(require_admin)):
    connection = get_connection()
    try:
        rows = connection.execute(
            "SELECT * FROM boats ORDER BY created_at DESC, id ASC"
        ).fetchall()
    finally:
        connection.close()

    return [serialize_boat(row) for row in rows]


@app.patch("/api/admin/boats/{boat_id}")
async def admin_update_boat(
    boat_id: str,
    update: AdminBoatUpdate,
    _admin: str = Depends(require_admin),
):
    normalized_id = normalize_boat_id(boat_id)
    now = timestamp()
    assignments: list[str] = []
    values: list[str | None] = []

    if update.boat is not None:
        assignments.append("structure_json = ?")
        values.append(json.dumps(update.boat.model_dump()))
    if update.customization is not None:
        assignments.extend([
            "primary_color = ?",
            "secondary_color = ?",
            "accent_color = ?",
        ])
        values.extend([
            update.customization.primary,
            update.customization.secondary,
            update.customization.accent,
        ])
    connection = get_connection()
    try:
        row = connection.execute(
            "SELECT status FROM boats WHERE id = ?", (normalized_id,)
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Boat not found")

        previous_status = row["status"]
        if update.status is not None:
            assignments.append("status = ?")
            values.append(update.status)
            if update.status == STATUS_LAUNCHED and previous_status != STATUS_LAUNCHED:
                assignments.append("launched_at = ?")
                values.append(now)
            elif update.status == STATUS_CUSTOMIZING:
                assignments.append("launched_at = ?")
                values.append(None)

        if not assignments:
            raise HTTPException(status_code=400, detail="No boat changes supplied")

        assignments.append("updated_at = ?")
        values.append(now)
        values.append(normalized_id)
        connection.execute(
            f"UPDATE boats SET {', '.join(assignments)} WHERE id = ?",
            values,
        )
        connection.commit()
    finally:
        connection.close()

    boat_data = serialize_boat(get_boat_row(normalized_id))
    if boat_data["status"] == STATUS_LAUNCHED:
        await simulation_manager.broadcast({
            "event": "boat_launched",
            "data": boat_data,
        })
    elif previous_status == STATUS_LAUNCHED:
        await simulation_manager.broadcast({
            "event": "boat_removed",
            "boat_id": normalized_id,
        })

    return boat_data


@app.delete("/api/admin/boats/{boat_id}", status_code=204)
async def admin_delete_boat(
    boat_id: str,
    _admin: str = Depends(require_admin),
) -> Response:
    normalized_id = normalize_boat_id(boat_id)
    connection = get_connection()
    try:
        row = connection.execute(
            "SELECT status FROM boats WHERE id = ?", (normalized_id,)
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Boat not found")

        connection.execute("DELETE FROM boats WHERE id = ?", (normalized_id,))
        connection.commit()
        was_launched = row["status"] == STATUS_LAUNCHED
    finally:
        connection.close()

    if was_launched:
        await simulation_manager.broadcast({
            "event": "boat_removed",
            "boat_id": normalized_id,
        })

    return Response(status_code=204)

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


@app.get("/{requested_path:path}", include_in_schema=False)
def serve_web_app(requested_path: str = ""):
    """Serve built Vite files and fall back to the client for browser routes."""
    web_root = WEB_DIST_DIRECTORY.resolve()
    index_path = web_root / "index.html"
    if not index_path.is_file():
        raise HTTPException(
            status_code=503,
            detail="Web client is not built. Run npm --prefix web run build.",
        )

    if requested_path == "api" or requested_path.startswith(("api/", "ws/")):
        raise HTTPException(status_code=404, detail="Not found")

    candidate = (web_root / requested_path).resolve()
    if not candidate.is_relative_to(web_root):
        raise HTTPException(status_code=404, detail="Not found")
    if candidate.is_file():
        return FileResponse(candidate)
    if Path(requested_path).suffix:
        raise HTTPException(status_code=404, detail="Not found")

    return FileResponse(index_path)
