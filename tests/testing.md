# Metabuffer Test Suites

This repo now has two parallelized suites:
- Screen/integration tests in `tests/screen/`
- Unit tests in `tests/unit/`

## Running

- Full run (screen + unit, parallel workers):
  - `./scripts/test-mini.sh`
- Full run with profiling:
- `./scripts/test-mini.sh --profile`
  - runner prints the persistent `/tmp/...` profile directory and each worker profile file path
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
- Rerun only previously failing files:
  - `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`

Runner behavior:
- Discovers `tests/**/test_*.lua`.
- Executes files concurrently in separate headless Neovim instances.
- Defaults to oversubscribing workers for these mostly wait-heavy screen tests:
  - default jobs = `min(test_files, TEST_MAX_JOBS or (cpu_count * 2), cpu_count * (TEST_JOBS_MULTIPLIER or 1) + (TEST_JOBS_EXTRA or 2))`
- Isolates each worker via `NVIM_APPNAME`.
- Prints file start/end, case names from MiniTest, and total elapsed ms.
- Prints a sorted per-file timing summary after each run.
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

### `tests/screen/project/test_screen_project_restore_view.lua`
- Project bootstrap keeps the startup-selected result at the same viewport offset.
- Guards against post-startup restores pushing the selected line toward the top.

### `tests/screen/project/test_screen_project_profile_scroll.lua`
- Profile-oriented scroll benchmark coverage for both `"native"` and `"mini"` backends.
- Uses dedicated benchmark spans so `--profile` output shows backend cost directly.

### `tests/screen/project/test_screen_project_flags_core_*.lua`
- `#hidden/#deps/#nolazy` consumption + status/debug reflection.
- `#binary/#hex` visibility and toggle-state reflection.

### `tests/screen/project/test_screen_project_file_mode_file_entries.lua`
- `#file <token>` file-entry activation and file-only result sets.

### `tests/screen/project/test_screen_project_file_mode_rename.lua`
- Straight edits on file-entry rows rename only the targeted file path.

### `tests/screen/edit/test_screen_edit_propagation.lua`
- In-place line replacements from results edit mode write back to the owned source line only.
- Replacement writeback preserves overall project line totals.

### `tests/screen/edit/test_screen_edit_structural_writeback.lua`
- Contiguous plain-buffer edits patch the real file region in place.
- Sparse project inserts from `o`/`O`/`p`/`P` anchor to exactly one owned source line and leave other files untouched.
- Inserted sparse result rows accept to the new source line and survive jump-list return back into Meta.

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

### `tests/screen/persistence/test_screen_persistence_statusline_restore.lua`
- Closing Meta restores the original window-local `statusline` and `winhighlight`.

### `tests/screen/persistence/test_screen_persistence_cursor_word.lua`
- `:MetaCursorWord` seeds the prompt and leaves insert at the end so new typing appends after the current word.

### `tests/screen/persistence/test_screen_persistence_plain_launch.lua`
- Plain `:Meta` launch opens a live session with prompt and info window on a normal buffer.

### `tests/screen/persistence/test_screen_persistence_external_split_pause.lua`
- Opening unrelated windows like `:help` hides Meta auxiliary UI instead of floating over the new split.

### `tests/screen/persistence/test_screen_persistence_existing_split_no_pause.lua`
- Moving to an already existing split does not hide Meta UI.

### `tests/screen/persistence/test_screen_persistence_history_commands_*.lua`
- `:Meta !!` and `:Meta !$` history expansion.
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
- Saved/history command token parsing.
- Escaped control token behavior.
- Multi-line parse behavior and active-query detection.
- Custom prefix option token parsing.

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
- Extra debounce while project lazy stream is still active.

### `tests/unit/test_query_flow_unit.lua`
- Filter-cache invalidation when project flags transition.
- Project source refresh on query text broadening with prefilter enabled.

### `tests/screen/project/test_screen_project_mode_churn.lua`
- Rapid matcher/case/syntax toggles while lazy project loading is active.
- Confirms query and hit state settle after mode churn.

### `tests/screen/history/test_screen_history_browser.lua`
- Saved prompt browser activation via `##`.
- Keyboard navigation and accept flow restore selected saved query.
