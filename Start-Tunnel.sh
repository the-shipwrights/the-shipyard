#!/usr/bin/env bash
set -Eeuo pipefail

CLOUDFLARED="${SHIPYARD_CLOUDFLARED:-cloudflared}"

if ! command -v "$CLOUDFLARED" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$CLOUDFLARED" >&2
    printf 'Install cloudflared or set SHIPYARD_CLOUDFLARED to its path.\n' >&2
    exit 127
fi

printf 'Starting the Cloudflare tunnel to http://127.0.0.1:8000\n'
printf 'Keep this terminal running during the event. Press Ctrl+C to stop the tunnel.\n\n'

exec "$CLOUDFLARED" tunnel --url http://127.0.0.1:8000