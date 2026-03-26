# Prompt Subsystem

11 modules managing prompt input, keymap handling, autocmd lifecycle, and input history. The prompt is a real Neovim buffer in a split window — users type in insert mode and the prompt subsystem translates edits into filter operations.

## Module Responsibilities

### `hooks.fnl` (1112 lines — largest prompt module)
- `M.new` — Factory that creates the hooks manager. Receives a large dependency table from `router/session.fnl` (avoids circular requires).
- Registers all prompt-related autocmds: `TextChanged`, `TextChangedI`, `CursorMoved`, `CursorMovedI`, `InsertEnter`, `InsertLeave`, `WinEnter`, `WinLeave`, `BufEnter`, `BufLeave`, `BufWritePost`.
- `on-prompt-changed` — Core event handler: reads prompt text, detects directive changes, dispatches to `router/query_flow.fnl`.
- Mode switching: handles `switch-mode` for matcher/case/syntax cycling.
- CMP integration: disables `nvim-cmp` in the prompt buffer.
- Scroll sync: schedules preview/info updates after scroll events.
- UI visibility management: hides/restores floating windows during mode transitions.
- Digraph input: wires digraph key handler into prompt insert mode.
- Animation-aware delays: adjusts prompt evaluation timing when animations are active.

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

## Caution Points

- `hooks.fnl` is large (1112 lines) because it orchestrates all prompt-related events. Modifications should be carefully scoped — each autocmd callback has subtle interactions with debounce timing and animation delays.
- The keystroke timer in `keystroke.fnl` can race with prompt TextChanged events. The sequence detector must consume the input before the regular prompt handler sees it.
- History navigation (`history.fnl`) behavior changes when the history browser float is open — `<Up>`/`<Down>` move the browser selection instead of cycling session history. This dual behavior is coordinated through a flag on the session object.
