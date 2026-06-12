#!/usr/bin/env python3
"""
sync-dashboard.py — reads structured markdown from a vault project folder
and updates its *Dashboard.html JSON block.

Usage:
    sync-dashboard.py <vault-project-path> [--quiet]
"""

import sys, os, re, json
from datetime import date as _date


# ── Minimal YAML frontmatter parser (no external deps) ──────────────────────

def _unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] in '"\'': return v[1:-1]
    if v in ('null', '~', ''):        return None
    if v == 'true':                    return True
    if v == 'false':                   return False
    return v

def parse_frontmatter(text):
    m = re.match(r'^---[ \t]*\n(.*?)\n---[ \t]*\n', text, re.DOTALL)
    if not m:
        return {}, text
    block, rest = m.group(1), text[m.end():]
    lines  = block.split('\n')
    result = {}
    i = 0
    while i < len(lines):
        km = re.match(r'^([\w-]+):\s*(.*)', lines[i])
        if not km:
            i += 1; continue
        key, val = km.group(1), km.group(2).strip()
        if val in ('', '[]'):
            items, j = [], i + 1
            while j < len(lines):
                lm = re.match(r'^  -\s+(.*)', lines[j])
                if not lm: break
                hm = re.match(r'^([\w-]+):\s*(.*)', lm.group(1).strip())
                if hm:
                    item = {hm.group(1): _unquote(hm.group(2))}
                    j += 1
                    while j < len(lines):
                        fm = re.match(r'^    ([\w-]+):\s*(.*)', lines[j])
                        if not fm: break
                        item[fm.group(1)] = _unquote(fm.group(2))
                        j += 1
                    items.append(item)
                else:
                    items.append(_unquote(lm.group(1)))
                    j += 1
            result[key] = items
            i = j
        else:
            result[key] = _unquote(val)
            i += 1
    return result, rest


# ── Markdown parsers ─────────────────────────────────────────────────────────

def parse_tasks(text):
    tasks, tid = [], 0
    for line in text.split('\n'):
        m = re.match(r'\s*-\s+\[( |x|X|-)\]\s+(.*)', line)
        if not m: continue
        mark, body = m.group(1).lower(), m.group(2)
        status = 'done' if mark == 'x' else 'blocked' if mark == '-' else 'todo'

        stream = priority = due = note = None
        sm = re.search(r'#stream:([\w-]+)', body)
        if sm: stream = sm.group(1); body = body.replace(sm.group(0), '')
        pm = re.search(r'#(critical|high|med|low)\b', body)
        if pm: priority = pm.group(1); body = body.replace(pm.group(0), '')
        dm = re.search(r'#due:([\d-]+)', body)
        if dm: due = dm.group(1); body = body.replace(dm.group(0), '')
        nm = re.search(r'::\s*(.*)', body)
        if nm: note = nm.group(1).strip(); body = body[:nm.start()]

        title = re.sub(r'\s+', ' ', body).strip().rstrip('#').strip()
        if not title: continue

        tid += 1
        t = {'id': f't{tid}', 'title': title, 'status': status, 'priority': priority or 'med'}
        if stream:   t['stream'] = stream
        if due:      t['due']    = due
        if note:     t['note']   = note
        tasks.append(t)
    return tasks


def parse_decisions(text):
    decisions = []
    pat = re.compile(
        r'###\s+(\d{4}-\d{2}-\d{2})\s*[—–-]+\s*(.*?)(?:\s*\[([\w-]+)\])?\s*\n(.*?)(?=\n###|\Z)',
        re.DOTALL)
    for m in pat.finditer(text):
        dt, title, stream, body = m.group(1), m.group(2).strip(), m.group(3), m.group(4)
        dm = re.search(r'\*\*Decision:\*\*\s*(.*)', body)
        detail = dm.group(1).strip() if dm else None
        entry  = {'date': dt, 'title': title}
        if stream: entry['stream'] = stream
        if detail: entry['detail'] = detail
        decisions.append(entry)
    return sorted(decisions, key=lambda x: x['date'], reverse=True)


def parse_sessions(text):
    sessions = []
    pat   = re.compile(
        r'###\s+(\d{4}-\d{2}-\d{2})(?:\s*[—–-]+\s*(.*?))?\s*\n(.*?)(?=\n###|\Z)',
        re.DOTALL)
    today = str(_date.today())
    for i, m in enumerate(pat.finditer(text)):
        dt, title, body = m.group(1), (m.group(2) or '').strip(), m.group(3)
        produced = [l[2:].strip() for l in body.split('\n') if l.strip().startswith('- ')]
        summary  = ' '.join(l.strip() for l in body.split('\n')
                            if l.strip() and not l.strip().startswith('- ')).strip()
        sessions.append({
            'id':       f's{i+1}',
            'date':     dt,
            'title':    title or f'Session {dt}',
            'status':   'active' if dt == today else 'closed',
            'summary':  summary,
            'produced': produced,
        })
    sessions.sort(key=lambda x: x['date'], reverse=True)
    return sessions


# ── HTML updater ─────────────────────────────────────────────────────────────

def update_html(html_path, data):
    with open(html_path) as f:
        html = f.read()
    pat = re.compile(
        r'(<script[^>]+id="dash-data"[^>]*>)\s*\{.*?\}\s*(</script>)',
        re.DOTALL)
    if not pat.search(html):
        return False, 'dash-data block not found'
    replacement = r'\1\n' + json.dumps(data, indent=2, ensure_ascii=False) + r'\n\2'
    with open(html_path, 'w') as f:
        f.write(pat.sub(replacement, html))
    return True, None


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        sys.exit('Usage: sync-dashboard.py <vault-project-path> [--quiet]')

    project_dir = os.path.realpath(os.path.expanduser(sys.argv[1]))
    quiet       = '--quiet' in sys.argv

    if not os.path.isdir(project_dir):
        sys.exit(f'Not a directory: {project_dir}')

    html_files = sorted(f for f in os.listdir(project_dir) if f.endswith('Dashboard.html'))
    if not html_files:
        sys.exit(f'No *Dashboard.html in {project_dir}')
    html_path = os.path.join(project_dir, html_files[0])

    def read(fname):
        p = os.path.join(project_dir, fname)
        return open(p).read() if os.path.exists(p) else ''

    fm, _     = parse_frontmatter(read('_index.md'))
    tasks     = parse_tasks(read('tasks.md'))
    decisions = parse_decisions(read('decisions.md'))
    sessions  = parse_sessions(read('progress.md'))
    today     = str(_date.today())

    data = {
        'meta': {
            'title':      fm.get('title') or os.path.basename(project_dir),
            'subtitle':   fm.get('subtitle') or '',
            'updated':    today,
            'today_note': 'Day counters compute from your clock against the absolute dates shown.',
        },
        'deadlines': fm.get('deadlines') or [],
        'streams':   fm.get('streams')   or [],
        'reference': fm.get('reference') or [],
        'tasks':     tasks,
        'decisions': decisions,
        'sessions':  sessions,
        'documents': fm.get('documents') or [],
        'paths': {
            'vault': project_dir,
            'repo':  os.path.expanduser(fm.get('repo') or ''),
        },
        'protocol': [
            'Edit the markdown files in this folder — not the JSON in this HTML.',
            'tasks.md — checkboxes with optional tags: #stream:id  #high  #due:YYYY-MM-DD  :: note text',
            'decisions.md — ### YYYY-MM-DD — Title [stream-id]  then  **Decision:** …',
            'progress.md — ### YYYY-MM-DD — Session title  then bullet points for what was done',
            '_index.md frontmatter — streams[], deadlines[], reference[], documents[]',
        ],
    }

    ok, err = update_html(html_path, data)
    if not ok:
        sys.exit(f'Error: {err}')
    if not quiet:
        print(f'✅  Synced → {os.path.basename(html_path)}')

if __name__ == '__main__':
    main()
