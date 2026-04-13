#!/usr/bin/env bash
set -eo pipefail

VAULT_SYNC_INTERVAL="${VAULT_SYNC_INTERVAL:-120}"

vault_sync_loop() {
    while true; do
        sleep "$VAULT_SYNC_INTERVAL"
        bw sync --force
    done
}

# Graceful shutdown: forward signals to both child processes
cleanup() {
    echo "Shutting down gracefully..."
    kill "$SYNC_PID" 2>/dev/null || true
    kill "$BW_PID"   2>/dev/null || true
    wait "$BW_PID"   2>/dev/null || true
}
trap cleanup SIGTERM SIGINT

# Logout any existing sessions to ensure a clean state after a container restart
bw logout > /dev/null 2>&1 || true

bw config server "$BW_HOST"; echo

if [ -n "$BW_CLIENTID" ] && [ -n "$BW_CLIENTSECRET" ]; then
    echo "Using apikey to log in"
    bw login --apikey --raw
    export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
else
    echo "Using username and password to log in"
    export BW_SESSION=$(bw login "$BW_USER" --passwordenv BW_PASSWORD --raw)
fi

bw unlock --check; echo

# Start background sync loop — inherits stdout/stderr, visible in docker logs
vault_sync_loop &
SYNC_PID=$!

# Start bw serve in background so the shell (PID 1) can handle signals
echo 'Running `bw serve` on port 8087'
bw serve --hostname 0.0.0.0 &
BW_PID=$!

# Wait for bw serve; container exits when it does
wait "$BW_PID"
