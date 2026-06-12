# 🏠 Home

## Active Projects

```dataview
TABLE status, file.mtime as "Updated", repo as "Repo"
FROM "Projects"
WHERE status = "active"
SORT file.mtime DESC
```

## Open Tasks (All Projects)

```tasks
not done
path includes Projects
```

## Recently Modified

```dataview
LIST
FROM "Projects" OR "Areas"
SORT file.mtime DESC
LIMIT 8
```
