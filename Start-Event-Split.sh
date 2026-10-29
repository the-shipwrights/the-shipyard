#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${SHIPYARD_PYTHON:-python3}"
NPM="${SHIPYARD_NPM:-npm}"
GODOT="${SHIPYARD_GODOT:-}"

cd "$REPO_ROOT"

if [[ -f .venv-wsl/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv-wsl/bin/activate
elif [[ -f .venv/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
fi

for command_name in "$PYTHON" "$NPM"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        printf 'Install it or set the matching SHIPYARD_* variable.\n' >&2
        exit 127
    fi
done

if [[ -z "$GODOT" ]] && command -v godot >/dev/null 2>&1; then
    GODOT="godot"
fi

if [[ -n "$GODOT" ]] && ! command -v "$GODOT" >/dev/null 2>&1; then
    printf 'SHIPYARD_GODOT was set but is not executable: %s\n' "$GODOT" >&2
    exit 127
fi

CLIENT_EXPORT_DIR="$REPO_ROOT/web/public/godot/client"
for artifact in client.html client.js client.wasm client.pck; do
    if [[ ! -s "$CLIENT_EXPORT_DIR/$artifact" ]]; then
        printf 'Missing Godot Web export artifact: %s\n' "$CLIENT_EXPORT_DIR/$artifact" >&2
        printf 'Open simulation/client in Godot, export the Web preset, and try again.\n' >&2
        exit 1
    fi
done

ADMIN_USER="${SHIPYARD_ADMIN_USER:-}"
ADMIN_PASSWORD="${SHIPYARD_ADMIN_PASSWORD:-}"
unset SHIPYARD_ADMIN_USER SHIPYARD_ADMIN_PASSWORD

if [[ -z "$ADMIN_USER" ]]; then
    read -r -p 'Operator username [operator]: ' ADMIN_USER
    ADMIN_USER="${ADMIN_USER:-operator}"
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
    read -r -s -p 'Set operator password for this event: ' ADMIN_PASSWORD
    printf '\n'
fi

if [[ -z "$ADMIN_PASSWORD" ]]; then
    printf 'An operator password is required.\n' >&2
    exit 1
fi

API_LOG="$(mktemp -t shipyard-api.XXXXXX)"
API_PID=""
GODOT_PID=""
MANUAL_GODOT=0
EVENT_READY=0

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM

    if [[ -n "$GODOT_PID" ]]; then
        kill "$GODOT_PID" 2>/dev/null || true
    fi
    if [[ -n "$API_PID" ]]; then
        kill "$API_PID" 2>/dev/null || true
    fi

    if [[ -n "$GODOT_PID" ]]; then
        wait "$GODOT_PID" 2>/dev/null || true
    fi
    if [[ -n "$API_PID" ]]; then
        wait "$API_PID" 2>/dev/null || true
    fi

    if [[ "$EVENT_READY" -eq 1 ]]; then
        rm -f -- "$API_LOG"
    else
        printf 'API startup log kept at: %s\n' "$API_LOG" >&2
    fi

    if [[ "$MANUAL_GODOT" -eq 1 ]]; then
        printf 'Close the manually started Godot simulation separately.\n'
    fi

    unset ADMIN_PASSWORD
    exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Building the Vite web client from the existing Godot export...\n'
"$NPM" --prefix "$REPO_ROOT/web" run build

printf 'Starting the local API...\n'
(
    cd "$REPO_ROOT"
    exec env \
        SHIPYARD_ADMIN_USER="$ADMIN_USER" \
        SHIPYARD_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        "$PYTHON" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
) >"$API_LOG" 2>&1 &
API_PID=$!
unset ADMIN_PASSWORD

api_ready=0
for _ in {1..40}; do
    if ! kill -0 "$API_PID" 2>/dev/null; then
        printf 'The API process stopped early. See %s\n' "$API_LOG" >&2
        exit 1
    fi

    if "$PYTHON" -c \
        'from urllib.request import urlopen; urlopen("http://127.0.0.1:8000/health", timeout=2)' \
        >/dev/null 2>&1; then
        api_ready=1
        break
    fi

    sleep 0.5
done

if [[ "$api_ready" -ne 1 ]]; then
    printf 'The API did not become ready. See %s\n' "$API_LOG" >&2
    exit 1
fi

if [[ -n "$GODOT" ]]; then
    printf 'Starting the Godot simulation...\n'
    "$GODOT" --path "$REPO_ROOT/simulation/server" &
    GODOT_PID=$!
else
    MANUAL_GODOT=1
    printf '\nNo Godot command-line executable was found.\n'
    printf 'Open simulation/server in the Godot editor and run the project now.\n'
    read -r -p 'Press Enter here once the simulation is running: ' _
fi

printf '\nThe local API is ready at http://127.0.0.1:8000\n'
printf 'In a second WSL terminal tab, run: bash Start-Tunnel.sh\n'

while true; do
    read -r -p 'Paste the public HTTPS base URL from cloudflared: ' PUBLIC_URL

    while [[ "$PUBLIC_URL" == */ ]]; do
        PUBLIC_URL="${PUBLIC_URL%/}"
    done

    if [[ "$PUBLIC_URL" =~ ^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$ ]]; then
        break
    fi

    printf 'Enter the base URL only, for example https://example.trycloudflare.com\n' >&2
done

export SHIPYARD_API_URL="http://127.0.0.1:8000"
export SHIPYARD_PUBLIC_URL="$PUBLIC_URL"

EVENT_READY=1

printf '\nParticipant site: %s\n' "$SHIPYARD_PUBLIC_URL"
printf 'Operator page:    %s/admin\n' "$SHIPYARD_PUBLIC_URL"
printf 'The scanner will print each boat ID and participant QR code.\n'
printf 'Press Ctrl+C here to stop the scanner and local API.\n\n'

cd "$REPO_ROOT"
"$PYTHON" -m scanning.tui