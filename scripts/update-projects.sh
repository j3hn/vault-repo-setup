#!/bin/bash

# ============================================================
# update-projects.sh
# Updates all existing projects with the latest dashboard
# template and regenerates their .command files.
# Run this after pulling changes to vault-repo-setup.
# ============================================================
# Usage:
#   update-projects [--dry-run]
# ============================================================

_SCRIPT="${BASH_SOURCE[0]}"
[ -L "$_SCRIPT" ] && _SCRIPT="$(readlink "$_SCRIPT")"
SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT")" && pwd)"

VAULT_ROOT="${VAULT_ROOT:-$HOME/vault}"
PROJECTS_DIR="$VAULT_ROOT/Projects"
DASHBOARD_TEMPLATE="$SCRIPT_DIR/../templates/vault/Dashboard/dashboard-template.html"
DRY_RUN=0
[ "$1" = "--dry-run" ] && DRY_RUN=1

if [ ! -d "$PROJECTS_DIR" ]; then
    echo "❌  Projects directory not found: $PROJECTS_DIR"
    exit 1
fi

if [ ! -f "$DASHBOARD_TEMPLATE" ]; then
    echo "❌  Dashboard template not found: $DASHBOARD_TEMPLATE"
    exit 1
fi

UPDATED=0
SKIPPED=0

echo "🔄  Scanning $PROJECTS_DIR..."
echo ""

for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue
    project=$(basename "$project_dir")

    # Skip template/hidden folders
    [[ "$project" == _* ]] && continue

    # Only update projects that already have a dashboard
    html_file=$(find "$project_dir" -maxdepth 1 -name "*Dashboard.html" 2>/dev/null | head -1)
    if [ -z "$html_file" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
        echo "   (dry-run) would update: $project"
        UPDATED=$((UPDATED + 1))
        continue
    fi

    # Re-copy dashboard HTML template (preserves filename)
    cp "$DASHBOARD_TEMPLATE" "$html_file"

    # Re-sync JSON from markdown files
    python3 "$SCRIPT_DIR/sync-dashboard.py" "$project_dir" --quiet

    # Regenerate .command file
    command_file="${project_dir}Open Dashboard.command"
    cat > "$command_file" <<CMDEOF
#!/bin/zsh
source "\$HOME/.zshrc" 2>/dev/null || true
open-dashboard "$project"
CMDEOF
    chmod +x "$command_file"

    echo "✅  $project"
    UPDATED=$((UPDATED + 1))
done

echo ""
if [ "$DRY_RUN" = "1" ]; then
    echo "   Dry run — $UPDATED project(s) would be updated, $SKIPPED skipped (no dashboard)."
else
    echo "   $UPDATED project(s) updated, $SKIPPED skipped (no dashboard)."
fi
