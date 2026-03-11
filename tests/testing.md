# Metabuffer Test Suites

This repo now has two parallelized suites:
- Screen/integration tests in `tests/screen/`
- Unit tests in `tests/unit/`

## Running

- Full run (screen + unit, parallel workers):
  - `./scripts/test-mini.sh`
- Override worker count:
  - `TEST_JOBS=4 ./scripts/test-mini.sh`
- Rerun a single file:
  - `TEST_ONLY='tests/unit/test_query_unit.lua' ./scripts/test-mini.sh`
- Rerun only previously failing files:
  - `TEST_FAILED_ONLY=1 ./scripts/test-mini.sh`

Runner behavior:
- Discovers `tests/**/test_*.lua`.
- Executes files concurrently in separate headless Neovim instances.
- Isolates each worker via `NVIM_APPNAME`.
- Prints file start/end, case names from MiniTest, and total elapsed ms.
- Returns non-zero if any file has failing cases.

## Screen Tests

Shared helpers:
- `tests/screen/support/screen_helpers.lua`

Key helper coverage:
- Real-typing simulation with per-character delay.
- Delayed token typing for special keys.
- Session probes (query/hits/matcher/case/statusline/info window/selection/prompt height).

### `tests/screen/test_screen_matchers_basic.lua`
- Prompt edit hotkeys (`<C-a>`, `<C-e>`, `<C-u>`, `<C-y>`).
- Fuzzy mode switching and non-contiguous matching.
- Regex mode filtering and broaden-after-delete behavior.
- Main-window navigation and statusline liveness.

### `tests/screen/test_screen_matchers_edges.lua`
- Unclosed regex-like tokens treated as literals in `all` matcher.
- Negation filtering + broadening on deletion.
- Escaped `#` control-like token stays literal.

### `tests/screen/test_screen_project_filtering.lua`
- Project mode immediate typing during lazy stream.
- Clear-query broadening while preserving source pool.

### `tests/screen/test_screen_project_flags.lua`
- `#hidden/#deps/#nolazy` consumption + status/debug reflection.
- `#file <token>` consumption and file-entry hit activation.

### `tests/screen/test_screen_project_info_sync.lua`
- Hit-buffer and info-window sync/alignment while typing/deleting.

### `tests/screen/test_screen_project_deps_toggle.lua`
- Deterministic deps toggle transitions (`#deps`, `#-deps`).

### `tests/screen/test_screen_persistence_resume.lua`
- `:Meta <query>` immediate application.
- Prompt height persistence across invocations.
- Accept + `MetaResume` restores query/modes.

### `tests/screen/test_screen_persistence_history.lua`
- `:Meta !!` and `:Meta !$` history expansion.
- `<CR>` from results opens selected hit correctly.

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

### `tests/unit/test_prompt_timing_unit.lua`
- Debounce timing by query length (1/2/3+ chars).
- Prompt delay scaling by result pool size thresholds.
- Extra debounce while project lazy stream is still active.

### `tests/unit/test_query_flow_unit.lua`
- Filter-cache invalidation when project flags transition.
- Project source refresh on query text broadening with prefilter enabled.

### `tests/screen/test_screen_project_mode_churn.lua`
- Rapid matcher/case/syntax toggles while lazy project loading is active.
- Confirms query and hit state settle after mode churn.

### `tests/screen/test_screen_history_browser.lua`
- Saved prompt browser activation via `##`.
- Keyboard navigation and accept flow restore selected saved query.
