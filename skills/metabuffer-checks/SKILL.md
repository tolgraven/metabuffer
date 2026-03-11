---
name: metabuffer-checks
description: Run the metabuffer plugin quality checks (lint, Fennel compile, smoke test, and mini test suites). Use when working in this repository and you need a fast verification pass before or after edits, or while debugging regressions.
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
./skills/metabuffer-checks/scripts/run-checks.sh --failed-tests-only
```

4. Report results concisely.
If all steps pass, report success for `lint`, `compile`, `smoke`, and `tests`.
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
4. `./scripts/test-mini.sh` (runs unit + screen suites in parallel)
Optional:
5. `--with-headless`: run headless `nvim` startup plus `Meta` and `Meta!` invocation checks
6. `--profile`: write startup and Meta timing profiles to `.cache/metabuffer-checks/`
7. `--failed-tests-only`: run only previously failing tests via `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`

- `scripts/init-venv.sh`
Creates and activates a skill-local Python venv and installs `PyYAML` so `quick_validate.py` works.

Do not skip steps unless the user explicitly asks.

## Fast test reruns

When tests fail, use one of:
- `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`
- `TEST_ONLY='tests/unit/test_query_unit.lua' ./scripts/test-mini.sh`

The failed test list is stored at:
- `.cache/metabuffer-tests/failed-files.txt`
