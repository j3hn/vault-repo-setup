# Vault ↔ Repo Setup

Two shell scripts that wire a new project together in one command: a git repo in your dev folder, a matching notes folder in your Obsidian vault, a `docs/` symlink that connects them, and a live HTML dashboard that reads from those notes automatically. The same files are visible in Obsidian, your editor, and the dashboard — one source of truth, no syncing, no duplication.

---

## How It Works

```
vault/Projects/flowforest/
        _index.md            ← project meta, streams, deadlines (frontmatter)
        tasks.md             ← tagged checkboxes
        decisions.md         ← date-headed decision log
        progress.md          ← session log
        research.md          ← free-form notes
        flowforest Dashboard.html  ← auto-generated from the files above

dev/flowforest/
        src/
        CLAUDE.md           ← AI agent brief (in repo)
        docs/  ──────────────symlink → vault/Projects/flowforest/
```

- `docs/` in your repo is a symlink to your vault project folder — same files, everywhere
- The dashboard HTML reads the markdown files and updates live as you edit them
- Git ignores `docs/` so vault notes never get committed

---

## One-Time Setup

### 1. Install prerequisites

```bash
brew install fswatch
pnpm add -g browser-sync
```

### 2. Set your paths

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export VAULT_ROOT="$HOME/path/to/your/vault"
export DEV_ROOT="$HOME/path/to/your/dev"
export PATH="$HOME/.local/bin:$PATH"
```

### 3. Symlink the scripts

From inside this repo:

```bash
mkdir -p ~/.local/bin
ln -s "$PWD/scripts/new-project.sh"    ~/.local/bin/new-project
ln -s "$PWD/scripts/link-project.sh"   ~/.local/bin/link-project
ln -s "$PWD/scripts/open-dashboard.sh"  ~/.local/bin/open-dashboard
ln -s "$PWD/scripts/update-projects.sh" ~/.local/bin/update-projects
```

### 4. Install the git hook

This makes `git pull` automatically propagate dashboard changes to all your existing projects:

```bash
ln -s "$PWD/hooks/post-merge" .git/hooks/post-merge
```

### 5. Copy vault templates

Copy `templates/vault/` into your Obsidian vault root. The `Dashboard/` folder holds the dashboard spec and renderer; `Projects/_example-project/` is the per-project template.

---

## Daily Usage

### Start a new project

```bash
new-project flowforest
# or with a client name
new-project acme-website "Acme Corp"
```

This creates:
1. `vault/Projects/flowforest/` with all template files + dashboard HTML
2. `Open Dashboard.command` alongside the HTML — double-click in Finder to launch
3. `dev/flowforest/` with `git init`
4. `dev/flowforest/docs/` → symlink to the vault folder
5. `docs/` added to `.gitignore`
6. `CLAUDE.md` in the repo root

### Open the live dashboard

Two ways to launch — pick whichever fits the moment:

**From Finder:** double-click `Open Dashboard.command` in the vault project folder. Terminal opens, everything starts, close the browser tab to stop.

**From the terminal:**
```bash
open-dashboard flowforest
```

Either way: a local server and file watcher start, the dashboard opens in your browser, and everything shuts down 15 seconds after you close the tab. Any save to a markdown file syncs to the dashboard automatically.

### Link an existing project

If you already have both the vault folder and the repo:

```bash
link-project flowforest
```

---

## Dashboard — how data maps to markdown

The dashboard reads four files. Edit them normally in Obsidian or any editor.

### `_index.md` — project meta, streams, deadlines

Structured YAML frontmatter. This is the only file you need to set up manually when starting a project.

```yaml
---
title: flowforest
subtitle: Generative music app
status: active
streams:
  - id: build
    name: Build
    color: "#4cc9f0"
    status: In progress
    statusColor: "#3b9ae1"
    summary: Core audio engine
    next: Add MIDI export
  - id: design
    name: Design
    color: "#f72585"
    status: Not started
    statusColor: "#e0a32e"
    summary: ""
    next: ""
deadlines:
  - date: 2026-08-01
    label: Beta launch
    severity: warn
reference:
  - k: Repo
    v: ~/dev/flowforest
  - k: Stack
    v: Electron, Web Audio API
documents: []
---
```

### `tasks.md` — task board

Plain checkboxes with optional tags. All checkboxes in the file are picked up regardless of heading.

```markdown
- [ ] Add MIDI export #stream:build #high #due:2026-07-15
- [ ] Design onboarding flow #stream:design #med
- [-] Fix audio glitch on M1 #stream:build #high :: blocked on upstream bug
- [x] Set up repo #stream:build
```

| Tag | Values |
|-----|--------|
| `#stream:id` | matches a stream `id` from `_index.md` |
| `#high` / `#med` / `#low` / `#critical` | priority |
| `#due:YYYY-MM-DD` | due date |
| `:: note text` | shown as a task note |
| `[-]` | blocked status |
| `[x]` | done |

### `decisions.md` — activity log

```markdown
### 2026-06-12 — Use Web Audio API over Tone.js [build]
**Decision:** Web Audio API directly — more control, no abstraction overhead.
**Reason:** Tone.js added 200 KB and we don't need its sequencer.
**Trade-offs:** More boilerplate for basic oscillator setup.
```

Format: `### YYYY-MM-DD — Title [stream-id]` followed by freeform body. The `[stream-id]` is optional. The `**Decision:**` line is pulled as the detail text in the dashboard.

### `progress.md` — session log

```markdown
### 2026-06-12 — First build session
- Set up Electron boilerplate
- Wired Web Audio context to main process
- Confirmed audio output on macOS and Windows
```

Format: `### YYYY-MM-DD — Session title` followed by bullet points. Each entry becomes a session card in the dashboard. Today's entry is marked active.

---

## For AI Agents (Claude Code etc.)

Add a `CLAUDE.md` at the repo root:

```markdown
Read these files at the start of every session:
- CLAUDE.md — project brief and current sprint
- docs/progress.md — running log of what's been done
- docs/tasks.md — open tasks
```

---

## File Reference

| File | Location | Purpose |
|------|----------|---------|
| `_index.md` | vault + `docs/` | Project hub. Frontmatter drives the dashboard (streams, deadlines, reference). |
| `tasks.md` | vault + `docs/` | Task board. Tagged checkboxes → dashboard task list. |
| `decisions.md` | vault + `docs/` | Decision log → dashboard activity timeline. |
| `progress.md` | vault + `docs/` | Session log → dashboard sessions panel. |
| `research.md` | vault + `docs/` | Free-form notes. Not synced to dashboard. |
| `*Dashboard.html` | vault project folder | Auto-generated. Open via `open-dashboard`, not by hand. |
| `CLAUDE.md` | repo root | AI agent brief. Not in vault, not synced to dashboard. |

---

## Keeping projects up to date

When you pull changes to this repo (new dashboard features, bug fixes), run:

```bash
update-projects
```

This re-copies the dashboard HTML renderer to every existing project and re-syncs their JSON from markdown. Your markdown files are never touched. If you installed the git hook in setup step 4, this runs automatically after every `git pull`.

To preview what would change without touching anything:

```bash
update-projects --dry-run
```

---

## Troubleshooting

**Dashboard shows old data after editing**
The watcher only runs while `open-dashboard` is active. If you edited files outside a session, run `open-dashboard` and it will sync on start.

**`open-dashboard` exits immediately**
Check that `browser-sync` and `fswatch` are installed (`which browser-sync`, `which fswatch`).

**Obsidian isn't seeing the files**
Check your `VAULT_ROOT` path. The symlink target must be inside your vault root.

**Git is tracking `docs/`**
Make sure `docs/` is in `.gitignore`. The script adds it automatically — check with `git status`.

**Symlink already exists warning**
The link is already set up — nothing to do.

**Cloud sync issues (iCloud / Dropbox)**
If your vault and dev folder are on different storage providers, symlinks can behave unexpectedly. Keep both on the same drive.
