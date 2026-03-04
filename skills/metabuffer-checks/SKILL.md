---
name: metabuffer-checks
description: Run the metabuffer plugin quality checks (lint, Fennel compile, and smoke test). Use when working in this repository and you need a fast verification pass before or after edits, or while debugging regressions.
---

# Metabuffer Checks

Run the project checks in a fixed order and report failures with the failing step and key error lines.

## Workflow

1. Determine the target project directory.
Use the provided path if the user gives one.
If no path is given, default to `/Users/tol/CODE/VIM/LISTA/metabuffer/metabuffer`.

2. Initialize Python environment when using `quick_validate.py`.
From repo root, run:
```bash
source ./skills/metabuffer-checks/scripts/init-venv.sh
```
This creates `skills/metabuffer-checks/.venv`, activates it, and installs required Python packages (`PyYAML` plus pip tooling updates).

3. Run the bundled script.
From any directory, run:
```bash
./skills/metabuffer-checks/scripts/run-checks.sh [optional-project-dir]
```
Options:
```bash
./skills/metabuffer-checks/scripts/run-checks.sh --with-headless
./skills/metabuffer-checks/scripts/run-checks.sh --profile
```

4. Report results concisely.
If all steps pass, report success for `lint`, `compile`, and `smoke`.
If a step fails, stop and report:
- failing step
- command run
- most relevant error lines

## Script

- `scripts/run-checks.sh`
Runs these commands in order inside the target project:
1. `./scripts/watch-fennel.sh --once`
2. `./scripts/compile-fennel.sh`
3. `./scripts/smoke-meta.sh`
Optional:
4. `--with-headless`: run headless `nvim` startup plus `Meta` and `Meta!` invocation checks
5. `--profile`: write startup and Meta timing profiles to `.cache/metabuffer-checks/`

- `scripts/init-venv.sh`
Creates and activates a skill-local Python venv and installs `PyYAML` so `quick_validate.py` works.

Do not skip steps unless the user explicitly asks.
