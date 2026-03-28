# Feature Implementation Tracker

Audited: 2026-03-28

This tracks the numbered feature specs in `features/` against the current `main` branch, existing feature branches, and relevant commits. It excludes the maintenance notes (`cleanup.md`, `hygiene.md`, `profiling.md`, `running-todo.md`) and the `features/research/` docs.

## Implemented

- [x] `01-multiple-buffers-and-floating-info.md`
  Project mode, cross-file hits, floating info, `<CR>` jump, and resume/session tracking are in place. Evidence: `feature/multi-buffer-floating-info`, `f5ddb1f`, current `router/session`, `window/info`, `:MetaResume`.
- [x] `01_2-lazy.md`
  Lazy project streaming, chunked refresh, prefilter toggles, startup prioritization, and config toggles are implemented. Evidence: `feature/01_2-lazy`, `ad94695`, `project/source.fnl`, `query_flow`, `config` lazy options.
- [x] `02-edit-propagation.md`
  Results-buffer edit mode and writeback to source files are implemented, including file-entry rename behavior. Evidence: `feature/02-edit-propagation`, `477e902`, `router/actions.fnl`, `source/{text,file,init}.fnl`, edit screen tests.
- [x] `06-prompt-highlighting.md`
  Prompt token highlighting exists even though the spec file is empty. Evidence: `prompt/hooks.fnl`, README/vimdoc prompt highlight sections, matcher/persistence tests.
- [x] `07-prompt-niceties.md`
  The spec itself now documents the implemented scope, and the related branch/commits are present. Evidence: `feature/07-prompt-niceties-additions`, `dd7897e`, `1785333`.
- [x] `09_1-unit-tests.md`
  Unit testing is implemented, but with `mini.test` instead of the spec’s original `plenary.nvim` idea. Evidence: `tests/unit/`, `a9a9d62`, `tests/testing.md`, AGENTS updates.
- [x] `09_2-integration-tests.md`
  Integration/screen coverage is implemented with `mini.test`. Evidence: `feature/09_2-integration-tests`, `93dc74b`, `tests/screen/`, `tests/testing.md`.
- [x] `10-hot-reload.md`
  Reload support exists, including compile-on-reload and smoke coverage. Evidence: `init.fnl` `M.reload`, `:MetaReload`, `tests/smoke/test_smoke_reload_compile.lua`.
- [x] `11-normal-nvim-setup.md`
  `setup(opts)` exposes defaults, keymaps, options, and nested UI config in normal Lua style. Evidence: `config.fnl`, README setup examples, `require("metabuffer").defaults`.
- [x] `20-lgrep-support.md`
  `#lgrep`/`#lg`, definition/usages variants, highlighting, docs, and tests are implemented. Evidence: `feature/20-lgrep-support`, `3906548`, `source/lgrep.fnl`, README/vimdoc, unit and screen tests.

## Partially Implemented

- [ ] `03_2-other-filters-support.md`
  `#file` and file-entry behavior are implemented, including file previews and file rename writeback. The broader “arbitrary non-text filters” idea is still open. Evidence: `query/source` file support, file rename tests, no git-sign/vimdoc filter implementation.
- [ ] `04-bringing-in-context.md`
  Context expansion exists with `#exp`, a context window, and multiple expansion modes (`around`, `fn`, `class`, `usage`, `env`). The bigger spec ambitions are still open: deeper multi-file expansion workflows, automatic parser installation, and broader language support. Evidence: `context/expand.fnl`, `window/context.fnl`, context tests.
- [ ] `08-prompt-completion.md`
  Builtin directive completion exists, but “regular completion framework support” from cmp/origin-buffer sources is not implemented; Meta currently suppresses normal completion plugins in the prompt. Evidence: `query/directive.fnl` completefunc, `prompt/hooks.fnl`, `compat/cmp.fnl`.
- [ ] `13-clj-ish-rewrite.md`
  The codebase clearly moved further toward cljlib/Clojure-style Fennel, but not to the full rewrite demanded by the spec. Evidence: heavy cljlib usage across `fnl/`, but the code still uses ordinary `fn`/`local` patterns extensively and the spec’s “complete rewrite” is not done.
- [ ] `14-meta-as-navigator.md`
  Pieces of the workflow exist: window-local layout, sync-from-main behavior, preview/context/info side windows. The more explicit “keep Meta on the side as a persistent navigator while another main work window drives context” still looks incomplete/experimental. Evidence: `session/view.fnl`, `router/navigation.fnl`, context window plumbing.
- [ ] `16-visual-snazz.md`
  A large chunk landed: animated prompt/info/preview/scroll behavior, loading indicator pulse, and mini/native animation backends. Some of the more ambitious spec items still appear open, especially dummy overlay loading windows. Evidence: `feature/16-visual-snazz`, `1af2113`, `5821718`, `window/animation.fnl`.
- [ ] `18-mini-nvim-lib.md`
  `mini.animate` and `mini.test` have been adopted, which covers the most concrete parts of the spec. The wider mini.nvim integration ideas (icons/completion/clue/git helpers/etc.) remain open. Evidence: `feature/18-mini-nvim-lib`, dependency/docs/test references, animation backend support.
- [ ] `19-in-file-auto-surface.md`
  There is groundwork from context expansion and navigator-style syncing, but the actual automatic “surface the thing around cursor with related context” mode is not clearly finished. Evidence: overlap with `04` and `14`, but no distinct user-facing auto-surface mode or docs/tests for it.

## Not Implemented

- [ ] `01_3-conceal.md`
  No evidence of conceal-based filtering/rendering; only normal window option stashing references `conceallevel`.
- [ ] `03-other-sources-support.md`
  The source-provider architecture exists, but the main requested follow-through is still open: LSP-backed structural sources, git history/PR/browser/tmux/vimdoc sources, and source-aware edit propagation for those backends.
- [ ] `05-llm-sync.md`
  No repo evidence of the socket-driven agent/UI sync feature.
- [ ] `12-simple-other-source.md`
  The spec file is currently empty, so there is nothing concrete to mark as implemented.
- [ ] `15-use-as-better-s-runner.md`
  No evidence of `:s/` prompt mode, live substitution preview, or capture-group highlighting.
- [ ] `17-virtual-tabs.md`
  No evidence of a Meta-specific virtual tab bar or instance switching UI.
- [ ] `21-tmux-pane-history-search-jump.md`
  No evidence of `#tmux` sources, scrollback ingestion, baleia integration, or tmux jump behavior.

## Notes

- “Implemented” here means the main user-visible scope of the spec exists on `main`, not necessarily that every idea in the file was completed.
- “Partially implemented” means there is clear shipped groundwork or a meaningful subset, but important spec items remain open.
- If this file is going to be maintained over time, the cleanest pattern is to update it whenever a numbered feature branch lands or a numbered spec is intentionally abandoned/superseded.
