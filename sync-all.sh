#!/usr/bin/env bash
# Master sync script — runs all sync directions with file locking
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOG_DIR="$HOME/.local/share/doc-sync/logs"
LOG_FILE="$LOG_DIR/sync-all.log"
LOCK_FILE="/tmp/doc-sync.lock.d"

mkdir -p "$LOG_DIR"

# Acquire exclusive lock (non-blocking — skip if another sync is running)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    # Check if stale lock (older than 30 min)
    if [[ -d "$LOCK_FILE" ]] && find "$LOCK_FILE" -maxdepth 0 -mmin +30 | grep -q .; then
        rm -rf "$LOCK_FILE"
        mkdir "$LOCK_FILE" 2>/dev/null || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SKIPPED — lock contention" >> "$LOG_FILE"; exit 0; }
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SKIPPED — another sync is already running" >> "$LOG_FILE"
        exit 0
    fi
fi
trap 'rm -rf "$LOCK_FILE"' EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] START sync-all" >> "$LOG_FILE"

# Direction can be specified: "push", "pull", or "all" (default)
DIRECTION="${1:-all}"

case "$DIRECTION" in
    push)
        "$SCRIPT_DIR/sync-to-gdrive.sh"
        "$SCRIPT_DIR/sync-to-icloud.sh"
        ;;
    pull)
        "$SCRIPT_DIR/sync-from-gdrive.sh"
        "$SCRIPT_DIR/sync-from-icloud.sh"
        ;;
    all)
        # Pull first (to get remote changes), then push
        "$SCRIPT_DIR/sync-from-gdrive.sh"
        "$SCRIPT_DIR/sync-from-icloud.sh"
        "$SCRIPT_DIR/sync-to-gdrive.sh"
        "$SCRIPT_DIR/sync-to-icloud.sh"
        ;;
    *)
        echo "Usage: $0 [push|pull|all]" >&2
        exit 1
        ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] END sync-all ($DIRECTION)" >> "$LOG_FILE"
