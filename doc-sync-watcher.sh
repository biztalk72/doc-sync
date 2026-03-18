#!/usr/bin/env bash
# Event-driven file sync watcher using fswatch
# Watches ~/Documents and iCloud Drive, triggers rclone sync on changes
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOG_DIR="$HOME/.local/share/doc-sync/logs"
LOG_FILE="$LOG_DIR/watcher.log"
PID_DIR="$HOME/.local/share/doc-sync"
DOCUMENTS="$HOME/Documents"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/EdenTnS"
DEBOUNCE_SEC=60

mkdir -p "$LOG_DIR" "$PID_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

cleanup() {
    log "Stopping watchers..."
    # Kill child processes
    if [[ -f "$PID_DIR/fswatch-docs.pid" ]]; then
        kill "$(cat "$PID_DIR/fswatch-docs.pid")" 2>/dev/null || true
        rm -f "$PID_DIR/fswatch-docs.pid"
    fi
    if [[ -f "$PID_DIR/fswatch-icloud.pid" ]]; then
        kill "$(cat "$PID_DIR/fswatch-icloud.pid")" 2>/dev/null || true
        rm -f "$PID_DIR/fswatch-icloud.pid"
    fi
    rm -f "$PID_DIR/watcher.pid"
    log "Watchers stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Check if already running
if [[ -f "$PID_DIR/watcher.pid" ]]; then
    OLD_PID=$(cat "$PID_DIR/watcher.pid")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Watcher already running (PID $OLD_PID). Use 'kill $OLD_PID' to stop." >&2
        exit 1
    fi
    rm -f "$PID_DIR/watcher.pid"
fi

echo $$ > "$PID_DIR/watcher.pid"
log "Watcher started (PID $$)"

# --- Watch ~/Documents → push to GDrive + iCloud ---
(
    fswatch -r -l "$DEBOUNCE_SEC" \
        --exclude '\.DS_Store$' \
        --exclude '/\._' \
        --exclude '\.Trash' \
        "$DOCUMENTS" | while read -r _event; do
        log "Change detected in ~/Documents — recording & pushing to remotes"
        "$SCRIPT_DIR/record-changes.sh" "$DOCUMENTS" "Local → GDrive + iCloud" 2>> "$LOG_FILE" || log "WARN: changelog record failed"
        "$SCRIPT_DIR/sync-all.sh" push 2>> "$LOG_FILE" || log "ERROR: push sync failed"
    done
) &
echo $! > "$PID_DIR/fswatch-docs.pid"
log "Watching ~/Documents (PID $!)"

# --- Watch iCloud Drive → pull to ~/Documents ---
# Ensure iCloud target directory exists
mkdir -p "$ICLOUD"
(
    fswatch -r -l "$DEBOUNCE_SEC" \
        --exclude '\.DS_Store$' \
        --exclude '/\._' \
        --exclude '\.Trash' \
        "$ICLOUD" | while read -r _event; do
        log "Change detected in iCloud Drive — recording & pulling to ~/Documents"
        "$SCRIPT_DIR/record-changes.sh" "$ICLOUD" "iCloud → Local" 2>> "$LOG_FILE" || log "WARN: changelog record failed"
        "$SCRIPT_DIR/sync-from-icloud.sh" 2>> "$LOG_FILE" || log "ERROR: iCloud pull failed"
        "$SCRIPT_DIR/record-changes.sh" "$DOCUMENTS" "Local (after iCloud pull)" 2>> "$LOG_FILE" || true
    done
) &
echo $! > "$PID_DIR/fswatch-icloud.pid"
log "Watching iCloud Drive (PID $!)"

echo "Doc-sync watcher started. Watching ~/Documents and iCloud Drive."
echo "Logs: $LOG_FILE"
echo "Stop with: kill $$"

# Wait for child processes
wait
