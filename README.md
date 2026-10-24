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
source .venv-wsl/bin/Activate

# make sure pip is installed and up to date
python -m pip install --upgrade pip
```

### Web Backend setup
Now you will install the required libraries for the backend, initialize the database, and start up the backend API.
```bash
# Install venv libraries
python -m pip install -r web-requirements.txt

# Initialize the database with a sample boat:
python -m backend.seed_ABCD

# Start the FastAPI backend (available at: `http://localhost:8000`):
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Leave this terminal running.

#### Useful backend pages:
- Health check: [localhost:8000/health](http://localhost:8000/health)
- Interactive API docs: [localhost:8000/docs](http://localhost:8000/docs)
- Alternative API docs: [localhost:8000/redoc](http://localhost:8000/redoc)

#### "Scan" (create) boats:
run `python3 scanning/submit_boat.py` to submit a boat without the scanning procedure.

Generated boat is available at `localhost:5173/boat/ABCD`



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
npm install vite # required dependency. 
npm --prefix web run dev
```


### "See" boats in archipelago:
TODO: has to be updated. 
Open the `simulation/server` godot project and run the `archipelago.tscn` scene
