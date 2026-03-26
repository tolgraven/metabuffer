# Router Subsystem

The router is the central orchestrator for metabuffer. `router.fnl` (714 lines) is the singleton entry point; its submodules split responsibilities into focused domains.

## Module Responsibilities

### `router.fnl` (singleton orchestrator)
- Requires all window modules, meta, prompt hooks, and all router submodules.
- Wires dependency tables that submodules receive instead of requiring router directly (avoids circular requires).
- Exposes the public API called by user commands: `entry_start`, `resume`, `accept`, `cancel`, `move_selection`, `scroll_main`, `switch_mode`, `toggle_project_mode`, etc.
- Owns `active-by-prompt` — the map from prompt buffer id to live session. This is the canonical session registry.
- Manages prompt buffer naming (synced to origin buffer name for statusline clarity).

### `session.fnl` (723 lines)
- `start!` — Full session bootstrap: creates meta object, prompt buffer, all window wrappers, registers prompt hooks, sets keymaps, optionally bootstraps project-mode streaming.
- `stop!` — Tears down a session: clears autocmds, destroys windows, restores stashed options, unloads buffers async.
- `resume!` — Reactivates a previously stopped session (re-attaches windows, re-registers hooks).
- Handles project-mode-specific bootstrap: calls `project_source_mod.bootstrap!` with a streaming callback that feeds results into `meta.on-update` as they arrive.
- Wires the dependency table that hooks, actions, and query_flow modules receive.

### `actions.fnl` (1215 lines — largest router file)
- Accept handlers: `accept-hit!` (jump to file:line), `accept-from-main!` (when results buffer focused).
- Cancel handler: `cancel!` (restore viewport, teardown).
- Toggle handlers: `toggle-project-mode!`, `toggle-scan-option!`.
- Writeback: `sync-changes!` propagates edits from the metabuffer back to origin files.
- Push: `push-to-origin!` writes metabuffer content over origin entirely.
- Window teardown orchestration: destroys windows in correct order, restores airline, clears autocmds.
- Contains `silent-win-set-buf!` helper (also in session.fnl — intentional local duplication to avoid cross-require).

### `query_flow.fnl` (332 lines)
- `apply-prompt-lines!` — The core filter pipeline. Reads prompt text → parses directives → decides if source/transform needs reload → runs matcher filter → triggers buffer render.
- Debounce logic: `queue-update-after-edit!` manages idle windows and prompt scheduler.
- Source switching: detects when `#file`, `#lgrep`, or scope toggles change and reloads the source set.
- Transform switching: detects `#hex`, `#json`, etc. and applies/removes transforms.
- Space-handling optimization: skips re-filter when whitespace-only edits don't change effective tokens.

### `navigation.fnl` (300 lines)
- `move-selection!` — Moves cursor by N lines, clamps to buffer bounds.
- `scroll-half-page!` / `scroll-page!` — Half/full page movement with boundary clamping.
- Scroll sync: after moving selection, schedules preview and info window updates.
- Source syntax refresh: in project mode, debounces treesitter re-highlight for visible source separators.
- Cursor hiding: temporarily hides cursor during programmatic scroll to avoid visual flash.

### `prompt.fnl` (375 lines)
- `prompt-update-delay-ms` — Computes debounce delay based on current state (lgrep active → longer delay, typing fast → shorter).
- `schedule-prompt-update!` — Timer-based prompt evaluation scheduling.
- `incomplete-directive-token?` — Detects partial directive input (e.g. `#fi` while typing `#file`) to avoid premature evaluation.
- Analyzes prompt text for active line detection, last non-empty line extraction.

### `history.fnl` (319 lines)
- `M.new` — Creates history manager per session.
- `build-history-entry` — Constructs a history record from current prompt state including scope toggles, matcher name, and effective text.
- `recall!` — Restores a history entry into the prompt, re-applying scope toggles and matcher mode.
- `merge-persisted!` — Imports entries from `history_store` into session history.
- `normalize-history-prompt` — Canonicalizes toggle syntax (`#+file` → `#file`).

### `util.fnl` (505 lines)
- State persistence: `read-prompt-height-state` / `write-prompt-height-state!`, `read-results-wrap-state` / `write-results-wrap-state!` — persist prompt window height and results wrap setting across Neovim restarts via `stdpath("state")` files.
- `prompt-lines` — Reads all lines from the prompt buffer.
- `resolve-option` — Resolves a config key with fallback chain (session → config → default).
- `transform-apply-ops!` — Applies transform operations to source lines.

## Inter-Module Communication

Router submodules communicate through dependency injection, NOT circular requires:

```
router.fnl builds deps = {
  :router M                -- the router module itself
  :meta session.meta       -- the meta model object
  :settings resolved-config
  :timing {debounce values}
  :prompt-scheduler-ctx {timer state}
  ...window modules, source modules, etc.
}

session.fnl passes deps → hooks.fnl
hooks.fnl calls → query_flow, navigation, actions (via deps)
```

This pattern prevents Lua `require` cycles. Submodules never require `router.fnl`; they receive it via the deps table.

## Caution Points

- `actions.fnl` is the largest file (1215 lines) and handles many responsibilities. When modifying accept/cancel flow, trace the full teardown sequence carefully — window destruction order matters.
- `silent-win-set-buf!` is duplicated in `actions.fnl` and `session.fnl` intentionally. Each needs it locally to avoid requiring the other.
- The debounce in `query_flow.fnl` interacts with the idle-window detection in `prompt.fnl` — changes to timing must consider both.
- Project mode bootstrap in `session.fnl` sets up an async streaming callback. The session must stay alive until `stream-done` is set; premature teardown causes orphaned timers.
