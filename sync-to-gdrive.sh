#!/usr/bin/env bash
# Sync ~/Documents → Google Drive
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOG_DIR="$HOME/.local/share/doc-sync/logs"
LOG_FILE="$LOG_DIR/sync-to-gdrive.log"
FILTER_FILE="$SCRIPT_DIR/filter-rules.txt"
SOURCE="$HOME/Documents"
DEST="gdrive:EdenTnS"

mkdir -p "$LOG_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] START sync-to-gdrive" >> "$LOG_FILE"

rclone sync "$SOURCE" "$DEST" \
    --filter-from "$FILTER_FILE" \
    --transfers 4 \
    --checkers 8 \
    --log-file "$LOG_FILE" \
    --log-level INFO \
    --stats-one-line \
    "$@"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] END sync-to-gdrive" >> "$LOG_FILE"
