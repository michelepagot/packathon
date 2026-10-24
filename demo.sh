#!/usr/bin/env bash

# Trap SIGINT (CTRL+C) and call the cleanup function
trap 'echo -stopping servers...; kill "$TTYD_PID" "$HTTP_PID" 2>/dev/null; exit 0' SIGINT

# 1. Start ttyd in the background
nohup ttyd -p 7681 -w "$(pwd)" -m 1 -W -t fontSize=20 -t 'theme={"background": "#121214", "foreground": "#e4e4e7", "cursor": "#528bff"}' zsh > /tmp/ttyd.log 2>&1 &
TTYD_PID=$!

# 2. Start the HTTP server in the background
nohup python3 -m http.server 8800 --directory docs/pages/slides > /tmp/http_server.log 2>&1 &
HTTP_PID=$!

echo "Servers started:"
echo " - ttyd (PID: $TTYD_PID) -> http://localhost:7681"
echo " - HTTP Server (PID: $HTTP_PID) -> http://localhost:8800"
echo "Press CTRL+C to stop both."

# Wait indefinitely so the script stays alive to catch CTRL+C
wait
