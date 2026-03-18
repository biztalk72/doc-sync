#!/usr/bin/env bash
# Pulls Google Drive changes and records changelog
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
DOCUMENTS="$HOME/Documents"
LOG_FILE="$HOME/.local/share/doc-sync/logs/watcher.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "GDrive periodic pull — starting"

# Record state before pull
"$SCRIPT_DIR/record-changes.sh" "$DOCUMENTS" "Local (before GDrive pull)" 2>> "$LOG_FILE" || true

# Pull from GDrive
"$SCRIPT_DIR/sync-from-gdrive.sh" "$@" 2>> "$LOG_FILE" || log "ERROR: GDrive pull failed"

# Record what changed after pull
"$SCRIPT_DIR/record-changes.sh" "$DOCUMENTS" "GDrive → Local (periodic pull)" 2>> "$LOG_FILE" || true

log "GDrive periodic pull — done"
