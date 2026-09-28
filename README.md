# the-shipyard

## How to run the web part (backend + client web):


### Backend setup

Prerequisite: Python 3.10 or newer.

In root (`the-shipyard`) run the following:

Create and activate a virtual environment + install backend dependencies

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
python -m pip install -r backend\requirements.txt
```

(Optional) Initialize the database with the sample boat: `python -m backend.seed_ABCD`

Start the FastAPI backend (available at: `http://localhost:8000`):

```powershell
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Useful backend pages:

```text
Health check: http://localhost:8000/health
Interactive API docs: http://localhost:8000/docs
Alternative API docs: http://localhost:8000/redoc
```

Leave this terminal running.

### Web client customizer setup:

Prerequisite: Node? Npm?

In `the-shipyard/web` run (client available at `http://localhost:5173`):

`npm run dev`

### "Scan" (create) boats:

In `scanning` run `python3 submit_boat.py`

Generated boat is available at `localhost:5173/boat/ABCD`

### "See" boats in archipelago:

Open the `simulation/server` godot project and run the `archipelago.tscn` scene
