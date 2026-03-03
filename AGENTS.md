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
  - `./script/nfnl`
- Compile all Fennel through nfnl (headless Neovim):
  - `./scripts/compile-fennel.sh`
- Continuous source lint watch (for immediate paren/syntax failures):
  - `./scripts/watch-fennel.sh`
- Continuous lint + compile watch:
  - `./scripts/watch-fennel.sh --compile`
- Optional compile logging:
  - default: quiet (`NVIM_LOG_FILE` defaults to `/dev/null`)
  - debug: `NVIM_LOG_FILE=.nvimlog ./scripts/compile-fennel.sh`

## Important Session Notes

- The previous raw compiler flow (`fennel --compile`) was replaced with headless Neovim + `metabuffer.nfnl.api` compile flow.
- `scripts/compile-fennel.sh` must not delete `lua/`; deleting it removes vendored `lua/metabuffer/nfnl`.
- nfnl trust behavior in headless environments can block `.nfnl.fnl` (`vim.secure.read` untrusted); compile script includes a controlled local fallback reader for non-interactive compilation.
- `script/nfnl` was implemented to avoid dependency on `sd`/`fd` (uses standard shell tools + `perl`), because those were not available in this environment.

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
- This repository intentionally commits compiled Lua so users do not need nfnl at runtime.

## Fennel code style

- Mirror Clojure best practices as close as possible.
- Function arguments always on separate line (unless entire thing oneliner).
- Write (brief) docstrings for functions and keep them up to date. Include expected output.

## Self-improvement

- When appropriate, update this file with new learnings, conventions, information, but make sure it is important enough, and ensure anything outdated is replaced rather than just countinously appending.

## Feature files.

- In the folder features/ we describe upcoming (branched) features in individual files. When told, and only then, use the relevant file as basis for feature implementation. Always check out a new branch for these, and make a PR at end.
- The folder also has a running-todo.md describing minor fixes to be done, and then checked off (only when I say it works). Only work on them when told.
