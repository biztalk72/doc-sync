#!/usr/bin/env bash
# Test script: verifies sync across Local, Google Drive, and iCloud Drive
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOCAL="$HOME/Documents"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/EdenTnS"
GDRIVE="gdrive:EdenTnS"
TEST_FILE="sync_test_$(date '+%Y%m%d_%H%M%S').txt"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}▶${NC} $1"; }

echo "============================================"
echo "  Doc-Sync Test — $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# --- 1. Check prerequisites ---
info "Checking prerequisites..."

if command -v rclone &>/dev/null; then
    pass "rclone installed ($(rclone version | head -1))"
else
    fail "rclone not found"
fi

if command -v fswatch &>/dev/null; then
    pass "fswatch installed"
else
    fail "fswatch not found"
fi

if rclone listremotes | grep -q "gdrive:"; then
    pass "Google Drive remote configured"
else
    fail "Google Drive remote not configured"
fi

if rclone listremotes | grep -q "icloud:"; then
    pass "iCloud remote configured"
else
    fail "iCloud remote not configured"
fi

echo ""

# --- 2. Check folders exist ---
info "Checking folders..."

if [[ -d "$LOCAL" ]]; then
    LOCAL_COUNT=$(ls "$LOCAL" | wc -l | tr -d ' ')
    pass "Local ~/Documents exists ($LOCAL_COUNT items)"
else
    fail "Local ~/Documents not found"
fi

if [[ -d "$ICLOUD" ]]; then
    ICLOUD_COUNT=$(ls "$ICLOUD" | wc -l | tr -d ' ')
    pass "iCloud EdenTnS exists ($ICLOUD_COUNT items)"
else
    fail "iCloud EdenTnS not found"
fi

if rclone lsd "$GDRIVE/" &>/dev/null; then
    GDRIVE_COUNT=$(rclone ls "$GDRIVE/" 2>/dev/null | wc -l | tr -d ' ')
    pass "GDrive EdenTnS exists ($GDRIVE_COUNT files)"
else
    fail "GDrive EdenTnS not found"
fi

echo ""

# --- 3. Check services ---
info "Checking services..."

WATCHER_LINE=$(launchctl list 2>/dev/null | grep "com.brian.docsync-watcher" || true)
if [[ -n "$WATCHER_LINE" ]]; then
    WPID=$(echo "$WATCHER_LINE" | awk '{print $1}')
    if [[ "$WPID" != "-" ]]; then
        pass "Watcher service running (PID $WPID)"
    else
        fail "Watcher service loaded but not running"
    fi
else
    fail "Watcher service not loaded"
fi

GDPULL_LINE=$(launchctl list 2>/dev/null | grep "com.brian.docsync-gdrive-pull" || true)
if [[ -n "$GDPULL_LINE" ]]; then
    pass "GDrive pull service loaded"
else
    fail "GDrive pull service not loaded"
fi

echo ""

# --- 4. Live sync test ---
info "Running live sync test..."
echo "  Creating test file: $TEST_FILE"

echo "sync-test $(date)" > "$LOCAL/$TEST_FILE"

# Push to iCloud
info "Syncing to iCloud..."
"$SCRIPT_DIR/sync-to-icloud.sh" 2>/dev/null
if [[ -f "$ICLOUD/$TEST_FILE" ]]; then
    pass "Local → iCloud sync works"
else
    fail "Local → iCloud sync failed"
fi

# Push to GDrive
info "Syncing to Google Drive..."
"$SCRIPT_DIR/sync-to-gdrive.sh" 2>/dev/null
if rclone ls "$GDRIVE/$TEST_FILE" &>/dev/null; then
    pass "Local → GDrive sync works"
else
    fail "Local → GDrive sync failed"
fi

echo ""

# --- 5. Modify test ---
info "Testing file modification sync..."
echo "MODIFIED at $(date)" > "$LOCAL/$TEST_FILE"

"$SCRIPT_DIR/sync-to-icloud.sh" 2>/dev/null
ICLOUD_CONTENT=$(cat "$ICLOUD/$TEST_FILE" 2>/dev/null || echo "")
if [[ "$ICLOUD_CONTENT" == *"MODIFIED"* ]]; then
    pass "Modify → iCloud synced"
else
    fail "Modify → iCloud not synced"
fi

"$SCRIPT_DIR/sync-to-gdrive.sh" 2>/dev/null
GDRIVE_CONTENT=$(rclone cat "$GDRIVE/$TEST_FILE" 2>/dev/null || echo "")
if [[ "$GDRIVE_CONTENT" == *"MODIFIED"* ]]; then
    pass "Modify → GDrive synced"
else
    fail "Modify → GDrive not synced"
fi

echo ""

# --- 6. Delete test ---
info "Testing file deletion sync..."
sleep 2
rm -f "$LOCAL/$TEST_FILE"

"$SCRIPT_DIR/sync-to-icloud.sh" 2>/dev/null
if [[ ! -f "$ICLOUD/$TEST_FILE" ]]; then
    pass "Delete → iCloud synced"
else
    fail "Delete → iCloud not synced (file still exists)"
fi

"$SCRIPT_DIR/sync-to-gdrive.sh" 2>/dev/null
if ! rclone ls "$GDRIVE/$TEST_FILE" &>/dev/null; then
    pass "Delete → GDrive synced"
else
    fail "Delete → GDrive not synced (file still exists)"
fi

echo ""

# --- 7. Cleanup ---
info "Cleaning up..."
rm -f "$LOCAL/$TEST_FILE" "$ICLOUD/$TEST_FILE" 2>/dev/null
rclone deletefile "$GDRIVE/$TEST_FILE" 2>/dev/null || true
pass "Cleanup done"

echo ""

# --- Summary ---
echo "============================================"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
    echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} out of $TOTAL"
fi
echo "============================================"
