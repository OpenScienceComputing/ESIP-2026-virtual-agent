#!/usr/bin/env bash
# Start an Arraylake device-code login that works without a browser, and print
# the activation URL as soon as the CLI emits it.
#
# Blocks until the login completes (or times out), so run it as a background
# task and read the URL from stdout or from the log file.
#
#   Usage: al-login.sh [logfile]
#   Env:   ARRAYLAKE_BIN  path to the arraylake CLI (default: first on PATH)

set -uo pipefail

LOG="${1:-$HOME/.cache/arraylake-login.log}"
# Auth0 device codes expire after ~15 min; waiting longer than the code lives
# is pointless, and waiting less strands a user who stepped away.
TIMEOUT="${AL_LOGIN_TIMEOUT:-900}"

# Resolve the CLI. It commonly lives in a conda env rather than on PATH.
AL="${ARRAYLAKE_BIN:-}"
if [ -z "$AL" ]; then
    if command -v arraylake >/dev/null 2>&1; then
        AL="$(command -v arraylake)"
    else
        for c in "$HOME"/miniforge3/envs/*/bin/arraylake \
                 "$HOME"/micromamba/envs/*/bin/arraylake \
                 "$HOME"/mambaforge/envs/*/bin/arraylake; do
            [ -x "$c" ] && { AL="$c"; break; }
        done
    fi
fi
if [ -z "$AL" ] || [ ! -x "$AL" ]; then
    echo "ERROR: arraylake CLI not found. Set ARRAYLAKE_BIN to its full path." >&2
    exit 127
fi

mkdir -p "$(dirname "$LOG")"
: > "$LOG"

# `script` supplies a pty so the CLI prints its normal panel; without one some
# rich output is suppressed. -f flushes after each write so we can poll the log.
script -q -f "$LOG" -c "$AL auth login --no-browser" </dev/null >/dev/null 2>&1 &
LOGIN_PID=$!

# Pull the URL out of raw bytes: the panel is wrapped in ANSI/OSC-8 escapes, and
# `strings` sidesteps having to unwrap them correctly.
extract_url() {
    strings "$LOG" 2>/dev/null \
        | grep -oE 'https://[^ ]*activate\?user_code=[A-Za-z0-9-]+' \
        | head -1
}

URL=""
for _ in $(seq 1 60); do
    URL="$(extract_url)"
    [ -n "$URL" ] && break
    kill -0 "$LOGIN_PID" 2>/dev/null || break
    sleep 1
done

if [ -z "$URL" ]; then
    echo "ERROR: no activation URL appeared within 60s. Log: $LOG" >&2
    sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r/\n/g' "$LOG" \
        | grep -vE 'Waiting for login|^[[:space:]]*$' | tail -20 >&2
    kill "$LOGIN_PID" 2>/dev/null
    exit 1
fi

echo "Open this URL in a browser and approve the login:"
echo
echo "    $URL"
echo
echo "(waiting up to $((TIMEOUT / 60)) min for approval; log: $LOG)"

# Wait for the user to approve. The CLI exits once it has exchanged the code.
WAITED=0
while kill -0 "$LOGIN_PID" 2>/dev/null; do
    if [ "$WAITED" -ge "$TIMEOUT" ]; then
        echo "ERROR: timed out after ${TIMEOUT}s. The code has expired -- rerun to get a fresh URL." >&2
        kill "$LOGIN_PID" 2>/dev/null
        exit 1
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

echo
"$AL" auth status 2>&1 | sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' | grep -vE '^[[:space:]]*$'
