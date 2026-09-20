#!/bin/bash
# Toggle Gemini: Ctrl+Alt+G = open, Ctrl+Alt+G = close
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
XDOTOOL="$HOME/.local/bin/xdotool"
URL="https://gemini.google.com"
PID_FILE="/tmp/gemini_popup.pid"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
    echo "[CLOSE]"
else
    rm -f "$PID_FILE"
    firefox --new-window "$URL" --width 400 --height 600 &>/dev/null &
    echo $! > "$PID_FILE"
    echo "[OPEN]"
fi
