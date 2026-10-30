# Boat scanning

Run these commands from the repository root in WSL/Linux Bash.

Create and activate a virtual environment, then install the scanning dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r scanning-requirements.txt
```

Start the backend in one terminal:

```bash
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Start Vite in a second terminal:

```bash
npm --prefix web run dev
```

In another activated shell, run the TUI:

```bash
python -m scanning.tui
```
The defaults submit to `http://127.0.0.1:8000` and print links to `http://localhost:5173`. Set `SHIPYARD_API_URL` or `SHIPYARD_PUBLIC_URL` to use different addresses. The event launcher sets both automatically and displays a QR code after a boat is submitted.

This should download all dependencies :) and perhaps a few more than whats needed... 
This dependency is vital for us.

## Computer Vision 

### Symbols 

denotes which side of the piece is laying down. 

- Hull Bow 
  - 0 UP FORWARD
  - 1 UP BACKWARD
  - 2 DOWN FORWARD
  - 3 DOWN BACKWARD

- Hull Stern 
  - 4 UP FORWARD
  - 5 UP BACKWARD
  - 6 DOWN FORWARD
  - 7 DOWN BACKWARD

- Hull Section 
  - 8 UP 
  - 9 DOWN

- Cabin
  - 10 default 
- Chimney
  - 11 default 
- Sail 
  - 12 FORWARD
  - 13 BACKWARD
- 


## Parsing & Boat
