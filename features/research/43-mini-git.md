# Research: Using mini.nvim Git Features in metabuffer (#43)

## Overview

This document investigates whether and how metabuffer should adopt git features from mini.nvim (specifically `mini.git` and `mini.diff`) to enhance or replace our current Git integration. The analysis covers what each module offers, how it compares to our existing approach, and provides a recommendation.

## Current State of metabuffer Git Integration

### file_info.fnl - Git Status and Blame

**Location:** `fnl/metabuffer/source/file_info.fnl` (458 lines)

Our git integration currently handles:

1. **File Status via `git-file-status()`**
   - Uses `git status --porcelain` to determine file state
   - Returns one of: `"clean"`, `"untracked"`, `"staged"`, `"dirty"`, `"staged+dirty"`, `"changed"`
   - Used in the info float to display file state metadata

2. **Commit Information via `git-last-commit-info()`**
   - Uses `git log -1 --format=%cr%x09%an -- <file>` to get age and author
   - Returns relative age (e.g., "2 days") and author name
   - Cached per file with mtime-based invalidation

3. **Line-Level Blame via `git-line-blame-info()` and async range variant**
   - Uses `git blame --line-porcelain` to get author and timestamp per line
   - Two paths:
     - Synchronous: `git-line-blame-info()` for single lines
     - Asynchronous: `M.ensure-line-meta-range-async!()` for batch line ranges
   - Parsed from blame output to extract author and author-time
   - Results cached per line with mtime-based invalidation

4. **Author Highlighting via `author_highlight.fnl`**
   - 24 predefined highlight groups (`MetaAuthor1` through `MetaAuthor24`)
   - Uses DJB2 hash function to distribute authors across groups
   - Provides `M.group-for-author()` to get consistent highlight group per author

5. **Relative Age Formatting**
   - Compact display: "2m" (minutes), "3h" (hours), "4d" (days), "2w" (weeks), "3mo" (months), "1y" (years)
   - Two implementations:
     - `compact-relative-age()` for parsing Git's age text (e.g., "2 days ago")
     - `compact-relative-age-from-epoch()` for computing from Unix timestamp

### Integration Points

- **Info float (`window/info.fnl`)**: Displays file metadata (mtime, git age, author) and per-line blame info
- **Status signs (`M.file-status-sign()`)**: Shows visual indicators for file state (clean, untracked, dirty)
- **Highlighting**: Age-based highlights (minute/hour/day/week/month/year) and author-based highlights
- **Caching strategy**: Three levels of cache:
  - `session.info-file-head-cache` - first file line
  - `session.info-file-meta-cache` - file metadata
  - `session.info-line-meta-cache` - per-line blame
  - `session.info-file-status-cache` - async file status
  - `session.info-line-meta-pending` - pending async requests

### Performance Characteristics

- **Synchronous calls blocked on Git**: `git-file-status()`, `git-last-commit-info()`, `git-line-blame-info()` all use `vim.fn.systemlist()` (blocking)
- **Async only for line ranges**: `M.ensure-line-meta-range-async!()` uses `vim.system()` with scheduled callback
- **Caching reduces redundancy**: Mtime-based validation prevents unnecessary re-fetches
- **Scalability concern**: Per-line blame in large projects could require many Git calls even with caching

## What mini.git Offers

**Module:** `mini.git` (Git integration for mini.nvim)

### Core Features

1. **Buffer-Local Git Data Tracking**
   - Automatically tracks Git metadata per buffer
   - Exposes via `vim.b.minigit_summary` table with:
     - `head_name` - current branch/HEAD reference
     - `root` - repository root path
     - File status (tracked/untracked/staged/dirty)
   - Also provides `vim.b.minigit_summary_string` for statusline use
   - Updates triggered by `MiniGitUpdated` User event

2. **`:Git` Command**
   - Generic wrapper for `git` CLI with Neovim integration
   - Intelligent output handling:
     - Data commands (log, status, blame) show in split window
     - Action commands (commit, push) show as notifications
     - Errors/warnings always as notifications
   - Supports command modifiers (`:vertical`, `:horizontal`, `:tab`, `:silent`)
   - Interactive editor support for commands like `:Git commit` or `:Git rebase --interactive`
   - Context-aware completion (branches, tags, paths, subcommand options)
   - Executes in file's Git repo root automatically

3. **History Navigation Functions**
   - `MiniGit.show_range_history()` - shows how line range evolved
   - `MiniGit.show_diff_source()` - shows file state at diff entry
   - `MiniGit.show_at_cursor()` - context-aware Git data inspection
   - Integrates with `:Git log` output for exploration

4. **Events**
   - `MiniGitUpdated` - after buffer data updates
   - `MiniGitCommandDone` - after `:Git` command execution
   - `MiniGitCommandSplit` - after `:Git` shows output in split
   - Event callbacks receive structured `data` table with command details

### Design Philosophy

- Lightweight integration focused on current-buffer context
- Does NOT aim to replace full Git client (tpope/vim-fugitive, NeogitOrg/neogit)
- Provides Lua table API for scripting rather than just statusline strings
- Respects repository-aware execution and error handling

## What mini.diff Offers

**Module:** `mini.diff` (Work with diff hunks)

### Core Features

1. **Per-Buffer Diff Visualization**
   - Computes difference between buffer text and reference (default: Git index)
   - Updates incrementally as you type (debounced, default 200ms)
   - Two visualization styles:
     - Sign column: colored signs (configurable, default "▒")
     - Line numbers: colored line numbers (better integration with 'number' option)
   - Highlight groups for each hunk type (add, change, delete)

2. **Overlay View**
   - Togglable with `MiniDiff.toggle_overlay()`
   - Shows deleted reference lines as virtual lines
   - Word-diff for change hunks with equal buffer/reference line counts
   - Context highlighting for understand what changed

3. **Hunk Management**
   - Apply hunks (stage in Git context)
   - Reset hunks (restore from reference)
   - Navigate hunks (first/prev/next/last)
   - "Hunk range under cursor" as textobject for operators
   - Dot-repeatable operations

4. **Extensible Source System**
   - Default Git source watches `.git/index` for changes
   - Can attach multiple sources; first successful attach wins
   - Custom sources define:
     - `attach()` - how to update reference text
     - `detach()` - cleanup
     - `apply_hunks()` - how to apply/stage changes
     - `name` - source identifier

5. **Buffer-Local Summary**
   - `vim.b.minidiff_summary` table with:
     - `source_name` - active source
     - `n_ranges` - number of hunk ranges
     - `add`, `change`, `delete` - line counts per type
   - `vim.b.minidiff_summary_string` for statusline
   - `MiniDiffUpdated` User event for customization

### Configuration

- Diff algorithm: "histogram" (or other vim.diff options)
- Indent heuristic: enabled by default
- Linematch: 60 (threshold for second-stage diff)
- Wrap hunk navigation: disabled by default

## Comparison Matrix

| Feature | Current (file_info.fnl) | mini.git | mini.diff | Notes |
|---------|-------------------------|----------|-----------|-------|
| **File Status** | ✓ (sync via git status) | ✓ (buffer-local cache) | ✗ | mini.git caches repo-level; ours is per-file |
| **File Blame/Author** | ✓ (line and file level) | ✗ | ✗ | Unique to metabuffer use case |
| **Relative Age** | ✓ (compact format) | ✗ | ✗ | Custom implementation in metabuffer |
| **Line-Level Blame Async** | ✓ | ✗ | ✗ | Async handling for performance |
| **Per-Line Caching** | ✓ (mtime-based) | ✗ | ✗ | metabuffer-specific optimization |
| **Git Command Wrapper** | ✗ | ✓ (rich :Git) | ✗ | Not relevant to metabuffer's blame display |
| **Diff Visualization** | ✗ | ✗ | ✓ (hunks + overlay) | Out of metabuffer's current scope |
| **Hunk Apply/Reset** | ✗ | ✗ | ✓ | Out of metabuffer's current scope |
| **History Navigation** | ✗ | ✓ (:Git log + show_at_cursor) | ✗ | Not relevant to current metabuffer scope |

## Pros of Adopting mini.git

1. **Reduced Custom Git Integration**
   - Offload Git data tracking and caching to a maintained library
   - Benefit from bug fixes and improvements in mini.git without manual updates

2. **Buffer-Local Variable API**
   - Standard, well-known interface (`vim.b.minigit_summary`)
   - Other plugins can integrate with the same data
   - Statusline integration is cleaner

3. **Repository Context Awareness**
   - mini.git handles Git root discovery and execution context
   - No need to manually compute repo root or handle -C flag

4. **User Events for Customization**
   - `MiniGitUpdated` event allows local overrides if needed
   - Better composability with user config

## Cons of Adopting mini.git

1. **Not Purpose-Built for Line-Level Blame**
   - mini.git focuses on repo and file-level data
   - Line-level blame info would need custom implementation anyway
   - Async batching optimization (file_info.fnl) not provided

2. **No Author Highlighting Integration**
   - Would still need `author_highlight.fnl` or equivalent
   - mini.git doesn't provide author bucketing or highlight group mapping

3. **Adds Soft Dependency**
   - metabuffer would require mini.nvim
   - Currently we only optionally depend on mini.animate
   - Increases user setup complexity if mini.nvim not already used

4. **Incomplete Replacement**
   - Would need to keep compact age formatting code
   - Line-level caching strategy is metabuffer-specific
   - No net reduction in complexity; just different dependencies

5. **Loss of Fine-Grained Control**
   - Our synchronous calls are blocked but predictable
   - mini.git's event-driven model adds indirection
   - Cache invalidation logic differs

## Pros of Adopting mini.diff

1. **Out-of-Scope Feature**
   - mini.diff does NOT currently apply to metabuffer's blame display
   - Could be useful for future writeback feature (applying filtered changes)
   - Better option than custom diff handling if we add hunk-level operations

2. **Rich Hunk Information**
   - Automatically tracks added/changed/deleted lines
   - Could enhance info display with hunk context

## Cons of Adopting mini.diff

1. **Not Applicable to Current metabuffer**
   - We don't display diff hunks in the info float
   - We don't apply or reset hunks (currently apply full file edits)
   - Adds overhead with no immediate benefit

2. **Adds Another Soft Dependency**
   - Same concerns as mini.git

3. **Different Reference Model**
   - mini.diff tracks "reference text" (Git index by default)
   - We track "original file state" for writeback
   - Would require custom source integration

## Performance Considerations

### Current Approach (file_info.fnl)

- **Blocking calls:** `git status`, `git log`, `git blame` are synchronous via `vim.fn.systemlist()`
- **Caching:** Three-level cache (file head, file meta, line meta) with mtime validation
- **Async:** Only for batch line-range blame requests via `vim.system()`
- **Scalability issue:** Large files or many files trigger many Git calls

### mini.git Approach

- **Event-driven:** Updates via `MiniGitUpdated` event when Git state changes
- **Caching:** Built-in buffer-local cache, invalidated on Git filesystem changes
- **Polling:** Watches `.git/index` for changes (file watcher not always reliable)
- **Advantage:** Better for repo/file-level data; reduces wasted Git calls

### Recommendation for Performance

Neither approach is optimal for metabuffer's line-level blame use case:
- mini.git is overkill for repository-level tracking we don't use
- Our current approach is simpler for the specific data we need
- Batch async blame (our current `ensure-line-meta-range-async!`) is the right pattern

## Migration Path (If Decided)

If we adopt mini.git for file-level metadata:

1. **Phase 1: Add mini.git as Optional Dependency**
   - Update `README.md` and docs
   - Add to compat system: `compat/minigit.fnl`
   - Register `MiniGitUpdated` event handler if mini.git available

2. **Phase 2: Replace File-Level Git Calls**
   - Remove `git-file-status()` and `git-last-commit-info()` calls
   - Use `vim.b.minigit_summary` for file status
   - Fall back to current implementation if mini.git not available

3. **Phase 3: Keep Line-Level Blame**
   - Retain `git-line-blame-info()` and async batch functions
   - mini.git doesn't provide line-level blame anyway
   - Batch async approach is efficient for our use case

4. **Phase 4: Deprecate Old Functions**
   - Keep dual-path (mini.git + fallback) for 1-2 releases
   - Eventually drop fallback after stable usage

5. **Testing**
   - Add tests for mini.git path and fallback path
   - Verify caching behavior and invalidation
   - Test author highlight integration still works

## Recommendation

**Do NOT adopt mini.git at this time.**

### Rationale

1. **Mismatch Between Needs and Offerings**
   - metabuffer's core Git integration is line-level blame display
   - mini.git provides file/repo-level data but can't be used for what we actually need
   - Only 20-30% of our Git code would benefit from mini.git

2. **Line-Level Blame is Core**
   - `author_highlight.fnl` + line caching is custom and optimized for our use case
   - Async batch blame via `ensure-line-meta-range-async!` is the performance win
   - Neither is provided by mini.git

3. **Added Complexity vs. Benefit**
   - Adds soft dependency on mini.nvim
   - Increases setup burden if user doesn't use mini.nvim
   - Event-based invalidation adds indirection vs. current mtime-based caching

4. **Keep Independence**
   - Current implementation is self-contained and predictable
   - No dependency on another plugin's architecture or event model
   - Easier to reason about caching behavior

### Future Consideration

Revisit if:
- metabuffer adds a Git client mode (like `:GitLog`, `:GitDiff`)
- We need deeper integration with mini.nvim ecosystem
- User feedback indicates Git performance is a bottleneck that mini.git would solve

## Alternative: Incremental Improvements (Recommended)

Instead of adopting mini.git, consider these improvements to current implementation:

1. **Improved Async Batching**
   - Currently batch blame queries per line range
   - Could batch file status checks across multiple files
   - Reduce total number of Git calls per session

2. **Cache Warm-Up**
   - Pre-fetch blame info for visible lines when info float opens
   - Avoid on-demand async delays during user exploration

3. **Source-Aware Optimization**
   - When switching between `#file` and text sources, clear irrelevant caches
   - Only track git info for source matching active context

4. **Compact Format Caching**
   - Cache age format result, not just raw author-time
   - Avoid repeated formatting computation on each render

5. **Documentation**
   - Clarify why we don't use mini.git or fugitive
   - Explain the design trade-offs in AGENTS.md

## References

- **mini.git source:** `lua/mini/git.lua` from https://github.com/nvim-mini/mini.nvim
- **mini.diff source:** `lua/mini/diff.lua` from https://github.com/nvim-mini/mini.nvim
- **Current metabuffer git integration:** `fnl/metabuffer/source/file_info.fnl`, `fnl/metabuffer/author_highlight.fnl`
- **mini.nvim repository:** https://github.com/nvim-mini/mini.nvim (40+ modules, ~8.9k stars)

## Summary Table

| Aspect | Decision | Reason |
|--------|----------|--------|
| **Adopt mini.git?** | ❌ No | Doesn't address line-level blame; adds complexity |
| **Adopt mini.diff?** | ❌ No | Out of scope; no current diff display feature |
| **Keep Current Implementation?** | ✅ Yes | Optimized for metabuffer's specific needs |
| **Improve Incrementally?** | ✅ Yes | Better ROI than major refactoring |

