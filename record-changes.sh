#!/usr/bin/env bash
# Records file changes (create/modify/delete) to a changelog with versioning
# Usage: record-changes.sh <source_dir> <label>
#   e.g. record-changes.sh ~/Documents "Local → Remote"
set -euo pipefail

SOURCE="${1:?Usage: record-changes.sh <source_dir> <label>}"
LABEL="${2:-sync}"
DATA_DIR="$HOME/.local/share/doc-sync"
CHANGELOG="$DATA_DIR/changelog.txt"
SNAPSHOT_FILE="$DATA_DIR/snapshot-$(echo "$SOURCE" | md5 -q).txt"
VERSION_FILE="$DATA_DIR/version.txt"

mkdir -p "$DATA_DIR"

# --- Version management ---
if [[ -f "$VERSION_FILE" ]]; then
    VERSION=$(cat "$VERSION_FILE")
else
    VERSION=0
fi

# --- Build current snapshot: relative_path | size | mtime ---
CURRENT_SNAPSHOT=$(mktemp)
trap "rm -f '$CURRENT_SNAPSHOT'" EXIT

if [[ -d "$SOURCE" ]]; then
    find "$SOURCE" -type f \
        ! -name '.DS_Store' \
        ! -name '._*' \
        ! -path '*/.Trash/*' \
        ! -path '*/.fseventsd/*' \
        ! -path '*/.Spotlight-V100/*' \
        -exec stat -f '%N|%z|%m' {} \; 2>/dev/null \
    | sed "s|^$SOURCE/||" \
    | sort > "$CURRENT_SNAPSHOT"
fi

# --- Compare with previous snapshot ---
if [[ ! -f "$SNAPSHOT_FILE" ]]; then
    # First run — record initial snapshot, no changelog entry
    cp "$CURRENT_SNAPSHOT" "$SNAPSHOT_FILE"
    echo "$VERSION" > "$VERSION_FILE"
    exit 0
fi

PREV_SNAPSHOT="$SNAPSHOT_FILE"

# Extract filenames from snapshots
CURRENT_FILES=$(mktemp)
PREV_FILES=$(mktemp)
trap "rm -f '$CURRENT_SNAPSHOT' '$CURRENT_FILES' '$PREV_FILES'" EXIT

awk -F'|' '{print $1}' "$CURRENT_SNAPSHOT" | sort > "$CURRENT_FILES"
awk -F'|' '{print $1}' "$PREV_SNAPSHOT" | sort > "$PREV_FILES"

# Detect changes
CREATED=$(comm -23 "$CURRENT_FILES" "$PREV_FILES")
DELETED=$(comm -13 "$CURRENT_FILES" "$PREV_FILES")

# Detect modified (same filename, different size or mtime)
MODIFIED=""
COMMON=$(comm -12 "$CURRENT_FILES" "$PREV_FILES")
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    CUR_LINE=$(grep -F "${file}|" "$CURRENT_SNAPSHOT" | head -1 || true)
    PREV_LINE=$(grep -F "${file}|" "$PREV_SNAPSHOT" | head -1 || true)
    if [[ -n "$CUR_LINE" && -n "$PREV_LINE" && "$CUR_LINE" != "$PREV_LINE" ]]; then
        MODIFIED="${MODIFIED}${file}"$'\n'
    fi
done <<< "$COMMON"

# --- Write changelog if there are changes ---
HAS_CHANGES=false
CHANGES=""

if [[ -n "$CREATED" ]]; then
    HAS_CHANGES=true
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        CHANGES="${CHANGES}  [CREATE]  $f"$'\n'
    done <<< "$CREATED"
fi

if [[ -n "$MODIFIED" ]]; then
    HAS_CHANGES=true
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        CHANGES="${CHANGES}  [MODIFY]  $f"$'\n'
    done <<< "$MODIFIED"
fi

if [[ -n "$DELETED" ]]; then
    HAS_CHANGES=true
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        CHANGES="${CHANGES}  [DELETE]  $f"$'\n'
    done <<< "$DELETED"
fi

if [[ "$HAS_CHANGES" == true ]]; then
    VERSION=$((VERSION + 1))
    echo "$VERSION" > "$VERSION_FILE"

    # Count changes
    N_CREATE=$(echo "$CREATED" | grep -c . || true)
    N_MODIFY=$(echo "$MODIFIED" | grep -c . || true)
    N_DELETE=$(echo "$DELETED" | grep -c . || true)

    {
        echo "================================================================"
        echo "Version : v${VERSION}"
        echo "Date    : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Action  : ${LABEL}"
        echo "Summary : +${N_CREATE} created, ~${N_MODIFY} modified, -${N_DELETE} deleted"
        echo "----------------------------------------------------------------"
        printf "%s" "$CHANGES"
        echo "================================================================"
        echo ""
    } >> "$CHANGELOG"
fi

# Update snapshot
cp "$CURRENT_SNAPSHOT" "$SNAPSHOT_FILE"
