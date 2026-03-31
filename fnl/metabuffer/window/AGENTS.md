# Window Subsystem

12 modules managing all Meta UI windows. Window modules never call each other directly — the router dispatches updates to each independently after state changes (event-driven fan-out).

## Module Responsibilities

### `base.fnl` (50 lines)
- `M.new` — Creates a window wrapper around a Neovim window handle. Stashes/restores window-local options on creation/teardown.
- `apply-metabuffer-window-highlights!` — Applies `winhighlight` remappings for Meta-owned windows.

### `metawindow.fnl` (46 lines)
- Main results window wrapper. Extends `base.fnl`.
- Defines `default-opts` (number, cursorline, signcolumn, scrolloff etc.) and `opts-to-stash` (options that are saved/restored).
- Owns the statusline format string (`%s%%#%s#%%=%s`) rendered by `statusline.fnl`.

### `floating.fnl`
- Creates and manages floating windows (info panel, keybind popup, etc.).
- Handles float positioning relative to host windows, accounting for winbar offsets.
- Provides open/close/resize API for float lifecycle.

### `prompt.fnl` (148 lines)
- Prompt window: horizontal split below the results window.
- Height persistence: reads/writes prompt height via `router/util.fnl` state files.
- Manages prompt buffer attachment and focus.

### `preview.fnl` (517 lines)
- Preview pane showing context around the currently selected hit.
- `maybe-update-for-selection!` — Main entry: reads source file, centers on hit line, applies syntax highlighting.
- Horizontal scroll: auto-scrolls to show indented content that would otherwise be off-screen.
- Line wrap persistence: wrap setting survives across sessions via state file.
- Statusline: shows file path of previewed file, positioned under the preview column.

### `info.fnl`
- Top-level info-window composition module.
- Wires float lifecycle (`info_float.fnl`), viewport sizing (`info_viewport.fnl`), line building (`info_row.fnl`), regular-mode updates (`info_regular.fnl`), and project-mode policy from `project/info_view.fnl`.
- Keep it as orchestration; do not let concrete render/update policy drift back into this file.

### `info_float.fnl`
- Float lifecycle and geometry helpers extracted from `info.fnl`.
- Keeps float/window concerns separate from project-mode content policy.

### `info_render.fnl`
- Shared render primitives for the info buffer.
- Owns `render-info-lines!`, selection highlight sync, and composition of row-builder + viewport + regular-mode updater.

### `info_regular.fnl`
- Regular-mode info update policy.
- Owns rerender signatures, current-range refresh, and async line-meta refetch scheduling.
- If the selected line or visible slice changes, this layer decides whether to rerender or just resync the viewport/highlight.

### `info_row.fnl`
- Builds concrete info buffer rows and synchronous/deferred highlight specs.
- Extension/icon coloring should stay here or in shared highlight helpers, not in float/layout code.

### `info_viewport.fnl`
- Owns visible-range math, info-buffer shaping, and topline sync.
- If the info view gets out of sync with the results viewport, fix it here rather than in project/ or prompt hooks.

### `animation.fnl` (580 lines)
- Dual-backend animation system:
  - **mini.animate** (preferred): uses `MiniAnimate` if available.
  - **native**: `vim.uv.new_timer` frame loop fallback.
- `enabled?` — Checks if animation is active for a given session and animation type.
- `duration-ms` — Returns effective duration after applying master + per-animation time scales.
- Per-session cancellation tokens prevent animation leaks when sessions are torn down.
- Animation types: `prompt`, `preview`, `info`, `loading`, `scroll`.

### `context.fnl`
- Contextual sidebar window (shown in project mode).
- Displays additional context around the selected hit beyond what the preview shows.

### `lineno.fnl`
- Fake line-number column for project mode results.
- Dynamic width: pinned to minimum 3 columns, expands to 4+ only when longer line numbers are in the visible range.
- Prevents visual jumps when file line numbers cross digit boundaries.

### `statusline.fnl`
- Builds statusline content for the main results window.
- Compact flag display: `hid` (hidden), `ig` (ignored), `dep` (deps), `prf` (prefilter), `nlz` (nolazy).
- Shows matcher name, hit count, and file path under preview column.

### `history_browser.fnl` (152 lines)
- Floating popup for browsing prompt history and saved prompts.
- Live filtering: typing in prompt narrows browser items.
- `<CR>` applies selected entry; `<Esc>` closes browser.
- Opened via `<C-r>` or `##` directive.

### `init.fnl` (8 lines)
- Barrel module: returns map of `{:base, :metawindow, :floating, :history-browser, :prompt, :preview, :info}`.

## Key Patterns

### Event-Driven Fan-Out
The router (not window modules) owns the update dispatch. When selection changes:
```
router → preview.maybe-update-for-selection!
router → info.update!
router → context.update!  (if visible)
router → statusline rebuild
```
Window modules receive their update call and act independently. They never import or call each other directly.

### Option Stash/Restore
`base.fnl` provides the stash/restore mechanism inherited by all window wrappers. On creation, window-local options are saved; on teardown they are restored to their pre-Meta values. This prevents Meta from permanently altering the user's window configuration.

### Airline Guard
Airline compatibility is now handled by `compat/airline.fnl` via the event bus. The `compat.on-win-create!` and `compat.on-win-teardown!` calls set/remove `w:airline_disable_statusline`. The guard must fire on every Meta window creation because Airline aggressively re-renders on `WinEnter`/`BufEnter`.

## Caution Points

- `info.fnl` should stay thin. Push row building into `info_row.fnl`, regular-mode policy into `info_regular.fnl`, viewport math into `info_viewport.fnl`, and project-mode policy into `project/info_view.fnl`.
- Animation cancellation tokens are per-session. Failing to cancel on teardown causes timer leaks and ghost updates to destroyed buffers.
- Preview horizontal scroll interacts with wrap setting. When wrap is on, horizontal scroll is disabled.
- Float positioning must account for winbar (row offset +1 when winbar present).
