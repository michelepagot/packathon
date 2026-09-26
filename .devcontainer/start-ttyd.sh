#!/usr/bin/env bash
# =============================================================================
# Packathon Codespace - Background ttyd Terminal & Keep-Alive Daemon
# =============================================================================
set -euo pipefail

WORKSPACE_DIR="${1:-/workspaces/packathon}"

# Start ttyd in background if not already running
if ! pgrep -x "ttyd" >/dev/null 2>&1; then
    echo "==> Starting ttyd daemon on port 7681 in ${WORKSPACE_DIR}..."
    nohup ttyd -p 7681 -w "${WORKSPACE_DIR}" -m 1 -W \
        -t fontSize=20 \
        -t 'theme={"background": "#121214", "foreground": "#e4e4e7", "cursor": "#528bff"}' \
        bash > /tmp/ttyd.log 2>&1 &
    disown
fi

# Start background keep-alive ping loop to prevent Codespace idle timeout
if ! pgrep -f "codespace-keepalive" >/dev/null 2>&1; then
    (
        exec -a codespace-keepalive bash -c 'while true; do echo "[$(date -u +%T)] keepalive heartbeat" >> /tmp/codespace-keepalive.log; sleep 120; done'
    ) &
    disown
fi
