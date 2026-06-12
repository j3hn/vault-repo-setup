#!/bin/bash

# ============================================================
# link-project.sh
# Links an Obsidian project folder into a repo as docs/
# ============================================================
# Usage:
#   ./link-project.sh <project-name>
#
# Example:
#   ./link-project.sh flowforest
#
# Assumes:
#   - Your vault is at $VAULT_ROOT (set below or as env var)
#   - Your repos are at $DEV_ROOT (set below or as env var)
#   - Project folder exists in vault at $VAULT_ROOT/Projects/<name>
#   - Repo exists at $DEV_ROOT/<name>
# ============================================================

# --- CONFIGURE THESE ---
VAULT_ROOT="${VAULT_ROOT:-$HOME/vault}"       # path to your Obsidian vault
DEV_ROOT="${DEV_ROOT:-$HOME/Dev}"             # path to your dev folder
DOCS_FOLDER="docs"                            # name of the folder inside the repo
# -----------------------

PROJECT="$1"
_SCRIPT="${BASH_SOURCE[0]}"
[ -L "$_SCRIPT" ] && _SCRIPT="$(readlink "$_SCRIPT")"
SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"

if [ -z "$PROJECT" ]; then
  echo "❌  Usage: ./link-project.sh <project-name>"
  exit 1
fi

VAULT_PROJECT="$VAULT_ROOT/Projects/$PROJECT"
REPO_PATH="$DEV_ROOT/$PROJECT"
LINK_PATH="$REPO_PATH/$DOCS_FOLDER"

# Check vault project folder exists
if [ ! -d "$VAULT_PROJECT" ]; then
  echo "⚠️  Vault project folder not found: $VAULT_PROJECT"
  read -p "   Create it now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$VAULT_PROJECT"
    echo "✅  Created $VAULT_PROJECT"
    # Copy templates in

    TEMPLATE_DIR="$SCRIPT_DIR/../templates/vault/Projects/_example-project"
    if [ -d "$TEMPLATE_DIR" ]; then
      cp "$TEMPLATE_DIR"/*.md "$VAULT_PROJECT/"
      # Replace placeholder name in files
      sed -i.bak "s/PROJECT_NAME/$PROJECT/g" "$VAULT_PROJECT"/*.md
      rm -f "$VAULT_PROJECT"/*.bak
      echo "✅  Templates copied and named for $PROJECT"
    fi
  else
    echo "   Aborted. Create the vault project folder first."
    exit 1
  fi
fi

# Check repo exists
if [ ! -d "$REPO_PATH" ]; then
  echo "❌  Repo not found: $REPO_PATH"
  exit 1
fi

# Check if docs/ already exists
if [ -e "$LINK_PATH" ]; then
  if [ -L "$LINK_PATH" ]; then
    echo "⚠️  $LINK_PATH is already a symlink. Skipping."
  else
    echo "⚠️  $LINK_PATH already exists as a real folder."
    echo "   Move or rename it first, then re-run."
  fi
  exit 0
fi

# Create the symlink
ln -s "$VAULT_PROJECT" "$LINK_PATH"
echo "✅  Linked: $LINK_PATH → $VAULT_PROJECT"

# Add docs/ to .gitignore if not already there
GITIGNORE="$REPO_PATH/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if grep -q "^$DOCS_FOLDER" "$GITIGNORE"; then
    echo "✅  .gitignore already has $DOCS_FOLDER/"
  else
    echo "" >> "$GITIGNORE"
    echo "# Obsidian project notes (symlinked from vault)" >> "$GITIGNORE"
    echo "$DOCS_FOLDER/" >> "$GITIGNORE"
    echo "✅  Added $DOCS_FOLDER/ to .gitignore"
  fi
else
  echo "# Obsidian project notes (symlinked from vault)" > "$GITIGNORE"
  echo "$DOCS_FOLDER/" >> "$GITIGNORE"
  echo "✅  Created .gitignore with $DOCS_FOLDER/"
fi

# Copy CLAUDE.md template into repo root if not present
CLAUDE_FILE="$REPO_PATH/CLAUDE.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_TEMPLATE="$SCRIPT_DIR/../templates/repo/CLAUDE.md"
if [ ! -f "$CLAUDE_FILE" ] && [ -f "$CLAUDE_TEMPLATE" ]; then
  cp "$CLAUDE_TEMPLATE" "$CLAUDE_FILE"
  sed -i.bak "s/PROJECT_NAME/$PROJECT/g" "$CLAUDE_FILE"
  rm -f "$CLAUDE_FILE.bak"
  echo "✅  Created CLAUDE.md in repo"
fi

echo ""
echo "🎉  Done! Project $PROJECT is linked."
echo ""
echo "   Vault notes:  $VAULT_PROJECT"
echo "   Repo docs/:   $LINK_PATH  (symlink)"
echo "   CLAUDE.md:   $CLAUDE_FILE"
echo ""
echo "   Next: update CLAUDE.md with your project brief."
