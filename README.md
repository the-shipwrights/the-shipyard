# the-shipyard

## How to run the web part (backend + client web):


### Backend setup

Prerequisite: Python 3.10 or newer.

In root (`the-shipyard`) run the following:

Create and activate a virtual environment + install backend dependencies

```bash
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

(Optional) Initialize the database with the sample boat: 
- Ruslan's Notes: I've found that this part is actually not optional! The backend doesn't work with out an initialized database, atleast not on my machine.  
```bash

python -m backend.seed_ABCD
```


Start the FastAPI backend (available at: `http://localhost:8000`):

```bash
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

Prerequisite: Node & Npm. 

In `the-shipyard/web` run (client available at `http://localhost:5173`):
```bash
npm install vite # required dependency. 
npm --prefix web run dev
```


### "Scan" (create) boats:

run `python3 scanning/submit_boat.py` to submit a boat without scanning 

Generated boat is available at `localhost:5173/boat/ABCD`

### Scan boats from live cam footage 
```bash
python scanning/tui.py
```
Select the predict option and choose a specific set of weights. Choose to predict contents from a live cam footage with snapshotting. A snapshot can be taken by pressing "p" while the camera footage is up. 


### "See" boats in archipelago:

Open the `simulation/server` godot project and run the `archipelago.tscn` scene
