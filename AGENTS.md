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

**Always use `make` targets, never the underlying scripts directly.** The Makefile sets `XDG_STATE_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `NVIM_APPNAME` automatically so headless Neovim runs stay sandboxed.

- Compile all Fennel → Lua:
  - `make` (or `make compile`)
- Lint Fennel + Lua:
  - `make check` (both), `make check-fnl` (fennel-ls only), `make check-lua` (lua-language-server only)
  - Lint a single file: `make check-fnl -- fnl/metabuffer/window/info.fnl`
- Run full test suite (compiles first, screen + unit, parallel):
  - `make test`
- Run a single test file:
  - `make test -- tests/unit/test_query_unit.lua`
- Run a targeted file first, then the full suite:
  - `make test-then-all -- tests/screen/project/test_screen_project_cross_file_search.lua`
- Run full suite with profiling output under `/tmp`:
  - `make test-profile`
- Rerun only files that failed on the previous run:
  - `TEST_FAILED_ONLY=1 make test`
- Run screen tests against the real repo instead of the generated fixture:
  - `TEST_REAL_REPO=1 make test`
- Enable UI animations in headless child sessions:
  - `TEST_UI_ANIMATIONS=1 make test`
- Embed or refresh bundled nfnl:
  - `./scripts/init-nfnl`
- Continuous source lint watch (immediate paren/syntax failures):
  - `./scripts/watch-fennel.sh`
- Continuous lint + compile watch:
  - `./scripts/watch-fennel.sh --compile`
- Optional compile logging:
  - default: quiet (`NVIM_LOG_FILE` defaults to `/dev/null`)
  - debug: `NVIM_LOG_FILE=.nvimlog make compile`

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
- Imports: `import-macros` at file top for cljlib macros, then `(local foo (require :metabuffer.foo))` for modules. Optional deps use `(pcall require :mod)`.
- Naming: kebab-case everywhere. Predicates end with `?` (e.g. `active-token?`). Side-effecting functions end with `!` (e.g. `apply-prompt-lines!`).
- Mutation: use `set` only for session/module state and table fields. Pure helpers compute and return without `set`. Name distinction (`!` suffix) makes intent clear.
- Error handling: wrap Neovim API and optional requires with `pcall`. Use `xpcall` + `debug.traceback` for startup orchestration steps that need context on failure. Prefer cljlib macros (`when-let`, `if-let`, `when-some`, `if-some`) for conditional bindings over nested nil checks.
- Module exports: most modules create `(local M {})`, attach functions to `M`, and return `M` at end of file. Index modules return a literal map of requires (e.g. `window/init.fnl`). Some modules build a local `api` map and return it.

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
  - test runs must not leave orphaned or spinning `nvim` processes behind; if a test run hangs or times out, immediately kill the leaked child Neovims before continuing.

## Writing Tests

- Framework: `mini.test` (from mini.nvim). All child processes boot with `-u tests/minimal_init.lua`.
- Unit tests (`tests/unit/test_*.lua`): require modules directly, call pure functions, assert with `MiniTest.expect.equality`. Use `MiniTest.new_set()`, define `T['description'] = function() ... end`, return `T`. Mutate `vim.g` or module config in tests but always restore afterwards.
- Screen tests (`tests/screen/**/test_*.lua`): control a child Neovim via `MiniTest.new_child_neovim()`. Use the helper module:
  - `local H = require('tests.screen.support.screen_helpers')`
  - Hooks: `H.case_hooks()` (fresh child per case), `H.shared_child_hooks()` (shared child per file), `H.batch_child_hooks()` (shared across batch).
  - Launch: `H.open_meta_with_lines({...})` for regular mode, `H.open_fixture_file(path)` / `H.open_project_meta_from_file(path)` for project mode.
  - Input: `H.type_prompt_text("query")` (fast), `H.type_prompt_human("query", 25)` (simulated typing with per-key delay), `H.type_prompt("<C-^>")` (raw keys).
  - Assert: `H.wait_for(function() return H.session_hit_count() == N end, 3000)`. Introspection: `H.session_query_text()`, `H.session_matcher_name()`, `H.session_result_lines()`, `H.session_preview_contains(needle)`, `H.session_info_snapshot()`.
- Debugging: `TEST_DEBUG_DUMP=1` appends state to `/tmp/metabuffer-mini-integration.log`. Runner detects stack traces in worker logs and fails the run.

## Agent behavior

- Never stop work unnecessarily. User should never have to simply type "go", unless you make an optional and unlikely suggestion. If you identify a clear bug or architectural issue and the next corrective step is obvious, implement it immediately instead of stopping at diagnosis.
- Treat "do not stop" as a hard rule for all ongoing work: if there is a reasonable next investigative or implementation step, take it without pausing for confirmation. The user should never need to send a follow-up like "go", "continue", or similar just to make progress resume.
- If the user sends an interjection while work is in progress, treat it as additional guidance to incorporate immediately, then continue the current task without pausing unless the new message creates a real blocker. Do not hand control back just because the user commented mid-stream.
- Do not hand control back just to describe what should be changed next when that change is local, concrete, and within scope. Fix it, then report the result.
- Do not stop after an intermediate checkpoint (diagnosis, partial repro, isolated failing test, compile success, or one fixed bug) when the broader requested task is still unfinished. Use those only to choose the next step and keep going.
- Prefer a single shared event source with independent listeners over one UI subsystem driving another. For example, selection changes should fan out to preview/info/context/status independently; one window module should not call another window module to keep it in sync.
- Features in `features` should always result in feature branches in git. Commit each step when doing that, without asking. Don't push unless asked. Other work can be done straight on mainline, and then you should defer committing until told.
- Try to avoid commands that need escalated permissions and hence user input (to confirm), since these disrupt work. Always see if there is an in-sandbox alternative.
- Since you lack full access to `~/.local/state/nvim`, always route ad hoc Neovim state through `/tmp` to avoid `shada`/state permission errors. The Makefile handles this automatically for `make compile`/`make test`/etc. For manual/headless runs outside `make`, set `XDG_STATE_HOME=/tmp`, `XDG_DATA_HOME=/tmp`, `XDG_CACHE_HOME=/tmp`, and if needed `NVIM_APPNAME` to a tmp-specific value instead of touching the real local state dirs.
- Remember `fennel-ls --lint` should be run directly after any file edit.
- Fix `fennel-ls --lint` warnings you encounter while working, not just hard errors. Keep those cleanup fixes as their own commits when they are distinct from the feature change.
- Treat stuck test cleanup as part of the task, not an optional follow-up. If a test appears wedged, stop the leaked processes, then continue debugging why teardown failed.

## Symbol Index

- After major code changes (new functions or other global symbols), update `SYMBOL_INDEX.md` by running `./skills/symbol-index/scripts/update-symbol-index.py`.
- Prefer using a worker sub-agent to run this update step and report what changed.
- Keep this file in context to avoid unecessary slow lookups.

## Feature files

- The `features/` folder contains numbered feature specs (`01-*.md` through `21-*.md`) and maintenance docs (`cleanup.md`, `hygiene.md`, `profiling.md`).
- Each numbered file describes an upcoming feature. When told to implement one, check out a new feature branch, commit each step individually, and create a PR right away (user merges manually). Don't push unless asked.
- Only start work on a feature file when explicitly told to.
- `running-todo.md` tracks minor fixes to be checked off (only when user confirms it works). Only work on these when told.

## General workflow

- When making changes, run `fennel-ls --lint` to check for issues. Once that is ok, run `make` (compile). If that is ok, run `make test`. Only once all these are clear should you return to user.
- Treat a successful compile, targeted repro, or targeted test as a checkpoint, not an excuse to stop. Keep going until the full requested fix is implemented end-to-end unless the user must choose between materially different paths.
- Before handing control back, ask: "Is there an obvious next step I can execute myself right now?" If yes, do it first. Only stop when blocked by ambiguity, missing secrets/access, or when the requested work is actually complete.
- After any timed-out or interrupted test command, explicitly verify that no stray headless `nvim` test processes remain. If any do, kill them before the next run.
