# Shipwright API

Run commands from the repository root in WSL or a Linux Bash shell.

## Local development

Create and activate a virtual environment, then install the API and scanner dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r web-requirements.txt -r scanning-requirements.txt
```

Start FastAPI in one terminal:

```bash
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Start the Vite client in another terminal:

```bash
npm --prefix web run dev
```

The client is at `http://localhost:5173`; FastAPI health and API docs are at `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/docs`.

Seed the sample boat with ID `BOAT`:

```bash
python -m backend.seed_BOAT
```

Run the scanner's sample submission without camera scanning:

```bash
python -m scanning.submit_boat
```

## API summary

- `POST /api/boats` creates a boat and returns its generated four-letter ID.
- `GET /api/boats/{boat_id}` returns a boat and its status.
- `PATCH /api/boats/{boat_id}` updates the three customization colors while the boat is being customized.
- `POST /api/boats/{boat_id}/launch` launches the boat and broadcasts it to the connected Godot simulation.
- `/ws/simulation` carries launch, update, removal, and control events to the simulation.
- `/ws/control/{boat_id}` receives mobile control commands.

Boat IDs are case-insensitive. Color values must use the `#RRGGBB` format.

## Operator console

The console is served at `/admin`. Set `SHIPYARD_ADMIN_USER` and `SHIPYARD_ADMIN_PASSWORD` in the FastAPI process environment to enable access. `Start-Event.sh` prompts for them if they are not already set; the PowerShell wrapper starts that Bash script inside WSL.

The authenticated operator API supports:

- `GET /api/admin/boats` to list boats.
- `PATCH /api/admin/boats/{boat_id}` to update the boat structure, colors, and status (`customizing` or `launched`).
- `DELETE /api/admin/boats/{boat_id}` to remove a boat.

The SQLite database is `backend/boats.db` by default. Set `SHIPYARD_DB_PATH` to use a different path.

## Exhibition mode

From the repository root, activate the virtual environment and run:

```bash
bash ./Start-Event.sh
```

Before the event, export the Web preset from the Godot editor after any changes to `simulation/client`. The launcher checks that the export is present and current, builds the Vite app, starts the local API, and starts a temporary Cloudflare Tunnel. If no Godot command-line executable is available, it pauses for you to run `simulation/server` from the editor. A submitted scan prints a QR code pointing to that event's public boat page.
