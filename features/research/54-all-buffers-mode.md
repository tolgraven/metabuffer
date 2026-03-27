# All-Buffers Project Mode

## Overview

An alternative to file-tree project mode that searches only loaded Neovim buffers instead of the filesystem. This includes all open buffers plus special buffer types like terminal windows, quickfix, help pages, plugin windows, and diagnostic output.

## Problem Statement

Current project mode (`Meta!`) searches all files under the project root recursively. This is powerful for codebase-wide searches but expensive for:

1. Large monorepos or vendor directories
2. Workflows where the user wants to search only buffers they've already opened/loaded
3. Terminal output, plugin-generated buffers (LSP hover, debugger), or dynamically-created content

An all-buffers mode lets users quickly filter across their working set without filesystem overhead.

## Design Principles

1. **Complementary to existing modes**: A new source backend, not a replacement for project mode
2. **Inclusive by default**: Include all buffer types (terminal, quickfix, help, floating, etc.) rather than restrictive filters
3. **Respect buffer properties**: Extract readable content from terminal buffers, preserve line mappings for plugin-generated content
4. **Same UX surface**: Use the existing prompt/matcher/transform pipeline, only swap the source backend
5. **Low overhead**: Enumerate only open buffers, no filesystem walk or lazy streaming needed

## Buffer Classification

### Included Buffer Types

#### Text Buffers (Normal)
- Regular file buffers (`:buffer` or `:e file.txt`)
- Modified but unsaved buffers
- Buffers with no backing file (temporary scratch buffers)
- **Line tracking**: Direct 1:1 mapping to buffer line numbers

#### Terminal Buffers
- `:terminal` spawned processes
- Terminal emulator output (`:term bash`, `:term watch`, etc.)
- **Content extraction**: Read-only snapshot of visible terminal scrollback
- **Line tracking**: Map terminal lines to their logical positions within the scrollback
- **Caveats**: Terminal content may contain control characters; consider applying `#strings` transform for binary-like output

#### Plugin-Generated Buffers
- LSP hover floats
- Debugger variable/stack inspection windows
- Plugin query results (e.g., `telescope`, `fzf`)
- **Line tracking**: Preserve buffer line numbers as-is
- **Read-only concern**: Many are unlisted or read-only; treat as source-only (no writeback)

#### Special Buffer Types
- **Quickfix** (`buftype=quickfix`): Include lines; map to file:line references in source-refs
- **Help** (`buftype=help`): Include Neovim help pages as searchable content
- **Diagnostic floats**: Include if listed or visible
- **Messages/command output**: Include if buffered in a buffer

### Excluded Buffer Types

By default, exclude:

- **Unlisted buffers** (`buflisted=false`): Most plugin internals, empty scratch buffers
  - Rationale: These are typically transient or UI scaffolding
  - Opt-in: Consider a toggle like `#-unlisted` to include them
- **Unmodifiable buffers** that are also `readonly=true` and have no path
  - Rationale: Likely read-only reference buffers (e.g., Lua debug tables)
  - Rationale: Write-back will fail; avoid confusion
- **Buftype special** like `dir`, `prompt`, `nofile`
  - Rationale: These are UI containers, not content to search
  - **Exception**: Some (`nofile` with actual text) might be useful; consider a config toggle

## Implementation Strategy

### Source Backend Architecture

New source provider module: `fnl/metabuffer/source/buffers.fnl` (parallel to `text.fnl`, `file.fnl`, `lgrep.fnl`)

```fennel
(fn active?
  [parsed]
  "Return true when buffers source is active (e.g., parsed.buffers = true)")

(fn collect-source-set
  [settings parsed canonical-path]
  "Enumerate all open buffers, extract content, build {:content [...] :refs [...]}")

(fn apply-write-ops!
  [ops]
  "Apply write ops. For terminal/readonly buffers, gracefully skip.")
```

### Directive Activation

Two options for user-facing activation:

#### Option A: Directive-based (`#buffers` or `#buf`)
```vim
:Meta
# then in prompt:
#buffers foo
# searches all loaded buffers for 'foo'
```

Pros:
- Consistent with `#file`, `#lgrep` pattern
- Can be combined with other directives
- Same session, switchable mid-query

Cons:
- Less discoverable; requires knowing the directive
- User must remember the syntax

#### Option B: Separate Command (`:MetaBuffers`)
```vim
:MetaBuffers
# or
:MetaBuffers [query]
```

Pros:
- More discoverable (appears in command list)
- Familiar ergonomics (like `:Meta` vs `:MetaResume`)

Cons:
- Duplicates command registration logic
- Creates two entry points instead of one unified flow

**Recommendation**: Start with directive (`#buffers` or `#buf`), short-alias `#b` to match `#f` for file mode. This fits the existing directive registry and keeps the codebase DRY. Can add `:MetaBuffers` command wrapper later if UX testing suggests it's needed.

### Integration with Existing Query Flow

1. **Directive parsing** (`fnl/metabuffer/query/directive.fnl`): Register new directive handler
2. **Source routing** (`fnl/metabuffer/source/init.fnl`): Add buffers provider to source registry
3. **Session state**: Track active buffer set to detect changes (buffer creation/deletion between queries)
4. **Debounce**: No special debounce needed (buffers enumeration is fast, no external tool)

### Key Implementation Details

#### Content Collection (`collect-source-set`)

```lua
-- Pseudocode
for buf in vim.api.nvim_list_bufs() do
  if buffer_should_include(buf) then
    lines = extract_content(buf)
    for idx, line in ipairs(lines) do
      content:insert(line)
      refs:insert({
        buf = buf,
        path = vim.api.nvim_buf_get_name(buf),
        lnum = idx,
        kind = buffer_kind(buf),  -- "terminal", "quickfix", "text"
        bufilisted = vim.bo[buf].buflisted,
        readonly = vim.bo[buf].readonly,
      })
    end
  end
end
```

#### Terminal Content Extraction

Terminal buffers require special handling:

```fennel
(fn extract-terminal-content
  [buf]
  "Read terminal scrollback into line array. Return {:lines [...] :metadata {...}}"
  (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
        scrollback-size (or settings.terminal-scrollback-lines 1000)]
    {:lines (vim.list_slice lines (- (# lines) scrollback-size) -1)
     :kind "terminal"}))
```

Caveats:
- Terminal buffers may contain ANSI color codes; consider an optional transform to strip them
- Control characters may be present; document that transforms like `#strings` help filter noise

#### Write-Back Behavior

For terminal/quickfix/readonly buffers:

1. **Read-only terminal**: Skip write ops silently (no error)
2. **Modified unsaved text buffer**: Apply writes normally, prompt to save if needed
3. **Quickfix**: Map back to source file and line; apply writes there if possible
4. **Help**: Skip writes (read-only by nature)

Implementation in `apply-write-ops!`:

```fennel
(if (. ref :readonly)
    (do
      ;; Log skipped writes but don't error
      (debug-log :skipped-readonly-buf ref.path)
      {:wrote false :changed 0})
    ;; For normal/file-backed buffers, proceed as in text.fnl
    (text.apply-write-ops! ops))
```

## UX Flow

### User Workflow 1: Current Project + All Buffers Fallback

```vim
" User opens some files, reads help, opens a terminal output"
:e src/main.fnl
:terminal
:help :Meta

" User wants to search across everything they have loaded:"
:Meta
#buffers pattern

" Results show terminal output, help sections, and file buffers mixed"
```

### User Workflow 2: Filtering Out Terminal Noise

```vim
:Meta
#buffers pattern #strings  " Decode/extract printable strings from terminal output"

" Or if terminal is too noisy:"
:Meta
#buffers pattern #-unlisted  " Exclude unlisted plugin buffers"
```

### User Workflow 3: Mixed Project + Buffers

```vim
" User has several files open but wants the full project context too:"
:Meta!   " Full project mode as before"

" But if they want only loaded buffers:"
:Meta
#buffers
```

## Configuration Options

Add to `fnl/metabuffer/config.fnl`:

```fennel
(set defaults
  {...
   :buffer-search-options {:include-unlisted false
                          :include-help true
                          :include-quickfix true
                          :include-terminal true
                          :terminal-scrollback-lines 1000}})
```

Users can override:

```lua
require("metabuffer").setup({
  options = {
    buffer_search_options = {
      include_unlisted = true,
      terminal_scrollback_lines = 500,
    },
  },
})
```

## Performance & Limits

- **Enumeration**: `vim.api.nvim_list_bufs()` is O(n) where n = number of open buffers (typically < 50)
- **Content extraction**: Linear read of each buffer's lines; terminates early on large buffers (e.g. >10k lines)
- **No lazy streaming needed**: Unlike project mode, buffer enumeration is instant
- **Memory**: Entire buffer content loaded into meta.buf.content; consider a soft cap (e.g., 100k total lines across all buffers)

Recommendation: Cap total lines to 100,000 and warn user if limit is approached.

## Filtering & Transforms

All existing transforms apply seamlessly:

- `#json` on JSON plugin output
- `#b64` on encoded terminal output
- `#strings` to extract readable text from binary terminal output
- `#regex`, `#fuzzy` matchers as usual

New transform to consider:

- `#ansi-strip`: Remove ANSI color codes from terminal output (low priority; can be user-custom)

## Interaction with Existing Modes

### With Single-Buffer Mode (default `:Meta`)
- Single buffer mode is the baseline (current buffer only)
- `#buffers` directive switches to all-buffers mode
- Selection/editing works as before

### With Project Mode (`:Meta!`)
- Project mode is unaffected; `#buffers` doesn't apply in project context
- If user wants to combine (e.g., "search current buffers AND project files"), that's a future enhancement; for now, they're exclusive

### With Query Sources (`:lgrep`, `:file`)
- Query sources (`#lgrep`, `#file`) are orthogonal; can't combine with `#buffers`
- Rationale: Query sources redefine the content pool; buffers mode is a content pool itself

## Activation Command Options

Three paths to implement, recommend **Option A** as the minimal viable feature:

### Option A: Directive only (minimal)
- `:Meta` + `#buffers pattern`
- Single entry point, no new commands
- Pros: Simple, fits existing architecture
- Cons: Slightly less discoverable

### Option B: Directive + convenience command
- Directive as above
- Add `:MetaBuffers [query]` command that expands to `:Meta` + `#buffers [query]`
- Pros: Familiar command ergonomics
- Cons: Adds command bloat; consider later

### Option C: Button/keybind to toggle
- After project mode's `<C-t>` pattern, add a buffer-mode toggle
- Pros: Discoverable via help
- Cons: Requires UI state tracking; more complex

## Testing Strategy

Unit tests (`tests/unit/`):
- `test_buffers_source_unit.lua`: Test `collect-source-set`, `apply-write-ops!` with mock buffers
- Terminal content extraction with ANSI codes
- Write-back behavior for read-only buffers

Integration tests (`tests/screen/`):
- `test_buffers_mode.lua`: Smoke test opening multiple buffers, querying with `#buffers`, selecting results
- `test_buffers_terminal_output.lua`: Terminal buffer search and content preservation
- `test_buffers_write_back.lua`: Modify result from terminal buffer, verify no error

## Alternatives Considered

1. **Always-on in single-buffer mode**: Auto-include loaded buffers instead of just current buffer
   - Rejected: Too invasive; breaks user expectation that `:Meta` = current buffer
2. **New `:MetaProject` subcommand**: Like `:MetaResume` but for buffers
   - Rejected: Adds command surface; directive is more flexible
3. **Separate UI for buffer vs. file results**: Color-code or separate panes
   - Deferred: Can add later if UX calls for it; start with unified view

## Edge Cases & Open Questions

1. **Buffer reloading mid-session**: If buffer is reloaded/deleted while meta session active, what happens?
   - Answer: Session tracks buffer IDs; if buffer is invalid, skip on render. No crash.

2. **Very large terminal buffers**: Should we truncate terminal scrollback?
   - Answer: Yes, configurable cap (default 1000 lines). Warn user if approaching limit.

3. **LSP hover floats**: Include or exclude?
   - Answer: Include if visible and listed; respect user's buffer list state
   - Config option to exclude all floating windows if desired

4. **Modifying terminal output, then accepting**: Does the terminal buffer get "written"?
   - Answer: Terminal buffers are flagged `readonly`; writes are silently skipped
   - Future: Could support "export modified terminal output to file" as a special action

5. **Quickfix results**: Include entry's context or just the file:line reference?
   - Answer: Include full quickfix buffer lines as-is; refs map to original file
   - Writeback: If user modifies quickfix line text, changes propagate to original file

## Future Extensions (Out of Scope)

1. **Buffer-of-buffers mode** (`#all-buffers-metadata`): Show buffer names, types, sizes instead of content
2. **Buffer history**: Search closed buffers that were recently open
3. **Cross-Tmux**: Search tmux pane history (as per feature #21, complementary)
4. **Selective buffer inclusion**: `#buffers:main,alt` to search only specific named buffers

## Summary

The all-buffers mode is a lightweight, complementary source backend that:

- Searches loaded Neovim buffers (text, terminal, quickfix, help, etc.)
- Activated via `#buffers` directive or future `:MetaBuffers` command
- Reuses all existing transforms, matchers, and writeback logic
- Handles edge cases (readonly, terminal scrollback, quickfix mapping)
- Provides fast, zero-friction searching of the user's working set

Implementation effort is low (new source provider module + directive handler + tests). Feature complexity is manageable (buffer enumeration and content extraction are straightforward). UX impact is high (users can now search their working set without full project mode overhead).
