# the-shipyard

## 2. Frontend setup and run

Prerequisite: Node.js and npm.

Open a second terminal:

```powershell
cd C:\Users\minzh\Dokument\gitrepos\the-shipyard\web
```

Install the frontend dependencies:

```powershell
npm install
```

Start the Vite development server:

```powershell
npm run dev
```

The frontend will normally be available at:

```text
http://localhost:5173
```

To make the frontend accessible from other devices on the local network, use:

```powershell
npm run dev -- --host 0.0.0.0
```

For the current Godot integration, use `localhost` when running locally because the Godot client is configured to call:

```text
http://localhost:8000
```

After starting both servers, open the seeded boat editor at:

```text
http://localhost:5173/boat/ABCD
```

The simulation route is:

```text
http://localhost:5173/simulation
```
