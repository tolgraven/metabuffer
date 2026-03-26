# Compat / Event Bus

Generic lifecycle event system. The standalone bus lives in `fnl/metabuffer/events.fnl`; `compat/init.fnl` is a pure side-effect loader that registers compat modules and returns `{}`. Modules declare which events they care about; the bus collects, sorts by priority, filters by role, and pcall-dispatches. Compat modules (third-party plugin shims) are the first consumers, but any subsystem can hook in.

## Module Contract

Each consumer module returns a table with an `:events` key. No `M` table — just pure data + functions.

```fennel
{:events
 {:<event-name> <spec>
  :<event-name> <spec>
  ...}}
```

## Handler Spec Schema

Each event value is one of three forms:

### 1. Bare function

```fennel
{:events
 {:on-session-start! (fn [args] ...)}}
```

Normalized to `{:handler fn :priority 50}`. No role filter — matches everything.

### 2. Config map

```fennel
{:events
 {:on-buf-create! {:handler (fn [args] ...)
                    :priority 10
                    :role-filter :prompt}}}
```

### 3. Sequential list of config maps

Multiple handlers for one event:

```fennel
{:events
 {:on-buf-create!
  [{:handler disable-common!  :priority 10}
   {:handler disable-pairs!   :priority 20  :role-filter :prompt}
   {:handler mark-preview!    :priority 20  :role-filter :preview}]}}
```

### Spec Keys

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `:handler` | `fn` | yes | — | The callback. Signature receives one args map (see catalog below). |
| `:priority` | `int` | no | `50` | Lower = runs first. Range 1–100 recommended. |
| `:role-filter` | `keyword`/`[keyword]` | no | `nil` | For buf/win events: restricts to listed roles. Omit = matches all. |

### Module-Level Keys

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `:events` | `table` | yes | — | Map of event-name → spec (see above). |
| `:name` | `string` | no | `"?"` | Module identifier, stamped onto each handler spec as `:source`. Shown in profiling logs. |
| `:domain` | `string` | no | `"?"` | Logical grouping (e.g. `"compat"`, `"transform"`, `"source"`). Shown in profiling logs to distinguish subsystems sharing the bus. |

## Event Catalog

Events are organized by lifecycle phase. Each entry shows the event name, handler signature, and when it fires.

### Plugin Lifecycle

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-plugin-init!` | `(config)` | `M.setup` called with merged config |
| `:on-plugin-teardown!` | `()` | Plugin unloaded |

### Session Lifecycle

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-session-start!` | `(session)` | New Meta session created, wiring begins |
| `:on-session-ready!` | `(session)` | UI fully settled — see below |
| `:on-session-stop!` | `(session)` | Session fully torn down |

**`:on-session-ready!` semantics:**
- **Buffer mode**: first filter + render cycle complete, results visible, info loaded.
- **Project mode**: bootstrap streaming done, results rendered into buffer, info window populated, entry animations finished.
- This is the "plugin is ready to use" signal. Use it for anything that should run only after the user can see and interact with results.

### Buffer Lifecycle

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-buf-create!` | `(buf role)` | Buffer created for a session |
| `:on-buf-teardown!` | `(buf role)` | Buffer about to be wiped |

**Buffer roles** (passed as second arg, filterable via `:role-filter`):

| Role | Buffer |
|------|--------|
| `:meta` | Main results buffer |
| `:prompt` | Prompt input buffer |
| `:preview` | Preview pane buffer |
| `:info` | Info float buffer |

### Window Lifecycle

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-win-create!` | `(win role)` | Window opened for a session |
| `:on-win-teardown!` | `(win role)` | Window about to close |

**Window roles** (passed as second arg, filterable via `:role-filter`):

| Role | Window |
|------|--------|
| `:main` | Main results window |
| `:prompt` | Prompt input window |
| `:preview` | Preview pane window |
| `:info` | Info float window |
| `:origin` | The window Meta was launched from |

### Mode Events

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-insert-enter!` | `(session)` | InsertEnter in prompt buffer |
| `:on-mode-switch!` | `(session kind old new)` | Matcher, case, or syntax mode toggled |

**`:on-mode-switch!` `kind` values**: `"matcher"`, `"case"`, `"syntax"`

### Source / Query Events

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-source-switch!` | `(session old-source new-source)` | Source provider changed (text → file, file → lgrep, etc.) |
| `:on-query-update!` | `(session query)` | Prompt query parsed and applied |
| `:on-selection-change!` | `(session line-nr)` | Selected hit changed (navigation, filter) |

### Project Events

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-project-bootstrap!` | `(session)` | Project mode streaming starts |
| `:on-project-complete!` | `(session)` | Project source fully loaded |

### Action Events

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-accept!` | `(session)` | User accepts selected hit (`<CR>`) |
| `:on-cancel!` | `(session)` | User cancels session (`<Esc>`) |
| `:on-restore-ui!` | `(session)` | Hidden session UI restored (resume) |

### Directive Events

| Event | Signature | Fires when |
|-------|-----------|------------|
| `:on-directive!` | `(session directive-key value change)` | User typed or removed a prompt directive |

**`:on-directive!` change map:**

| Key | Type | Description |
|-----|------|-------------|
| `:old` | `any` | Previous value of `directive-key` in session (nil if newly activated) |
| `:new` | `any` | New value from parsed query (nil if deactivated) |
| `:activated?` | `bool` | `true` when directive was absent and is now present |
| `:deactivated?` | `bool` | `true` when directive was present and is now absent |
| `:kind` | `string` | Directive kind from spec: `"toggle"`, `"flag"`, `"suffix"`, `"prefix-value"`, `"literal"` |
| `:provider-type` | `string` | Provider domain: `"scope"`, `"transform"`, `"source"`, `"option"` |

**Dispatch point:** `router/query_flow.fnl → M.apply-prompt-lines!` — after `parsed` is computed, before session state mutation. Fires once per changed directive key, comparing `parsed[key]` vs `session.last-parsed-query[key]`.

**Examples of when it fires:**
- User types `#file` → `(:on-directive! session :include-files true {:old nil :new true :activated? true :kind "toggle" :provider-type "source"})`
- User removes `#hex` → `(:on-directive! session :hex nil {:old true :new nil :deactivated? true :kind "toggle" :provider-type "transform"})`
- User types `#lgrep` → `(:on-directive! session :lgrep true {:old nil :new true :activated? true :kind "flag" :provider-type "source"})`

## Priority Conventions

| Range | Usage |
|-------|-------|
| 1–19 | Critical setup (must happen before anything else) |
| 10 | Airline disable, heavy buffer plugin disable |
| 20–39 | Role-specific setup (prompt pairs, preview markers) |
| 30 | CMP disable |
| 40–60 | Default range. Bare functions get 50. |
| 70–89 | Teardown restore (re-enable things) |
| 80 | Hlsearch clear/restore |
| 90 | Airline re-enable |
| 90–100 | Final cleanup |

## Event Bus API (`events.fnl`)

### `(events.send event-name args)` — Raw dispatch

Run all handlers for `event-name` in priority order. Checks `:role-filter` against `args`. Each handler is pcall-wrapped.

### `(events.register! mod)` — Runtime registration

Register an external module's `:events` at runtime. Re-sorts handler lists after insertion. For user compat plugins or dynamic extensions.

### `(events.registered-events)` — Introspection

Returns sorted list of event names that have at least one handler.

### `(events.handlers-for event-name)` — Introspection

Returns the sorted handler list for an event, or nil.

### `(events.set-profile! enabled)` — Profiling

Enable or disable per-handler timing logs. When enabled, every dispatched handler logs to the debug log file (`/tmp/metabuffer-debug.log` by default, requires `vim.g["meta#debug"] = true`):

```
[event-bus] :on-buf-create!  compat/buffer-plugins  p=10  42.3µs
[event-bus] :on-buf-create!  compat/cmp             p=30  18.7µs
[event-bus] :on-win-create!  compat/airline          p=10  5.1µs  ERR: some error
[event-bus] :on-query-update!  transform/hex         p=50  120.8µs
```

Each line shows: event name, domain/module, handler priority, wall-clock elapsed microseconds (via `vim.uv.hrtime`), and an `ERR:` suffix if the handler pcall failed.

Enable from Lua:
```lua
vim.g["meta#debug"] = true  -- required: turns on debug logging
require("metabuffer.events").set_profile(true)
```

## Builtin Modules

### `airline.fnl`
Disables `w:airline_disable_statusline` on Meta windows, re-enables on teardown.
- `:on-win-create!` priority 10
- `:on-win-teardown!` priority 90

### `buffer_plugins.fnl`
Disables conjure, LSP, gitgutter, gitsigns, diagnostics on all Meta buffers. Disables auto-pairs/endwise/cmp on prompt. Marks preview buffer.
- `:on-buf-create!` — 3 handlers at priorities 10, 20 (prompt-only), 20 (preview-only)

### `cmp.fnl`
Disables nvim-cmp on prompt buffer via API + buffer-local flag. Re-disables on InsertEnter.
- `:on-buf-create!` priority 30, role-filter `:prompt`
- `:on-insert-enter!` priority 30

### `hlsearch.fnl`
Clears hlsearch on session start/cancel/restore, restores on accept.
- `:on-session-start!` priority 80
- `:on-accept!` priority 80
- `:on-cancel!` priority 80
- `:on-restore-ui!` priority 80

### `rainbow.fnl`
Deactivates rainbow_parentheses on Meta buffers, reactivates on teardown.
- `:on-buf-create!` priority 30
- `:on-buf-teardown!` priority 70

## Adding a New Compat Module

1. Create `fnl/metabuffer/compat/my_plugin.fnl`
2. Return `{:events {:<event> <spec>}}` — no `M` table
3. Add `(local my-plugin (require :metabuffer.compat.my_plugin))` to `init.fnl`
4. Call `events.register!` from `init.fnl`
5. Lint with `make check-fnl -- fnl/metabuffer/compat/my_plugin.fnl`

## User Extension (Runtime)

Users can register handlers from their config without touching compat files:

```lua
local events = require("metabuffer.events")
events.register({
  events = {
    ["on-session-start!"] = function(args)
      -- custom startup logic
    end,
    ["on-buf-create!"] = {
      handler = function(args) ... end,
      priority = 40,
      role_filter = { "prompt" },
    },
  },
})
```
