#!/usr/bin/env bash
# Stop the doc-sync watcher
PID_DIR="$HOME/.local/share/doc-sync"

if [[ -f "$PID_DIR/watcher.pid" ]]; then
    PID=$(cat "$PID_DIR/watcher.pid")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Watcher (PID $PID) stopped."
    else
        echo "Watcher process $PID not running. Cleaning up."
        rm -f "$PID_DIR/watcher.pid" "$PID_DIR/fswatch-docs.pid" "$PID_DIR/fswatch-icloud.pid"
    fi
else
    echo "No watcher PID file found."
fi
