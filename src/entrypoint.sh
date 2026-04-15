#!/busybox/sh
set -eu

VAULT_SYNC_INTERVAL="${VAULT_SYNC_INTERVAL:-120}"

vault_sync_loop() {
    while true; do
        echo "Next vault sync in $VAULT_SYNC_INTERVAL seconds"
        sleep "$VAULT_SYNC_INTERVAL"
        bw sync --force; echo
    done
}

# Graceful shutdown: forward signals to both child processes
cleanup() {
    echo "Shutting down gracefully..."
    kill "$SYNC_PID" 2>/dev/null || true
    kill "$BW_PID"   2>/dev/null || true
    wait "$BW_PID"   2>/dev/null || true
}
trap cleanup TERM INT

CURRENT_SERVER=$(bw config server || true)
if [ "$CURRENT_SERVER" != "$BW_HOST" ]; then
    echo "Setting config server to $BW_HOST"
    # Existing auth is bound to the previous server; clear it before re-auth.
    bw logout > /dev/null 2>&1 || true
    bw config server "$BW_HOST"; echo
else
    echo "Config server already set to $BW_HOST"
fi

CREDENTIALS_CHANGED=0

if bw login --check > /dev/null 2>&1; then
    echo "Already logged in, verifying credentials match..."
    STATUS=$(bw status 2>/dev/null || echo '{}')
    LOGGED_IN_USER=$(echo "$STATUS" | grep -o '"userEmail":"[^"]*"' | cut -d'"' -f4 || true)
    LOGGED_IN_USERID=$(echo "$STATUS" | grep -o '"userId":"[^"]*"' | cut -d'"' -f4 || true)

    if [ -z "$LOGGED_IN_USER" ]; then
        echo "Warning: Could not parse current user from bw status, attempting to verify unlock..."
    else
        echo "Currently logged in as: $LOGGED_IN_USER (ID: $LOGGED_IN_USERID)"
    fi

    # If using API key auth, check if the API key's user ID matches the logged-in user
    if [ -n "${BW_CLIENTID:-}" ]; then
        CLIENTID_USERID=$(echo "$BW_CLIENTID" | cut -d'.' -f2 || true)
        if [ -n "$CLIENTID_USERID" ] && [ -n "$LOGGED_IN_USERID" ]; then
            if [ "$CLIENTID_USERID" != "$LOGGED_IN_USERID" ]; then
                echo "API key user ID ($CLIENTID_USERID) differs from logged-in user ($LOGGED_IN_USERID); re-authenticating..."
                CREDENTIALS_CHANGED=1
                bw logout > /dev/null 2>&1 || true
            else
                echo "API key user ID matches logged-in user"
            fi
        fi
    fi
else
    CREDENTIALS_CHANGED=1
fi

if [ "$CREDENTIALS_CHANGED" -eq 1 ]; then
    if [ -n "${BW_CLIENTID:-}" ] && [ -n "${BW_CLIENTSECRET:-}" ]; then
        echo "Using apikey to log in"
        bw login --apikey --raw > /dev/null
    else
        echo "Using username and password to log in"
        bw login "$BW_USER" --passwordenv BW_PASSWORD --raw > /dev/null
    fi
fi

echo "Unlocking vault"
export BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
bw unlock --check; echo

# Start background sync loop — inherits stdout/stderr, visible in docker logs
vault_sync_loop &
SYNC_PID=$!

# Start bw serve in background so the shell (PID 1) can handle signals
echo 'Listening on port 8087'
bw serve --hostname 0.0.0.0 &
BW_PID=$!

# Wait for bw serve; container exits when it does
wait "$BW_PID"
