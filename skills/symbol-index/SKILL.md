---
name: symbol-index
description: Create or update the repository symbol index for key code artifacts (functions first, plus module exports and global assignments). Use after code changes in this repo to keep `SYMBOL_INDEX.md` current, especially when editing `fnl/`, `lua/`, or `plugin/`.
---

# Symbol Index

Update the repo symbol index with a deterministic script and run it after code edits.

## Workflow

1. Run the index updater.
From repo root:
```bash
./skills/symbol-index/scripts/update-symbol-index.py
```

2. Prefer running through a worker sub-agent after code changes.
Assign the worker to run the script and report what changed in `SYMBOL_INDEX.md`.

3. Verify output file changed as expected.
Check `SYMBOL_INDEX.md` and ensure major touched files/functions are represented.

## Script

- `scripts/update-symbol-index.py`
Scans `fnl/`, `lua/`, and `plugin/` and writes `SYMBOL_INDEX.md` with:
1. Functions
2. Module exports
3. Global assignments

The script is deterministic and sorted by file and line.
