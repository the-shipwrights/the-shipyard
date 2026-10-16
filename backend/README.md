
source .venv-wsl/bin/Activate

uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

## Backend setup and run

Prerequisite: Python 3.10 or newer.

Open PowerShell in the repository root:

```powershell
cd the-shipyard
```

Create and activate a virtual environment:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the backend dependencies:

```powershell
python -m pip install --upgrade pip
python -m pip install -r backend\requirements.txt
```

Initialize the database with the sample boat:

```powershell
python -m backend.seed_ABCD
```

Start the FastAPI backend:

```powershell
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

The backend will be available at:

```text
http://localhost:8000
```

Useful backend pages:

```text
Health check: http://localhost:8000/health
Interactive API docs: http://localhost:8000/docs
Alternative API docs: http://localhost:8000/redoc
```

Leave this terminal running.

If PowerShell prevents activation scripts from running, activate the environment using Command Prompt instead:

```cmd
.venv\Scripts\activate.bat
```


## 3. Seed database instructions

The seed script creates or updates the sample boat with ID `ABCD`.

Run it from the repository root, not from inside the `backend` directory:

```powershell
cd C:\Users\minzh\Dokument\gitrepos\the-shipyard
.\.venv\Scripts\Activate.ps1
python -m backend.seed_ABCD
```

Expected output:

```text
Seeded boat ABCD
```

The SQLite database is stored at:

```text
backend\boats.db
```

The seed operation is repeatable. Running it again updates the existing `ABCD` boat.

Important: re-running the seed resets the sample boat to its default state:

```text
Status: customizing
Color: #2f7fff
Launched: no
```

## 4. API endpoint summary

Base URL:

```text
http://localhost:8000
```

### Health check

```http
GET /health
```

PowerShell:

```powershell
curl.exe http://localhost:8000/health
```

Expected response:

```json
{
  "status": "ok"
}
```

### Create a boat

```http
POST /api/boats
Content-Type: application/json
```

PowerShell:

```powershell
curl.exe -X POST "http://localhost:8000/api/boats" `
  -H "Content-Type: application/json" `
  -d '{"pieces":[{"id":2,"x":0,"y":0,"flipped":false,"colors":[]},{"id":1,"x":4,"y":0,"flipped":false,"colors":[]},{"id":0"x":8,"y":0,"flipped":false,"colors":[]},{"id":3,"x":2,"y":4,"flipped":false,"colors":[]}]}' 
```

Successful response status:

```text
201 Created
```

Request body structure:

```json
{
  "pieces": [
    {
      "id": 0,
      "x": 0,
      "y": 0,
      "flipped": false,
      "colors": []
    }
  ]
}
```

The response contains a generated four-letter boat ID:

```json
{
  "id": "WXYZ",
  "boat": {
    "pieces": []
  },
  "customization": {
    "color": "#2f7fff"
  },
  "status": "customizing",
  "created_at": "...",
  "updated_at": "...",
  "launched_at": null
}
```

### Get a boat

```http
GET /api/boats/{boat_id}
```

PowerShell:

```powershell
curl.exe http://localhost:8000/api/boats/ABCD
```

Boat IDs are case-insensitive, so this also works:

```powershell
curl.exe http://localhost:8000/api/boats/abcd
```

Successful response status:

```text
200 OK
```

If the boat does not exist:

```text
404 Not Found
```

### Update boat color

```http
PATCH /api/boats/{boat_id}
Content-Type: application/json
```

PowerShell:

```powershell
curl.exe -X PATCH "http://localhost:8000/api/boats/ABCD" `
  -H "Content-Type: application/json" `
  -d '{"color":"#ff8800"}'
```

The color must be a six-digit hexadecimal CSS color, including the `#`:

```text
#ff8800
#2f7fff
#AABBCC
```

Successful response status:

```text
200 OK
```

Invalid color example:

```json
{
  "color": "blue"
}
```

This returns a validation error because the API currently expects the `#RRGGBB` format.

### Launch a boat

```http
POST /api/boats/{boat_id}/launch
```

PowerShell:

```powershell
curl.exe -X POST http://localhost:8000/api/boats/ABCD/launch
```

This changes the boat status to:

```json
{
  "status": "launched"
}
```

Successful response status:

```text
200 OK
```

If the boat does not exist:

```text
404 Not Found
```

### Complete local test sequence

Once the backend is running, these commands test the seeded boat:

```powershell
curl.exe http://localhost:8000/health
curl.exe http://localhost:8000/api/boats/ABCD
curl.exe -X PATCH "http://localhost:8000/api/boats/ABCD" -H "Content-Type: application/json" -d '{"color":"#ff8800"}'
curl.exe -X POST http://localhost:8000/api/boats/ABCD/launch
curl.exe http://localhost:8000/api/boats/ABCD
```

Then open the frontend:

```powershell
Start-Process "http://localhost:5173/boat/ABCD"
```