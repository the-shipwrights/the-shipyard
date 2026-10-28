# Web client

Use WSL/Linux Bash from the repository root. The frontend requires Node.js and npm.

Install dependencies once:

```bash
npm --prefix web install
```

With FastAPI running at `127.0.0.1:8000`, start Vite:

```bash
npm --prefix web run dev
```

Open `http://localhost:5173`. Vite proxies `/api` and `/ws` to FastAPI, so the Godot web client can use the same origin during local development. The seeded boat route is `/boat/BOAT`; the builder is available at `/build` and the operator console at `/admin`.

For an exhibition, export the Godot project's Web preset in the editor after client changes, then run `bash ./Start-Event.sh` from the repository root. The launcher builds the Vite app and serves it with FastAPI through a temporary HTTPS tunnel. If no Godot command-line executable is available, it pauses for you to start the simulation from the editor. The scanner prints the current public URL in each boat's QR code.
