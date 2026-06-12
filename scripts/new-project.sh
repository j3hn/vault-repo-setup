#!/bin/bash

# ============================================================
# new-project.sh
# Creates a new project in both the vault and repo, then links them
# ============================================================
# Usage:
#   ./new-project.sh <project-name> [client-name]
#
# Example:
#   ./new-project.sh flowforest
#   ./new-project.sh acme-website "Acme Corp"
# ============================================================

# --- CONFIGURE THESE ---
VAULT_ROOT="${VAULT_ROOT:-$HOME/vault}"
DEV_ROOT="${DEV_ROOT:-$HOME/Dev}"
# -----------------------

PROJECT="$1"
CLIENT="${2:-}"
_SCRIPT="${BASH_SOURCE[0]}"
[ -L "$_SCRIPT" ] && _SCRIPT="$(readlink "$_SCRIPT")"
SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"

if [ -z "$PROJECT" ]; then
  echo "❌  Usage: ./new-project.sh <project-name> [client-name]"
  exit 1
fi

VAULT_PROJECT="$VAULT_ROOT/Projects/$PROJECT"
REPO_PATH="$DEV_ROOT/$PROJECT"
TODAY=$(date +%Y-%m-%d)

echo "🚀  Setting up project: $PROJECT"
echo ""

# 1. Create vault project folder from templates
if [ -d "$VAULT_PROJECT" ]; then
  echo "⚠️  Vault project already exists: $VAULT_PROJECT"
else
  mkdir -p "$VAULT_PROJECT"
  TEMPLATE_DIR="$SCRIPT_DIR/../templates/vault/Projects/_example-project"
  cp "$TEMPLATE_DIR"/*.md "$VAULT_PROJECT/"
  # Replace placeholders
  for f in "$VAULT_PROJECT"/*.md; do
    sed -i.bak "s/PROJECT_NAME/$PROJECT/g" "$f"
    sed -i.bak "s/CLIENT_NAME/$CLIENT/g" "$f"
    sed -i.bak "s/YYYY-MM-DD/$TODAY/g" "$f"
    rm -f "${f}.bak"
  done
  echo "✅  Vault project created: $VAULT_PROJECT"

  # Copy dashboard template and run initial sync
  DASHBOARD_TEMPLATE="$SCRIPT_DIR/../templates/vault/Dashboard/dashboard-template.html"
  DASHBOARD_FILE="$VAULT_PROJECT/$PROJECT Dashboard.html"
  if [ -f "$DASHBOARD_TEMPLATE" ]; then
    cp "$DASHBOARD_TEMPLATE" "$DASHBOARD_FILE"
    python3 "$SCRIPT_DIR/sync-dashboard.py" "$VAULT_PROJECT" --quiet 2>/dev/null \
      && echo "✅  Dashboard created: $PROJECT Dashboard.html" \
      || echo "⚠️  Dashboard created (sync skipped — run open-dashboard to activate)"

    # Create .command launcher for Finder double-click
    COMMAND_FILE="$VAULT_PROJECT/Open Dashboard.command"
    cat > "$COMMAND_FILE" <<CMDEOF
#!/bin/zsh
source "\$HOME/.zshrc" 2>/dev/null || true
open-dashboard "$PROJECT"
CMDEOF
    chmod +x "$COMMAND_FILE"
    echo "✅  Launcher created: Open Dashboard.command"
  fi
fi

# 2. Create repo if it doesn't exist
if [ -d "$REPO_PATH" ]; then
  echo "⚠️  Repo already exists: $REPO_PATH"
else
  mkdir -p "$REPO_PATH"
  cd "$REPO_PATH"
  git init -q
  echo "✅  Repo initialised: $REPO_PATH"
fi

# 3. Link vault to repo
"$SCRIPT_DIR/link-project.sh" "$PROJECT"
