# the-shipyard

## How to run the whole project (backend + client web + scanning):


### Shared setup
Prerequisite: Python 3.10 or newer.

In root (`the-shipyard`) run the following:

Create and activate a virtual environment + install backend dependencies
```bash
# Dependencies
sudo apt update; sudo apt install make build-essential libssl-dev zlib1g-dev \ libbz2-dev libreadline-dev libsqlite3-dev curl git \ libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libzstd-dev
sudo apt install pyenv
pyenv install 3.14.7

# Config, pyenv is optional, only if you need it for your wsl!
pyenv local 3.14.7
python3 -m venv .venv-wsl

# Run virtual env
source .venv-wsl/bin/activate

# make sure pip is installed and up to date
python -m pip install --upgrade pip
```

### Web Backend setup
Now you will install the required libraries for the backend, initialize the database, and start up the backend API.
```bash
# Install venv libraries
python -m pip install -r web-requirements.txt

# Initialize the database with a sample boat:
python -m backend.seed_BOAT

# Start the FastAPI backend (available at: `http://localhost:8000`):
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Leave this terminal running.

#### Useful backend pages:
- Health check: [localhost:8000/health](http://localhost:8000/health)
- Interactive API docs: [localhost:8000/docs](http://localhost:8000/docs)
- Alternative API docs: [localhost:8000/redoc](http://localhost:8000/redoc)

#### "Scan" (create) boats:
run `python3 -m scanning.submit_boat` to submit a boat without the scanning procedure.

The seeded sample boat is available at `http://localhost:5173/boat/BOAT`



### Scanning setup
First, prep a YOLO model and training data according to the YOLO format. With these files, put them in their correct directories (TODO: be more specific). 
```bash
# files here are quite beefy, so install at your own peril!
python -m pip install -r scanning-requirements.txt

# run the Terminal User Interface for scanning. 
python -m scanning.tui
```

### Web client customizer setup:
Prerequisite: Node & Npm. 

run the following (client available at [http://localhost:5173](http://localhost:5173)`):
```bash
npm --prefix web install
npm --prefix web run dev
```


### "See" boats in archipelago:
TODO: has to be updated. 
Open the `simulation/server` godot project and run the `archipelago.tscn` scene

## Run an exhibition event

The event launcher serves the built web client and API from the same local FastAPI process, starts the Godot simulation, and exposes the site through a temporary Cloudflare Quick Tunnel. The operator computer and visitors' phones need internet access. The tunnel URL is temporary and changes after a restart.

Prerequisites: Node.js/npm, Python with `web-requirements.txt` and `scanning-requirements.txt` installed, the Godot editor with Web export templates installed, and `cloudflared` available on the Linux `PATH`. Activate the Python virtual environment containing those packages before launching. Set `SHIPYARD_PYTHON`, `SHIPYARD_NPM`, or `SHIPYARD_CLOUDFLARED` if a command uses a different name or path. A Godot command-line executable is optional; set `SHIPYARD_GODOT` to use it to start the simulation automatically. In WSL, the desktop simulation window requires WSLg or another configured Linux display.

To install `cloudflared`:
```bash
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

From WSL/Linux Bash at the repository root, run:

```bash
bash ./Start-Event.sh
```

Before the event, open `simulation/client` in the Godot editor and export the Web preset to the configured path. Repeat this after changing the client project; the launcher checks that the export is present and newer than its source. The launcher builds the Vite site and prompts for an operator username and password if they are not already in `SHIPYARD_ADMIN_USER` and `SHIPYARD_ADMIN_PASSWORD`. If no Godot command-line executable is available, it pauses so you can open `simulation/server` in the editor and run the project. It then prints the public participant and operator URLs and starts the scanning TUI. After a boat is submitted, the TUI prints its four-letter ID and a QR code linking to that event's public boat page. Open the printed `/admin` page to list, edit, or delete boats. `Start-Event.ps1` remains as a Windows convenience wrapper that translates the repository path and runs `Start-Event.sh` in the default WSL distribution.

The boat database remains in `backend/boats.db`. Stopping the launcher ends the tunnel and event services; a future event can still use the saved records, but it will have a new public URL.

For local development, the Vite server proxies `/api` and `/ws` to FastAPI. Start FastAPI, then run `npm --prefix web run dev`; the default participant URL is `http://localhost:5173`.
