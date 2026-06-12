---
title: DASHBOARD
type: convention
tags:
  - dashboard
  - convention
  - templates
aliases:
  - Project Dashboard Convention
  - Dashboard Spec
---

# Project Dashboard — a reusable convention

A **project dashboard** is one self-contained HTML file that gives a single, always-current overview of a project or matter: deadlines, workstreams, outstanding and completed tasks, a history of decisions, the sessions worked, and links to key documents. It exists because work spread across many sessions is hard to keep bearings on; the dashboard is the one place to oversee everything.

It is deliberately low-tech: **no server, no build step, no dependencies.** Open the `.html` straight from disk (double-click in Dropbox / Finder) and it renders. All the project data lives in a single JSON block inside the file; editing that block is the only thing needed to keep it current.

## Files in this folder

| File | Purpose |
| --- | --- |
| `DASHBOARD.md` | This spec: schema, protocol, how to add a dashboard to a project. |
| `dashboard-template.html` | The renderer + an empty example. Copy this into any project to start one. |

The first live instance is `Projects/Coast/Coast Dashboard.html`.

## Add a dashboard to a project

1. Copy `dashboard-template.html` into the project folder and rename it `<Project> Dashboard.html` (e.g. `Coast Dashboard.html`).
2. Open it and edit only the `<script type="application/json" id="dash-data">` block: set `meta.title`, then fill `streams`, `tasks`, `deadlines`, etc. Delete the example entries.
3. Save. Open the file in a browser to confirm it renders. Done.

The renderer never needs editing. Title, sections, counts, day-counters, and filters all come from the data. Any section with no data hides itself.

## Data schema (the `dash-data` JSON block)

```
meta        { title, subtitle, updated (YYYY-MM-DD), today_note }
deadlines[] { date (YYYY-MM-DD), label, severity: "crit"|"warn"|"normal" }
streams[]   { id, name, color (#hex), status, statusColor (#hex), summary, next }
reference[] { k, v }                              // quick-reference key/value facts
tasks[]     { id, title, status, stream, priority, due?, note? }
              status:   "todo" | "doing" | "done" | "blocked"
              priority: "critical" | "high" | "med" | "low"
              stream:   an id from streams[]
decisions[] { date, stream?, title, detail? }     // activity & decisions log, newest shown first
sessions[]  { id, date, title, status, summary, produced[] }
              status: "active" | "closed" | "archived"
documents[] { label, path (relative to the html file), note? }
protocol[]  [ "string", ... ]                      // shown in the maintenance panel; may contain inline HTML
```

Notes:
- `streams` are the parallel workstreams / fronts of the project (the Coast instance uses the legacy key `fronts`; the renderer accepts either, plus `reference`/`facts` and `decisions`/`log`).
- `color` / `statusColor` are plain hex strings so each project picks its own palette.
- `due` on a task and all `deadlines` show a live "in N days / passed" computed from the viewer's clock; the absolute date is always shown too.
- Keep the JSON valid: double quotes, no trailing commas, no `</script>` inside any string. Invalid JSON shows an error banner instead of rendering.

## Session protocol (how it stays current)

The dashboard is only useful if it is updated as work happens. Each working session:

1. **Start** — read the dashboard; add a `sessions` entry with `status: "active"`. Only one session is `active` at a time. If a previous one was left `active`, close it first.
2. **During** — log decisions/activity to `decisions` (newest first); move `tasks` through `todo` → `doing` → `done` (or `blocked`); add tasks as they arise; update `streams[].status`/`next`.
3. **End** — set the session's `status` to `"closed"`, fill its `produced` list, bump `meta.updated`, and refresh `deadlines`.
4. Older sessions become `archived`; keep the latest few in detail.

This protocol is also embedded in each dashboard's "How this dashboard is maintained" panel, so the file is self-documenting even away from this spec.

## For automated/agent sessions

When working in a project that has a `* Dashboard.html`, treat maintaining it as part of the session. When a project would clearly benefit from one and has none, offer to create it from `dashboard-template.html`. (For Claude: this is also captured as a memory rule so it carries across sessions.)
