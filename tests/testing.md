# Metabuffer Test Suites

This repo now has two parallelized suites:
- Screen/integration tests in `tests/screen/`
- Unit tests in `tests/unit/`

## Running

- Full run (screen + unit, parallel workers):
  - `./scripts/test-mini.sh`
- Run without the startup smoke prefix:
  - `./scripts/test-mini.sh --no-smoke tests/unit/test_query_unit.lua`
- Full run with profiling:
  - `./scripts/test-mini.sh --profile`
  - runner prints the persistent `/tmp/...` profile directory and each worker profile file path
- Print a sorted per-file timing summary without full verbose logs:
  - `./scripts/test-mini.sh --timings`
- `make test-profile`
- `make test-profile tests/screen/project/test_screen_project_profile_scroll.lua`
- pass runner flags through `make` with `--`, for example:
  - `make test-profile -- tests/screen/project/test_screen_project_profile_scroll.lua --verbose`
- Use the real metabuffer repo instead of the default generated project fixture:
  - `TEST_REAL_REPO=1 ./scripts/test-mini.sh`
- Enable UI animations inside the headless mini child:
  - `TEST_UI_ANIMATIONS=1 ./scripts/test-mini.sh`
- Override worker count:
  - `TEST_JOBS=4 ./scripts/test-mini.sh`
- Override default oversubscription:
  - `TEST_JOBS_MULTIPLIER=1 ./scripts/test-mini.sh`
  - `TEST_JOBS_EXTRA=4 ./scripts/test-mini.sh`
  - `TEST_MAX_JOBS=16 ./scripts/test-mini.sh`
- Rerun a single file:
  - `./scripts/test-mini.sh tests/unit/test_query_unit.lua`
- Rerun a single smoke file directly:
  - `./scripts/test-mini.sh --no-smoke tests/smoke/test_smoke_plain_launch.lua`
- Run a selected test or category first, then automatically the full suite if it passes:
  - `make test-then-all tests/unit/test_query_unit.lua`
  - `make test-then-all persistence`
  - selected phase skips startup smokes; the full-suite phase still runs them first
  - uses a higher per-file timeout by default (`30000ms`)
  - forces `TEST_JOBS=1` only for the selected-first phase; the full-suite phase uses the normal runner default unless you override it
- Run a whole category/directory:
  - `./scripts/test-mini.sh animation`
  - `./scripts/test-mini.sh edit`
  - `./scripts/test-mini.sh persistence`
  - `./scripts/test-mini.sh project`
  - `./scripts/test-mini.sh screen`
  - `./scripts/test-mini.sh unit`
- Rerun only previously failing files:
  - `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`

Runner behavior:
- Discovers regular suite files under `tests/screen/` and `tests/unit/`.
- Always runs plugin/reload/launch smoke tests first, even for single-file or category runs:
  - `tests/smoke/test_smoke_plugin_source.lua`
  - `tests/smoke/test_smoke_reload_compile.lua`
  - `tests/smoke/test_smoke_plain_headless_launch.lua`
  - `tests/smoke/test_smoke_plain_launch.lua`
  - `tests/smoke/test_smoke_project_headless_launch.lua`
  - `tests/smoke/test_smoke_project_plain_launch.lua`
- `--no-smoke` disables that startup-smoke prefix for the current invocation.
- `--timings` prints the sorted per-file timing summary without enabling verbose worker logs.
- Those startup smoke tests force `TEST_UI_ANIMATIONS=1` so launch-time animation/timer failures are covered even though the rest of the screen suite defaults animations off for determinism.
- Aborts the whole run immediately if either startup smoke test fails.
- Executes files concurrently in separate headless Neovim instances.
- Defaults to oversubscribing workers for these mostly wait-heavy screen tests:
  - default jobs = `min(test_files, TEST_MAX_JOBS or (cpu_count * 2), cpu_count * (TEST_JOBS_MULTIPLIER or 1) + (TEST_JOBS_EXTRA or 2))`
- Isolates each worker via `NVIM_APPNAME`.
- Clears and checks `vim.v.errmsg` / `:messages` for every MiniTest case, including smoke and unit tests.
- Fails a worker if its log contains runtime error signatures even when the test file itself forgot to assert on them.
- Prints file start/end, case names from MiniTest, and total elapsed ms.
- Prints a sorted per-file timing summary after each run when `--timings` or `--verbose` is used.
- Optional profiling (`--profile`) adds per-file and per-case breakdowns for:
  - wall time
  - CPU time
  - blocked time (`wall - CPU`)
  - explicit `wait_for()` time
  - simulated typing sleep time
  - child Neovim startup time
- Returns non-zero if any file has failing cases.

## Screen Tests

Shared helpers:
- `tests/screen/support/screen_helpers.lua`

Key helper coverage:
- Real-typing simulation with per-character delay.
- Delayed token typing for special keys.
- Session probes (query/hits/matcher/case/statusline/info window/selection/prompt height).
- Default generated project fixture with:
  - nested `lua/`, `fnl/`, `doc/`, `deps/`, hidden, ignored, and deeply nested dirs
  - text files containing stable query terms (`meta`, `metam`, `local`, `lua`, `preview-window`, `info-window`)
  - a synthetic binary `metabuffer.png`
  - enough files to exercise lazy project bootstrap without using the full repo
- Animations are disabled by default in screen tests for determinism; opt in with
  `TEST_UI_ANIMATIONS=1` when specifically exercising animation behavior.

### `tests/screen/matchers/test_screen_matchers_basic_*.lua`
- Prompt edit hotkeys (`<C-a>`, `<C-e>`, `<C-u>`, `<C-y>`).
- Fuzzy mode switching and non-contiguous matching.
- Regex mode filtering and broaden-after-delete behavior.
- Main-window navigation and statusline liveness.

### `tests/screen/matchers/test_screen_matchers_edges_*.lua`
- Unclosed regex-like tokens treated as literals in `all` matcher.
- Negation filtering + broadening on deletion.
- Escaped `#` control-like token stays literal.

### `tests/screen/project/test_screen_project_filtering_*.lua`
- Project mode immediate typing during lazy stream.
- Clear-query broadening while preserving source pool.

### `tests/screen/animation/test_screen_animation_*.lua`
- Dedicated animation-on coverage for regular and project launch/scroll paths with the mini backend.

### `tests/screen/project/test_screen_project_restore_view.lua`
- Project bootstrap keeps the startup-selected result at the same viewport offset.
- Guards against post-startup restores pushing the selected line toward the top.

### `tests/screen/project/test_screen_project_profile_scroll.lua`
- Profile-oriented scroll benchmark coverage for both `"native"` and `"mini"` backends.
- Uses dedicated benchmark spans so `--profile` output shows backend cost directly.
- Excluded from the default suite; runs under `--profile` or when selected explicitly.

### `tests/screen/project/test_screen_project_flags_core_*.lua`
- `#hidden/#deps/#nolazy` consumption + status/debug reflection.
- `#binary/#hex/#strings` visibility and toggle-state reflection.
- Binary transforms render real content in the results window (`#hex` hex+ASCII, `#strings` extracted printable chunks).

### `tests/screen/project/test_screen_project_lgrep_basic.lua`
- `:Meta!` `#lg:u` switches project mode over to lgrep-backed refs.
- Selection jumps to the first grouped/scored lgrep hit.
- Plain `#lg` search also jumps to the first search-hit start, not the old source line.
- Info rows for lgrep hits show a non-blank source marker in the sign column.

### `tests/screen/project/test_screen_project_file_mode_file_entries.lua`
- `#file <token>` file-entry activation and file-only result sets.

### `tests/screen/project/test_screen_project_file_mode_rename.lua`
- Straight edits on file-entry rows rename only the targeted file path, both from project `:Meta!` and regular `:Meta` with `#file`.

### `tests/screen/edit/test_screen_edit_propagation.lua`
- In-place line replacements from results edit mode write back to the owned source line only.
- Replacement writeback preserves overall project line totals.

### `tests/screen/edit/test_screen_edit_regular_contiguous_writeback.lua`
- Contiguous plain Meta edits patch the real file region in place.

### `tests/screen/edit/test_screen_edit_regular_filtered_replace_writeback.lua`
- Filtered regular Meta replacements still write back to the owned source file.

### `tests/screen/edit/test_screen_edit_regular_filtered_insert_writeback.lua`
- Filtered regular Meta inserts write back to the owned source file.

### `tests/screen/edit/test_screen_edit_project_insert_writeback.lua`
- Filtered project Meta direct inserts write back without explicit edit-mode bootstrap.

### `tests/screen/edit/test_screen_edit_transform_json_writeback.lua`
- Edited projected JSON rows write back through the reverse transform path, so files stay compact/source-shaped instead of persisting the rendered pretty view.

### `tests/screen/edit/test_screen_edit_transform_custom_writeback.lua`
- Custom shell-backed transforms reverse cleanly on writeback when a `to` command is configured.

### `tests/screen/edit/test_screen_edit_structural_writeback.lua`
- Sparse project inserts from `o`/`O`/`p`/`P` anchor to exactly one owned source line and leave other files untouched.

### `tests/screen/project/test_screen_project_file_mode_binary.lua`
- `-binary` exclusion from file-entry mode.

### `tests/screen/project/test_screen_project_file_mode_shortcut.lua`
- `./query` file shortcut behavior.

### `tests/screen/project/test_screen_project_file_query_split_basic.lua`
- Separation of file tokens from normal query terms.

### `tests/screen/project/test_screen_project_file_query_split_partial.lua`
- `#file` without a file token preserves regular hits.

### `tests/screen/project/test_screen_project_file_query_split_paths.lua`
- File token constrains regular hits by matching paths.

### `tests/screen/project/test_screen_project_flags_clear.lua`
- Clearing file tokens removes stale file-query filtering.

### `tests/screen/project/test_screen_project_info_sync.lua`
- Hit-buffer and info-window sync/alignment while typing/deleting.

### `tests/screen/project/test_screen_project_scroll_sync.lua`
- Animated project scrolling keeps results cursor, selection, and info window aligned.

### `tests/screen/project/test_screen_project_deps_toggle.lua`
- Deterministic deps toggle transitions (`#deps`, `#-deps`).

### `tests/screen/persistence/test_screen_persistence_resume_*.lua`
- `:Meta <query>` immediate application.
- Prompt height persistence across invocations.
- Accept + `MetaResume` restores query/modes.
- Hidden regular sessions restore on `<C-o>` back to the results buffer.
- Hidden sessions are pruned once their results buffer falls out of the jumplist.

### `tests/screen/persistence/test_screen_persistence_statusline_prompt_only.lua`
- Prompt statusline keeps mode/count/key-hint content while the main results statusline only shows runtime state.

### `tests/screen/persistence/test_screen_persistence_lgrep_basic.lua`
- Regular `:Meta` can switch to lgrep-backed refs with `#lg`.
- The lgrep query term is removed from normal filter text and gets mirrored prompt/results highlighting.

### `tests/screen/persistence/test_screen_persistence_wrap_restore.lua`
- Results-window `wrap` persists across regular `:Meta` close/reopen and rebuilds early-rendered source views accordingly.

### `tests/screen/persistence/test_screen_persistence_statusline_restore_basic.lua`
- Cancel and project-cancel restore the original window-local `statusline`, `winhighlight`, and colorcolumn.
- Help-hide cycles still restore the origin window correctly afterward.

### `tests/screen/persistence/test_screen_persistence_statusline_restore_resume.lua`
- Accept from regular Meta restores the origin window, and jumplist resume reapplies Meta window styling.

### `tests/screen/persistence/test_screen_persistence_statusline_restore_plugin.lua`
- Accept/cancel hand statusline control back to statusline-plugin owners on the origin window.

### `tests/screen/persistence/test_screen_persistence_cancel_restore_regular.lua`
- Regular `Esc` hides Meta UI, returns to the origin buffer, and keeps the session resumable via jumplist forward.

### `tests/screen/persistence/test_screen_persistence_cursor_word.lua`
- `:MetaCursorWord` seeds the prompt and leaves insert at the end so new typing appends after the current word.

## Smoke Tests

### `tests/smoke/test_smoke_plain_launch.lua`
- Plain `:Meta` launch opens a live session with prompt and info window on a normal buffer.

### `tests/smoke/test_smoke_reload_compile.lua`
- `require('metabuffer').reload({ compile = true })` succeeds after sourcing the real plugin bootstrap.
- `:Meta` remains defined after reload.
- Guards against broken freshly compiled modules that only fail on reload-time `require()`.

### `tests/smoke/test_smoke_project_plain_launch.lua`
- Plain `:Meta!` launch opens a live project session with prompt and info window.

### `tests/screen/persistence/test_screen_persistence_named_buffers_launch.lua`
- Meta-owned prompt/preview/info/results buffers use stable names instead of showing up as unnamed scratch buffers.
- Preview split creation does not leave stray unnamed buffers behind.

### `tests/screen/persistence/test_screen_persistence_named_buffers_restore.lua`
- Accept/resume and cancel flows do not leave stray unnamed buffers behind.

### `tests/screen/persistence/test_screen_persistence_named_buffers_repeat.lua`
- Repeated `:Meta` launch/hide cycles do not accumulate hidden unnamed buffers.

### `tests/screen/persistence/test_screen_persistence_double_launch_block.lua`
- A second `:Meta` during animated startup is ignored instead of creating a duplicate session/layout.
- `Esc` during animated startup stays hidden after the delayed startup callbacks settle.

### `tests/screen/persistence/test_screen_persistence_treesitter_regular.lua`
- Regular file-backed `:Meta` keeps Tree-sitter highlighting active on the results buffer when a parser is available.

### `tests/screen/persistence/test_screen_persistence_treesitter_autocmd_safe.lua`
- Global `FileType` autocmds that call `vim.treesitter.start()` do not crash Meta startup on preview/info scratch buffers.

### `tests/screen/persistence/test_screen_persistence_external_split_pause.lua`
- Opening unrelated windows like `:help` hides Meta auxiliary UI instead of floating over the new split.

### `tests/screen/persistence/test_screen_persistence_existing_split_no_pause.lua`
- Moving to an already existing split does not hide Meta UI.

### `tests/screen/persistence/test_screen_persistence_history_commands_*.lua`
- `:Meta !!` and `:Meta !$` history expansion.

### `tests/screen/matchers/test_screen_matchers_multiline_or.lua`
- Multiple prompt lines match as OR by default, including direct prompt-buffer multiline updates.
- `<CR>` from results opens selected hit correctly.
- Repeated `!!` insertion does not duplicate payload.

### `tests/screen/persistence/test_screen_persistence_history_project_replay.lua`
- Project history replay preserves non-consumed flags.

### `tests/screen/persistence/test_screen_persistence_history_project_up.lua`
- Up-recall does not accumulate duplicate consumed setting tokens.

### `tests/screen/persistence/test_screen_persistence_history_project_legacy.lua`
- Legacy `#+file` history normalizes to `#file`.

### `tests/screen/persistence/test_screen_persistence_history_recall.lua`
- Minimal replay-only coverage for `Meta !!` after accept.

## Unit Tests

### `tests/unit/test_query_unit.lua`
- `truthy?` semantics.
- Flag token consumption and retained query text.
- `#lg`, `#lg:u`, and `#lg:d` parsing.
- Derived short aliases for scope/source/transform directives.
- Runtime custom transform directives are discovered from the registry, not hardcoded in `query.fnl`.
- Default lgrep promotion from the first token on a line.
- Saved/history command token parsing.
- Escaped control token behavior.
- Multi-line parse behavior and active-query detection.
- Custom prefix option token parsing.

### `tests/unit/test_transform_unit.lua`
- Reversible binary plist transform coverage (`#bplist` XML plist roundtrip back to `bplist00` bytes).
- `#strings` can patch edited extracted strings back into the original binary as rewritten bytes.
- Custom transform filetype gating coverage.
- Custom transforms can choose different `from`/`to` commands by detected filetype.
- Transform toggle resolution and rendered-view expansion for `#hex`, `#b64`, `#bplist`, `#json`, `#xml`, and `#css`.

### `tests/unit/test_matchers_unit.lua`
- `all` matcher literal, negation, anchors, regex-token and highlight behavior.
- Fuzzy matcher non-contiguous matching.
- Regex matcher multi-token intersection and invalid regex handling.

### `tests/unit/test_util_unit.lua`
- Input splitting, regex pattern conversion, escaping, case checks, clamp.

### `tests/unit/test_config_unit.lua`
- Default keymap exposure.
- Nested keymap override resolution.
- Debounce defaults presence.
- Nested `ui.animation` option resolution, legacy aliases, and time-scale math.

### `tests/unit/test_prompt_timing_unit.lua`
- Debounce timing by query length (1/2/3+ chars).
- Prompt delay scaling by result pool size thresholds.

### `tests/unit/test_prompt_hooks_unit.lua`
- `metabuffer.prompt.hooks.new()` returns the expected hook table shape.
- Extra debounce while project lazy stream is still active.

### `tests/unit/test_query_flow_unit.lua`
- Filter-cache invalidation when project flags transition.
- Project source refresh on query text broadening with prefilter enabled.

### `tests/unit/test_lgrep_source_unit.lua`
- Lgrep source collection groups hits by file, sorts by score/file, and expands chunk line numbers into source refs.

### `tests/unit/test_project_source_unit.lua`
- Lazy startup project bootstrap prefers deferred streaming before any prompt query.
- Prefilter is applied before the max-line cap so matching lines survive small caps.
- Transformed views preserve original source line ownership through `line-map`.

### `tests/screen/project/test_screen_project_mode_churn.lua`
- Rapid matcher/case/syntax toggles while lazy project loading is active.
- Confirms query and hit state settle after mode churn.

### `tests/screen/history/test_screen_history_browser.lua`
- Saved prompt browser activation via `##`.
- Keyboard navigation and accept flow restore selected saved query.
