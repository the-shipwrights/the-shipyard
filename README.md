# the-shipyard

## How to run the web part (backend + client web):


### Backend setup

Prerequisite: Python 3.10 or newer.

In root (`the-shipyard`) run the following:

Create and activate a virtual environment + install backend dependencies

```bash
# Dependencies
sudo apt update; sudo apt install make build-essential libssl-dev zlib1g-dev \ libbz2-dev libreadline-dev libsqlite3-dev curl git \ libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libzstd-dev
sudo apt install pyenv
pyenv install 3.14.7

# Config
pyenv local 3.14.7
python3 -m venv .venv-wsl

# Run virtual env
source .venv-wsl/bin/Activate

# Install venv libraries
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

# Initialize the database with a sample boat:
python -m backend.seed_ABCD

# Start the FastAPI backend (available at: `http://localhost:8000`):
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
