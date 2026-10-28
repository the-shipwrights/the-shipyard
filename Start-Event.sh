#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${SHIPYARD_PYTHON:-python3}"
NPM="${SHIPYARD_NPM:-npm}"
GODOT="${SHIPYARD_GODOT:-}"
CLOUDFLARED="${SHIPYARD_CLOUDFLARED:-cloudflared}"

cd "$REPO_ROOT"

if [[ -f .venv-wsl/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv-wsl/bin/activate
elif [[ -f .venv/bin/activate ]]; then
    # shellcheck disable=SC1091
    source .venv/bin/activate
fi

for command_name in "$PYTHON" "$NPM" "$CLOUDFLARED"; do
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
        printf 'Open simulation/client in the Godot editor, export the Web preset, and try again.\n' >&2
        exit 1
    fi
done
# stale_client_source="$(find "$REPO_ROOT/simulation/client" -type f \
#     ! -path '*/.godot/*' ! -name '*.uid' ! -name '*.import' ! -name '.editorconfig' \
#     -newer "$CLIENT_EXPORT_DIR/client.pck" -print -quit)"
# if [[ -n "$stale_client_source" ]]; then
#     printf 'Godot client source is newer than the Web export: %s\n' "$stale_client_source" >&2
#     printf 'Export the Web preset in the Godot editor before starting the event.\n' >&2
#     exit 1
# fi

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
TUNNEL_LOG="$(mktemp -t shipyard-tunnel.XXXXXX)"
API_PID=""
GODOT_PID=""
TUNNEL_PID=""
MANUAL_GODOT=0
EVENT_READY=0

cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM

    for process_id in "$TUNNEL_PID" "$GODOT_PID" "$API_PID"; do
        if [[ -n "$process_id" ]]; then
            kill "$process_id" 2>/dev/null || true
        fi
    done
    for process_id in "$TUNNEL_PID" "$GODOT_PID" "$API_PID"; do
        if [[ -n "$process_id" ]]; then
            wait "$process_id" 2>/dev/null || true
        fi
    done

    if [[ "$EVENT_READY" -eq 1 ]]; then
        rm -f -- "$API_LOG" "$TUNNEL_LOG"
    else
        printf 'Startup logs kept at:\n  %s\n  %s\n' "$API_LOG" "$TUNNEL_LOG" >&2
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
    if "$PYTHON" -c 'from urllib.request import urlopen; urlopen("http://127.0.0.1:8000/health", timeout=2)' >/dev/null 2>&1; then
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
    printf 'The simulation can connect as soon as this API is ready.\n'
    read -r -p 'Press Enter here once the simulation is running: ' _
fi

printf 'Starting the temporary public tunnel...\n'
"$CLOUDFLARED" tunnel --url http://127.0.0.1:8000 >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

PUBLIC_URL=""
for _ in {1..120}; do
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        printf 'The Cloudflare tunnel stopped before providing a URL. See %s\n' "$TUNNEL_LOG" >&2
        exit 1
    fi
    PUBLIC_URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" | head -n 1 || true)"
    if [[ -n "$PUBLIC_URL" ]]; then
        break
    fi
    sleep 0.5
done

if [[ -z "$PUBLIC_URL" ]]; then
    printf 'The tunnel did not provide a public URL. See %s\n' "$TUNNEL_LOG" >&2
    exit 1
fi

EVENT_READY=1
export SHIPYARD_API_URL="http://127.0.0.1:8000"
export SHIPYARD_PUBLIC_URL="$PUBLIC_URL"
printf '\nParticipant site: %s\n' "$PUBLIC_URL"
printf 'Operator page:    %s/admin\n' "$PUBLIC_URL"
printf 'The scanner prints a boat ID, participant link, and QR code after each submission.\n'
printf 'Press Ctrl+C here to stop the event services.\n\n'

cd "$REPO_ROOT"
"$PYTHON" -m scanning.tui
