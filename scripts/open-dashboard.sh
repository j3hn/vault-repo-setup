#!/bin/bash

# ============================================================
# open-dashboard.sh
# Starts browser-sync + fswatch for a project dashboard.
# Shuts everything down when the browser tab is closed.
# ============================================================
# Usage:
#   open-dashboard <project-name>
# ============================================================

_SCRIPT="${BASH_SOURCE[0]}"
[ -L "$_SCRIPT" ] && _SCRIPT="$(readlink "$_SCRIPT")"
SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"

VAULT_ROOT="${VAULT_ROOT:-$HOME/vault}"
BS_PORT="${DASHBOARD_PORT:-3100}"
PING_PORT="${DASHBOARD_PING_PORT:-19876}"

PROJECT="$1"
if [ -z "$PROJECT" ]; then
    echo "❌  Usage: open-dashboard <project-name>"
    exit 1
fi

VAULT_PROJECT="$VAULT_ROOT/Projects/$PROJECT"

if [ ! -d "$VAULT_PROJECT" ]; then
    echo "❌  Vault project not found: $VAULT_PROJECT"
    exit 1
fi

# Find dashboard HTML
HTML_FILE=$(find "$VAULT_PROJECT" -maxdepth 1 -name "*Dashboard.html" 2>/dev/null | head -1)
if [ -z "$HTML_FILE" ]; then
    echo "❌  No *Dashboard.html found in $VAULT_PROJECT"
    echo "   Run: new-project $PROJECT  (or copy dashboard-template.html manually)"
    exit 1
fi
HTML_NAME=$(basename "$HTML_FILE")

# Check dependencies
for cmd in browser-sync fswatch python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌  $cmd not found."
        [ "$cmd" = "browser-sync" ] && echo "   Install: pnpm add -g browser-sync"
        [ "$cmd" = "fswatch" ]      && echo "   Install: brew install fswatch"
        exit 1
    fi
done

# Cleanup: kill all child processes on exit
cleanup() {
    kill "$PING_PID" "$BS_PID" "$FSWATCH_PID" 2>/dev/null
    wait "$PING_PID" "$BS_PID" "$FSWATCH_PID" 2>/dev/null
    echo "🛑  Dashboard stopped."
}
trap cleanup EXIT INT TERM

# Initial sync
python3 "$SCRIPT_DIR/sync-dashboard.py" "$VAULT_PROJECT" --quiet

# Start heartbeat server — exits when browser tab stops pinging
python3 "$SCRIPT_DIR/ping-server.py" "$PING_PORT" &
PING_PID=$!

# Start browser-sync
browser-sync start \
    --server "$VAULT_PROJECT" \
    --files "$HTML_FILE" \
    --port "$BS_PORT" \
    --no-open \
    --logLevel silent \
    2>/dev/null &
BS_PID=$!

sleep 1  # let browser-sync bind

# URL-encode the filename (spaces → %20) for the browser
HTML_URL_NAME="${HTML_NAME// /%20}"

# Open browser
open "http://localhost:$BS_PORT/$HTML_URL_NAME?ping=$PING_PORT"

# Watch markdown files only — exclude HTML and .command to avoid feedback loop
fswatch -o -e "\.html$" -e "\.command$" "$VAULT_PROJECT" | while read -r; do
    python3 "$SCRIPT_DIR/sync-dashboard.py" "$VAULT_PROJECT" --quiet
done &
FSWATCH_PID=$!

echo "📊  Dashboard: http://localhost:$BS_PORT/$HTML_URL_NAME"
echo "   Edit docs/ markdown — dashboard updates automatically."
echo "   Close the browser tab to stop (15 s grace period)."
echo ""

# Block until the ping server exits (triggered by browser tab close)
wait "$PING_PID"
