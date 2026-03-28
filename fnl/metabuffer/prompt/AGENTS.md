# Prompt Subsystem

11 modules managing prompt input, keymap handling, autocmd lifecycle, and input history. The prompt is a real Neovim buffer in a split window — users type in insert mode and the prompt subsystem translates edits into filter operations.

## Module Responsibilities

### `hooks.fnl` (1229 lines — largest prompt module)
- `M.new` — Factory that creates the hooks manager. Receives a large dependency table from `router/session.fnl` (avoids circular requires).
- Registers all prompt-related autocmds: `TextChanged`, `TextChangedI`, `CursorMoved`, `CursorMovedI`, `InsertEnter`, `InsertLeave`, `WinEnter`, `WinLeave`, `BufEnter`, `BufLeave`, `BufWritePost`.
- `on-prompt-changed` — Core event handler: reads prompt text, detects directive changes, dispatches to `router/query_flow.fnl`.
- Directive UX: inline directive arguments should use `#flag:filter` form when available; prompt highlighting should clearly separate the directive prefix from the inline argument (`#file:` vs path filter text).
- Mode switching: handles `switch-mode` for matcher/case/syntax cycling.
- CMP integration: disables `nvim-cmp` in the prompt buffer.
- Scroll sync: schedules preview/info updates after scroll events.
- UI visibility management: hides/restores floating windows during mode transitions.
- Digraph input: wires digraph key handler into prompt insert mode.
- Animation-aware delays: adjusts prompt evaluation timing when animations are active.
- Event bus emission: emits lifecycle events (`:on-insert-enter!`, `:on-session-start!`, `:on-session-stop!`, `:on-mode-switch!`, etc.) via `events.send` so that compat modules and other subsystems react to prompt lifecycle changes without direct coupling.
- Window restore: monitors `WinNew`, `VimResized`, and `OptionSet` to auto-restore Meta window layout after external disturbances.

### `prompt.fnl`
- Prompt object: wraps the prompt buffer.
- `get-text` / `set-text!` — Read/write prompt content.
- Buffer lifecycle: create, attach to window, cleanup.

### `action.fnl`
- Prompt editing actions mapped to keybindings:
  - `prompt-home` (`<C-a>`) — Move cursor to line start.
  - `prompt-end` (`<C-e>`) — Move cursor to line end.
  - `prompt-kill-backward` (`<C-u>`) — Delete from start to cursor, stash killed text.
  - `prompt-yank` (`<C-y>`) — Re-insert previously killed text.
  - `prompt-newline` (`<S-CR>`) — Insert a literal newline into the prompt for multi-line queries.

### `keymap.fnl`
- Keymap registration engine.
- `register-prompt-keymaps!` — Takes the keymap table from config and registers buffer-local mappings.
- Builder pattern: each keymap entry is `{modes, key, action-name, ...args}`. The builder resolves `action-name` to the corresponding router function.

### `key.fnl`
- Key constant definitions.
- Maps symbolic names to Neovim key codes (e.g. `<C-a>`, `<CR>`, `<Esc>`).
- Used by `keymap.fnl` and `keystroke.fnl` for consistent key references.

### `keystroke.fnl`
- Multi-key sequence detection.
- Tracks key input state to detect sequences like `!!` (insert last prompt), `!$` (insert last token), `!^!` (insert last tail).
- Timer-based: resets sequence state after a short idle timeout.

### `caret.fnl`
- Cursor position tracking within the prompt buffer.
- Reports cursor column to other modules (e.g. for determining which token the cursor is on for `negate-current-token`).

### `history.fnl`
- Prompt history navigation.
- `<Up>` / `<Down>` cycle through session history entries.
- Interacts with `history_browser` window when the browser is open (arrow keys move browser selection instead).

### `digraph.fnl`
- Digraph input support.
- Allows entering special characters via the standard Neovim digraph mechanism in insert mode.

### `util.fnl`
- Prompt text utilities.
- Token extraction, whitespace normalization, line splitting helpers.

### `init.fnl` (11 lines)
- Barrel module: returns map of `{:prompt, :action, :keymap, :key, :keystroke, :caret, :history, :hooks, :digraph, :util}`.

## Key Patterns

### Dependency Injection
`hooks.fnl` receives all its dependencies via an `opts` table at construction time rather than requiring modules directly. This avoids require cycles (hooks depends on router functions, router depends on hooks registration).

```fennel
(fn M.new [opts]
  (let [{: mark-prompt-buffer!
         : on-prompt-changed
         : update-info-window
         : update-preview-window
         ...} opts]
    ;; all callbacks come from opts, never from require
    ))
```

### Keystroke State Machine
`keystroke.fnl` implements a mini state machine for multi-character sequences. State transitions:
1. First `!` → arm sequence detector, start timeout timer
2. Second `!` within timeout → fire `insert-last-prompt`, reset
3. `$` within timeout → fire `insert-last-token`, reset
4. Timeout expires → insert literal `!`, reset

### Autocmd Lifecycle
Autocmds are created with a session-specific augroup. On session teardown, the entire augroup is cleared. This prevents stale autocmds from firing on destroyed buffers.

### Autocmd Helpers
Three helpers are defined inside `register!`, closing over `aug` (augroup) and `session`:

- `au!` — Buffer-local + `schedule-when-valid` session guard. Signature: `(au! events buf body)` where `body` is a zero-arg function. Use for simple buffer-local autocmds that just need session-safe scheduling.
- `au-buf!` — Buffer-local + raw callback. Signature: `(au-buf! events buf callback)` where `callback` receives the event object. Use when the callback needs complex synchronous logic, its own `vim.schedule`, or access to the event data.
- `au-global!` — Global (no buffer scope) + raw callback with optional opts override. Signature: `(au-global! events callback ?opts)`. Use for non-buffer-scoped autocmds like `VimResized`, `WinNew`, `WinScrolled`, `BufWritePost`. Pass `{:pattern "wrap"}` etc. via `?opts` for pattern-based autocmds like `OptionSet`.

All raw `vim.api.nvim_create_autocmd` calls inside `register!` use one of these three helpers. The only direct `nvim_create_autocmd` calls remaining in hooks.fnl are the helper definitions themselves.

## Caution Points

- `hooks.fnl` is large (~1230 lines) because it orchestrates all prompt-related events and now also emits lifecycle events via the event bus. Modifications should be carefully scoped — each autocmd callback has subtle interactions with debounce timing and animation delays.
- The keystroke timer in `keystroke.fnl` can race with prompt TextChanged events. The sequence detector must consume the input before the regular prompt handler sees it.
- History navigation (`history.fnl`) behavior changes when the history browser float is open — `<Up>`/`<Down>` move the browser selection instead of cycling session history. This dual behavior is coordinated through a flag on the session object.
