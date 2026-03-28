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

### `info.fnl` (994 lines — largest window module)
- Floating info panel showing metadata for the selected hit.
- Two render modes:
  1. **Hit info**: file path, line number, git blame, file size, permissions, etc.
  2. **Project loading**: streaming progress (`N/M files`), shown during bootstrap.
- Info window winbar mirrors current visible range and loading progress.
- Buffer shaping must never introduce empty visible rows; use loading placeholders while async detail fill catches up.
- `build-info-lines` — Constructs the info line table from hit metadata.
- `render-info-lines!` — Writes lines to info buffer with highlight namespaces.
- `schedule-info-highlight-fill!` — Async highlight application to avoid blocking.
- `project-loading-pending?` — Determines whether to show loading view vs hit info. Only true during actual bootstrap (`startup`, `bootstrap-pending`, `not bootstrapped`, `not stream-done`), NOT during lazy refresh operations.
- Info rerender signatures should include the concrete ref slice and active source mode, not just index counts, so source switches like `#file` cannot leave stale content in place.
- Accounts for host window winbar when positioning (row offset).

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
Window modules receive their update call and act independently. They never import or call each other.

### Option Stash/Restore
`base.fnl` provides the stash/restore mechanism inherited by all window wrappers. On creation, window-local options are saved; on teardown they are restored to their pre-Meta values. This prevents Meta from permanently altering the user's window configuration.

### Airline Guard
Airline compatibility is now handled by `compat/airline.fnl` via the event bus. The `compat.on-win-create!` and `compat.on-win-teardown!` calls set/remove `w:airline_disable_statusline`. The guard must fire on every Meta window creation because Airline aggressively re-renders on `WinEnter`/`BufEnter`.

## Caution Points

- `info.fnl` is the most complex module (994 lines). The loading-vs-hit-info mode switch is sensitive — `project-loading-pending?` must only return true during actual bootstrap, not during lazy refresh operations (this was a previous bug).
- Animation cancellation tokens are per-session. Failing to cancel on teardown causes timer leaks and ghost updates to destroyed buffers.
- Preview horizontal scroll interacts with wrap setting. When wrap is on, horizontal scroll is disabled.
- Float positioning must account for winbar (row offset +1 when winbar present).
