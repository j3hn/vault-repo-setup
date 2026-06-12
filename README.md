# Vault ↔ Repo Setup

One-time setup to link your Obsidian vault and Dev repos so they share the same project notes — no syncing, no duplication.

---

## How It Works

```
vault/Projects/flowforest/   ← notes live here (Obsidian sees this)
        _index.md
        tasks.md
        decisions.md
        progress.md
        research.md

Dev/flowforest/
        src/
        CONTEXT.md           ← AI agent brief (in repo)
        docs/  ──────────────symlink → vault/Projects/flowforest/
```

- `docs/` in your repo is a symlink to your vault project folder
- Same files, one source of truth
- Obsidian reads/writes them, your AI agent reads/writes them
- Git ignores `docs/` so vault notes never get committed

---

## One-Time Setup

### 1. Configure your paths

Open `scripts/link-project.sh` and set:

```bash
VAULT_ROOT="$HOME/path/to/your/vault"   # your Obsidian vault folder
DEV_ROOT="$HOME/path/to/your/Dev"       # your dev repos folder
```

Or set them as environment variables in your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export VAULT_ROOT="$HOME/Documents/MyVault"
export DEV_ROOT="$HOME/Dev"
```

### 2. Make scripts executable

```bash
chmod +x scripts/link-project.sh
chmod +x scripts/new-project.sh
```

### 3. Put the scripts somewhere accessible (optional)

To run them from anywhere:

```bash
mkdir -p ~/.local/bin
ln -s "$PWD/scripts/link-project.sh" ~/.local/bin/link-project
ln -s "$PWD/scripts/new-project.sh" ~/.local/bin/new-project
```

Then add to your shell profile if not already:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Daily Usage

### Starting a brand new project

```bash
new-project flowforest
# or with a client name
new-project acme-website "Acme Corp"
```

This will:
1. Create `vault/Projects/flowforest/` with all template files
2. Create `Dev/flowforest/` and `git init` it
3. Symlink `Dev/flowforest/docs/` → vault folder
4. Add `docs/` to `.gitignore`
5. Create `CONTEXT.md` in the repo

### Linking an existing project

If you already have the vault folder and repo:

```bash
link-project flowforest
```

### Setting up existing projects manually

For each existing project you want to link:

```bash
# From inside your repo
ln -s ~/path/to/vault/Projects/my-project ./docs
echo "docs/" >> .gitignore
```

---

## Vault Setup

Copy the contents of `templates/vault/` into your Obsidian vault root:

```
templates/vault/
├── Home.md                          → vault root
└── Projects/_example-project/      → use as a reference
        _index.md
        tasks.md
        decisions.md
        progress.md
        research.md
```

**Rename `_example-project`** to your first real project name, then duplicate the folder for each new project (or use the scripts above to do it automatically).

---

## For AI Agents (Claude Code etc.)

When starting a session in a repo, point your agent to:

- `CONTEXT.md` — project brief, stack, patterns, current sprint
- `docs/progress.md` — running log of what's been done
- `docs/tasks.md` — what's open

You can tell Claude Code to always load these by adding a `.claude/settings.json`:

```json
{
  "context_files": [
    "CONTEXT.md",
    "docs/progress.md",
    "docs/tasks.md"
  ]
}
```

---

## File Reference

| File | Where | Who uses it |
|------|-------|-------------|
| `_index.md` | vault + docs/ | You (Obsidian hub note) |
| `tasks.md` | vault + docs/ | You + AI agent |
| `decisions.md` | vault + docs/ | You + AI agent |
| `progress.md` | vault + docs/ | You + AI agent (append log) |
| `research.md` | vault + docs/ | You |
| `CONTEXT.md` | repo root only | AI agent (distilled brief) |

---

## Troubleshooting

**Obsidian isn't seeing the files**
Check your vault path is correct in the script. The symlink target must be inside or accessible from your vault root.

**Git is tracking docs/**
Make sure `docs/` is in your `.gitignore`. The script adds it automatically but double-check with `git status`.

**Symlink already exists warning**
The link is already set up — nothing to do.

**Files showing on wrong device / cloud sync issues**
If your vault is on iCloud or Dropbox and your Dev folder isn't, symlinks can behave unexpectedly. Keep both on the same drive or storage provider if possible.
