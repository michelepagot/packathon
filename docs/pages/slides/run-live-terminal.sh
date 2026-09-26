#!/usr/bin/env bash
# =============================================================================
# Packathon - Local Presentation Server & Emergency Terminal Fallback
# Serves docs/pages via Python HTTP server and runs ttyd bound strictly to 127.0.0.1
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAGES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

HTTP_PORT="${HTTP_PORT:-8000}"
TERM_PORT="${TERM_PORT:-7681}"
FONT_SIZE="${FONT_SIZE:-20}"

# Check for Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "==> Error: 'python3' is not installed or not in PATH."
    exit 1
fi

# Check for ttyd
if ! command -v ttyd >/dev/null 2>&1; then
    echo "==> Warning: 'ttyd' is not installed on this host."
    echo "    To enable the live terminal, install via: 'sudo zypper in ttyd'"
    echo "    or download the binary from: https://github.com/tsl0922/ttyd/releases"
    echo ""
    echo "    Starting Python HTTP server only..."
    exec python3 -m http.server "${HTTP_PORT}" --directory "${PAGES_DIR}"
fi

cleanup() {
    echo ""
    echo "==> Shutting down presentation and terminal servers..."
    if [[ -n "${HTTP_PID:-}" ]] && kill -0 "${HTTP_PID}" 2>/dev/null; then
        kill "${HTTP_PID}" 2>/dev/null || true
    fi
    if [[ -n "${TTYD_PID:-}" ]] && kill -0 "${TTYD_PID}" 2>/dev/null; then
        kill "${TTYD_PID}" 2>/dev/null || true
    fi
    wait 2>/dev/null || true
    echo "==> Done."
}
trap cleanup INT TERM EXIT

echo "================================================================="
echo "  Packathon - Local Slides & Emergency Terminal Server"
echo "================================================================="
echo "  1. Python Web Server (Serving docs/pages):"
echo "     - Slides:     http://localhost:${HTTP_PORT}/slides/"
echo "     - Test Bench: http://localhost:${HTTP_PORT}/slides/terminal-test.html"
echo "     - Home Page:  http://localhost:${HTTP_PORT}/"
echo ""
echo "  2. Web Terminal (ttyd bound to 127.0.0.1):"
echo "     - Endpoint:   http://localhost:${TERM_PORT}"
echo "     - Shell cwd:  ${REPO_ROOT}"
echo "================================================================="
echo "Press Ctrl+C to stop all servers."
echo ""

# Start Python HTTP server in background
python3 -m http.server "${HTTP_PORT}" --directory "${PAGES_DIR}" >/dev/null 2>&1 &
HTTP_PID=$!

# Launch ttyd (foreground) bound strictly to loopback interface 'lo'
exec ttyd -i lo -p "${TERM_PORT}" -w "${REPO_ROOT}" -m 1 -W \
    -t fontSize="${FONT_SIZE}" \
    -t 'theme={"background": "#121214", "foreground": "#e4e4e7", "cursor": "#528bff"}' \
    bash
