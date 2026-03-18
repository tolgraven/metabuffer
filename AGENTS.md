# AGENTS

## Project Overview

- Project: `metabuffer` (Neovim plugin), Fennel-first port of `metabuffer.nvim` (Python remote plugin).
- Source of truth: `fnl/`.
- Generated runtime code committed to repo: `lua/` and `plugin/`.
- Main entrypoints:
  - `fnl/metabuffer/init.fnl` -> `lua/metabuffer/init.lua`
  - `fnl/plugin/metabuffer.fnl` -> `plugin/metabuffer.lua`
- Plugin commands exposed by setup include: `:Meta`, `:MetaResume`, `:MetaCursorWord`, `:MetaResumeCursorWord`, `:MetaSync`, `:MetaPush`.

## nfnl Setup (Current)

- Embedded namespaced nfnl runtime is vendored under:
  - `lua/metabuffer/nfnl/`
  - `fnl/metabuffer/nfnl/` (macros)
- Namespacing is `metabuffer.nfnl.*` to avoid global `nfnl.*` collisions.
- Project config file: `.nfnl.fnl`.
- `.nfnl.fnl` includes:
  - `:source-file-patterns ["fnl/**/*.fnl"]`
  - orphan ignore for embedded runtime `lua/metabuffer/nfnl/`
  - custom `:fnl-path->lua-path` mapping so:
    - `fnl/plugin/*.fnl` -> `plugin/*.lua`
    - `fnl/**/*.fnl` -> `lua/**/*.lua`

## Build / Maintenance Commands

- Embed or refresh bundled nfnl:
  - `./scripts/init-nfnl`
- Compile all Fennel through nfnl (headless Neovim):
  - `./scripts/compile-fennel.sh`
- Continuous source lint watch (for immediate paren/syntax failures):
  - `./scripts/watch-fennel.sh`
- Continuous lint + compile watch:
  - `./scripts/watch-fennel.sh --compile`
- Optional compile logging:
  - default: quiet (`NVIM_LOG_FILE` defaults to `/dev/null`)
  - debug: `NVIM_LOG_FILE=.nvimlog ./scripts/compile-fennel.sh`
- Run full test suite (screen + unit, parallel):
  - `./scripts/test-mini.sh`
- Run full suite with profiling output written under `/tmp`:
  - `./scripts/test-mini.sh --profile`
- Rerun single failing file quickly while iterating:
  - `./scripts/test-mini.sh tests/unit/test_query_unit.lua`
- Rerun only files that failed on previous run:
  - `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`
- Run screen tests against the real repo instead of the default generated fixture project:
  - `TEST_REAL_REPO=1 ./scripts/test-mini.sh`
- Enable UI animations in headless mini.test child sessions when needed:
  - `TEST_UI_ANIMATIONS=1 ./scripts/test-mini.sh`

## Important Session Notes

- The previous raw compiler flow (`fennel --compile`) was replaced with headless Neovim + `metabuffer.nfnl.api` compile flow.
- `scripts/compile-fennel.sh` must not delete `lua/`; deleting it removes vendored `lua/metabuffer/nfnl`.
- nfnl trust behavior in headless environments can block `.nfnl.fnl` (`vim.secure.read` untrusted); compile script includes a controlled local fallback reader for non-interactive compilation.
- `scripts/init-nfnl` was implemented to avoid dependency on `sd`/`fd` (uses standard shell tools + `perl`), because those were not available in this environment.

## Repo Hygiene

- `.ignore` excludes generated Lua from search tooling:
  - `lua/**/*.lua`
- `.gitattributes` marks generated/vendored Lua for Linguist:
  - `lua/**/*.lua linguist-generated`
  - `lua/metabuffer/nfnl/**/*.lua linguist-vendored`
- `.gitignore` includes local artifacts:
  - `.nvimlog`
  - `deps/`

## Caution Points

- If you rework compile tooling, keep compatibility with `plugin/metabuffer.lua` and `lua/` output paths.
- If vendored `nfnl` is refreshed, verify no plain `nfnl.*` namespace imports remain.
- This repository will later on commit compiled Lua so users do not need nfnl at runtime.
- Never ever commit on your own without first running the full test suite. Limited/targeted runs are preferable while you are working, but before handing back controls always ensure every single test passes.

## Fennel code style

- Mirror Clojure best practices as close as possible.
- Function arguments always on separate line (unless entire thing oneliner).
- Write (brief) docstrings for not immediately (from outside) self-descriptive functions and keep them up to date. Include expected output.
- Beware of tendency to try to call locally defined functions globally (through vim dispatch), ensure no __fnl_global__ related errors by using vars in these instances. Forward declaration issue due to Lua transpilation.
- Try keep functions below ~25 or at least ~40 lines. Try to use side-effecting helpers for nvim comms. If a function does many things within itself, something is wrong (unless it's an orchestration function simply calling many other smaller functions).

## Self-improvement

- When appropriate, update this file with new learnings, conventions, information, but make sure it is important enough, and ensure anything outdated is replaced rather than just countinously appending.
- Always update docs when new functionality is added or changed. Both README and vim docs should be comprehensive.
- When adding or renaming setup options, update README, `doc/metabuffer.txt`, and config unit tests in the same pass.
- Always update/extend tests when functionality changes:
  - unit tests under `tests/unit/` for pure logic and parser/matcher behavior.
  - screen/integration tests under `tests/screen/` for end-to-end prompt/router/window behavior.
  - screen tests default to a generated project fixture from `tests/screen/support/screen_helpers.lua`; only opt into full-repo coverage with `TEST_REAL_REPO=1`.
  - keep screen files grouped by dir (`context/`, `history/`, `matchers/`, `persistence/`, `project/`) and split any file trending above ~2-3s.
  - keep `tests/testing.md` synchronized with current test coverage and rerun workflows.
  - when multiple tests fail, use `.cache/metabuffer-tests/failed-files.txt` and parallel sub-agents (one per failing file) to investigate/fix in parallel, then run a full suite check.

## Agent behavior

- Never stop work unnecessarily. User should never have to simply type "go", unless you make an optional and unlikely suggestion. If you identify a clear bug or architectural issue and the next corrective step is obvious, implement it immediately instead of stopping at diagnosis.
- Do not hand control back just to describe what should be changed next when that change is local, concrete, and within scope. Fix it, then report the result.
- Prefer a single shared event source with independent listeners over one UI subsystem driving another. For example, selection changes should fan out to preview/info/context/status independently; one window module should not call another window module to keep it in sync.
- Features in `features` should always result in feature branches in git. Commit each step when doing that, without asking. Don't push unless asked. Other work can be done straight on mainline, and then you should defer committing until told.
- Try to avoid commands that need escalated permissions and hence user input (to confirm), since these disrupt work. Always see if there is an in-sandbox alternative.
- Since you lack full access to `~/.local/state/nvim`, always route ad hoc Neovim state through `/tmp` to avoid `shada`/state permission errors. For manual/headless runs, set `XDG_STATE_HOME=/tmp`, `XDG_DATA_HOME=/tmp`, `XDG_CACHE_HOME=/tmp`, and if needed `NVIM_APPNAME` to a tmp-specific value instead of touching the real local state dirs.
- Remember `fennel-ls` should be run directly after any file edit.
- Fix `fennel-ls` warnings you encounter while working, not just hard errors. Keep those cleanup fixes as their own commits when they are distinct from the feature change.

## Symbol Index

- After major code changes (new functions or other global symbols), update `SYMBOL_INDEX.md` by running `./skills/symbol-index/scripts/update-symbol-index.py`.
- Prefer using a worker sub-agent to run this update step and report what changed.
- Keep this file in context to avoid unecessary slow lookups.

## Feature files.

- In the folder features/ we describe upcoming (branched) features in individual files. When told, and only then, use the relevant file as basis for feature implementation. Always check out a new branch for these, commit each step individually, and make a PR (right away, but user will merge manually when finished). Don't push unless asked to.
- The folder also has a running-todo.md describing minor fixes to be done, and then checked off (only when I say it works). Only work on them when told.

## General workflow

- When making changes, run `fennel-ls` to check for issues. Once that is ok, run `scripts/compile-fennel.sh`. If that is ok, run unit and integration tests. Only once all these are clear should you return to user.
- Treat a successful compile, targeted repro, or targeted test as a checkpoint, not an excuse to stop. Keep going until the full requested fix is implemented end-to-end unless the user must choose between materially different paths.
