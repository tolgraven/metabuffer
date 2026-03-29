-- [nfnl] fnl/metabuffer/config.fnl
local custom_mod = require("metabuffer.custom")
local M = {}
local default_prompt_keymaps = {{{"n", "i"}, "<CR>", "accept"}, {{"n", "i"}, "<M-CR>", "toggle-prompt-results-focus"}, {{"n", "i"}, "<A-CR>", "toggle-prompt-results-focus"}, {"n", "<Esc>", "cancel"}, {"n", "<C-p>", "move-selection", -1}, {"n", "<C-n>", "move-selection", 1}, {"i", "<C-p>", "move-selection", -1}, {"i", "<C-n>", "move-selection", 1}, {"n", "<C-k>", "move-selection", -1}, {"n", "<C-j>", "move-selection", 1}, {"i", "<C-k>", "move-selection", -1}, {"i", "<C-j>", "move-selection", 1}, {"i", "<C-a>", "prompt-home"}, {"i", "<C-e>", "prompt-end"}, {"i", "<C-u>", "prompt-kill-backward"}, {"i", "<C-y>", "prompt-yank"}, {"i", "<S-CR>", "prompt-newline"}, {"i", "<Up>", "history-or-move", 1}, {"i", "<Down>", "history-or-move", -1}, {"n", "<Up>", "history-or-move", 1}, {"n", "<Down>", "history-or-move", -1}, {"i", "!!", "insert-last-prompt"}, {"n", "!!", "insert-last-prompt"}, {"i", "!$", "insert-last-token"}, {"n", "!$", "insert-last-token"}, {"i", "!^!", "insert-last-tail"}, {"n", "!^!", "insert-last-tail"}, {"i", "<LocalLeader>1", "negate-current-token"}, {"i", "<LocalLeader>!", "negate-current-token"}, {"n", "<LocalLeader>h", "merge-history"}, {"i", "<LocalLeader>h", "merge-history"}, {"i", "<C-r>", "history-searchback"}, {{"n", "i"}, "<C-^>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-6>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-_>", "switch-mode", "case"}, {{"n", "i"}, "<C-/>", "switch-mode", "case"}, {{"n", "i"}, "<C-?>", "switch-mode", "case"}, {{"n", "i"}, "<C-->", "switch-mode", "case"}, {{"n", "i"}, "<C-o>", "switch-mode", "case"}, {{"n", "i"}, "<C-s>", "switch-mode", "syntax"}, {"n", "<C-g>", "toggle-scan-option", "ignored"}, {"n", "<C-l>", "toggle-scan-option", "deps"}, {{"n", "i"}, "<LocalLeader>i", "toggle-info-file-entry-view"}, {{"n", "i"}, "<LocalLeader>r", "refresh-files"}, {{"n", "i"}, "<C-d>", "scroll-main", "half-down"}, {"n", "<C-u>", "scroll-main", "half-up"}, {{"n", "i"}, "<C-f>", "scroll-main", "page-down"}, {{"n", "i"}, "<C-b>", "scroll-main", "page-up"}, {{"n", "i"}, "<C-t>", "toggle-project-mode"}}
local default_main_keymaps = {{"n", "<Esc>", "cancel"}, {"n", "!", "exclude-symbol-under-cursor"}, {"n", "#", "insert-symbol-under-cursor-newline"}, {"n", "<CR>", "accept-main"}, {"n", "<LocalLeader>i", "toggle-info-file-entry-view"}, {"n", "<LocalLeader>r", "refresh-files"}, {"n", "<ScrollWheelDown>", "scroll-main", "line-down"}, {"n", "<ScrollWheelUp>", "scroll-main", "line-up"}, {{"n", "i"}, "<M-CR>", "toggle-prompt-results-focus"}, {{"n", "i"}, "<A-CR>", "toggle-prompt-results-focus"}}
local default_prompt_fallback_keymaps = {{"i", "<C-a>", "prompt-home"}, {"i", "<C-e>", "prompt-end"}, {"i", "<C-u>", "prompt-kill-backward"}, {"i", "<C-k>", "move-selection", -1}, {"i", "<C-y>", "prompt-yank"}}
M.defaults = {options = {history_max = 100, project_max_file_bytes = (1024 * 1024), project_max_total_lines = 500000, project_rg_bin = "rg", project_rg_base_args = {"--files", "--glob", "!.git"}, project_rg_include_ignored_args = {"--no-ignore", "--no-ignore-vcs", "--no-ignore-parent"}, project_rg_deps_exclude_globs = {"!node_modules/**", "!vendor/**", "!deps/**", "!.venv/**", "!venv/**", "!dist/**", "!build/**", "!target/**"}, project_fallback_glob_pattern = "**/*", info_max_lines = 10000, info_min_width = 28, info_max_width = 52, context_height = 14, context_around_lines = 3, context_max_blocks = 24, info_file_entry_view = "meta", prompt_update_debounce_ms = 170, prompt_update_idle_ms = 90, prompt_short_query_extra_ms = {180, 120, 70}, prompt_size_scale_thresholds = {2000, 10000, 50000}, prompt_size_scale_extra = {0, 2, 6, 10}, project_lazy_enabled = true, project_lazy_disable_headless = true, project_lazy_min_estimated_lines = 5000, project_lazy_chunk_size = 4, project_lazy_frame_budget_ms = 6, project_lazy_refresh_debounce_ms = 32, project_lazy_refresh_min_ms = 8, project_lazy_prefilter_enabled = true, project_source_syntax_chunk_lines = 240, project_bootstrap_delay_ms = 120, project_bootstrap_idle_delay_ms = 140, lgrep_bin = "lgrep", lgrep_limit = 80, lgrep_debounce_ms = 260, prompt_forced_coalesce_ms = 700, preview_source_switch_debounce_ms = 60, source_syntax_refresh_debounce_ms = 80, scroll_sync_debounce_ms = 20, ui_animations_enabled = true, ui_animations_time_scale = 1.5, ui_animation_backend = "mini", ui_animation_prompt_enabled = true, ui_animation_prompt_ms = 140, ui_animation_prompt_time_scale = 1, ui_animation_prompt_backend = "mini", ui_animation_preview_enabled = true, ui_animation_preview_ms = 180, ui_animation_preview_time_scale = 1, ui_animation_info_enabled = true, ui_animation_info_ms = 220, ui_animation_info_time_scale = 1, ui_animation_info_backend = "mini", ui_animation_loading_enabled = true, ui_animation_loading_ms = 90, ui_animation_loading_time_scale = 1, ui_loading_indicator = true, ui_animation_scroll_enabled = true, ui_animation_scroll_ms = 100, ui_animation_scroll_time_scale = 1, ui_animation_scroll_backend = "mini", window_local_layout = true, custom = {transforms = {}}, dep_dir_names = {node_modules = true, [".venv"] = true, venv = true, vendor = true, deps = true, dist = true, build = true, target = true, __pycache__ = true, [".mypy_cache"] = true, [".pytest_cache"] = true, [".tox"] = true, [".next"] = true, [".nuxt"] = true, [".yarn"] = true, [".pnpm-store"] = true}, default_include_binary = false, default_include_deps = false, default_include_files = false, default_include_hex = false, default_include_hidden = false, default_include_ignored = false, default_include_lgrep = false}, ui = {custom_mappings = {}, highlight_groups = {All = "Title", Fuzzy = "Number", Regex = "Special"}, syntax_on_init = "buffer", prefix = "#"}, keymaps = {prompt = default_prompt_keymaps, main = default_main_keymaps, prompt_fallback = default_prompt_fallback_keymaps}}
local function table_3f(v)
  return (type(v) == "table")
end
local function nested(opts, k)
  return (table_3f(opts) and table_3f(opts[k]) and opts[k])
end
local function nested_in(root, ks)
  local cur0 = root
  local cur = cur0
  local ok = true
  for _, k in ipairs(ks) do
    if (ok and table_3f(cur) and table_3f(cur[k])) then
      cur = cur[k]
    else
      ok = false
      cur = nil
    end
  end
  return cur
end
local function opt_value(opts, k, legacy_g, default)
  local options = nested(opts, "options")
  if (table_3f(options) and (options[k] ~= nil)) then
    return options[k]
  else
    if (table_3f(opts) and (opts[k] ~= nil)) then
      return opts[k]
    else
      if (legacy_g ~= nil) then
        return (vim.g[legacy_g] or default)
      else
        return default
      end
    end
  end
end
local function nested_value(opts, ks, default)
  local cur0 = opts
  local cur = cur0
  local found = true
  for _, k in ipairs(ks) do
    if (found and table_3f(cur) and (cur[k] ~= nil)) then
      cur = cur[k]
    else
      found = false
      cur = nil
    end
  end
  if found then
    return cur
  else
    return default
  end
end
local function resolve_keymaps(opts)
  local keymaps = nested(opts, "keymaps")
  return {prompt = ((keymaps and keymaps.prompt) or (table_3f(opts) and opts.prompt_keymaps) or vim.g.meta_prompt_keymaps or M.defaults.keymaps.prompt), main = ((keymaps and keymaps.main) or (table_3f(opts) and opts.main_keymaps) or vim.g.meta_main_keymaps or M.defaults.keymaps.main), prompt_fallback = ((keymaps and keymaps.prompt_fallback) or (table_3f(opts) and opts.prompt_fallback_keymaps) or vim.g.meta_prompt_fallback_keymaps or M.defaults.keymaps.prompt_fallback)}
end
local function resolve_ui(opts)
  local ui = nested(opts, "ui")
  local anim = nested_in(opts, {"ui", "animation"})
  return {custom_mappings = ((ui and (ui.custom_mappings ~= nil) and ui.custom_mappings) or vim.g["meta#custom_mappings"] or M.defaults.ui.custom_mappings), highlight_groups = ((ui and (ui.highlight_groups ~= nil) and ui.highlight_groups) or vim.g["meta#highlight_groups"] or M.defaults.ui.highlight_groups), syntax_on_init = ((ui and (ui.syntax_on_init ~= nil) and ui.syntax_on_init) or vim.g["meta#syntax_on_init"] or M.defaults.ui.syntax_on_init), animation = anim, prefix = ((ui and (ui.prefix ~= nil) and ui.prefix) or vim.g["meta#prefix"] or M.defaults.ui.prefix)}
end
local direct_option_specs = {{"history_max", nil}, {"project_max_file_bytes", "meta_project_max_file_bytes"}, {"project_max_total_lines", "meta_project_max_total_lines"}, {"default_include_hidden", "meta_project_include_hidden"}, {"default_include_ignored", "meta_project_include_ignored"}, {"default_include_deps", "meta_project_include_deps"}, {"default_include_binary", "meta_project_include_binary"}, {"default_include_hex", "meta_project_include_hex"}, {"default_include_files", "meta_project_include_files"}, {"default_include_lgrep", "meta_default_include_lgrep"}, {"project_rg_bin", "meta_project_rg_bin"}, {"project_rg_base_args", "meta_project_rg_base_args"}, {"project_rg_include_ignored_args", "meta_project_rg_include_ignored_args"}, {"project_rg_deps_exclude_globs", "meta_project_rg_deps_exclude_globs"}, {"project_fallback_glob_pattern", "meta_project_fallback_glob_pattern"}, {"info_max_lines", "meta_info_max_lines"}, {"info_min_width", "meta_info_width"}, {"info_max_width", "meta_info_max_width"}, {"context_height", "meta_context_height"}, {"context_around_lines", "meta_context_around_lines"}, {"context_max_blocks", "meta_context_max_blocks"}, {"info_file_entry_view", "meta_info_file_entry_view"}, {"prompt_update_debounce_ms", "meta_prompt_update_debounce_ms"}, {"prompt_update_idle_ms", "meta_prompt_update_idle_ms"}, {"prompt_short_query_extra_ms", "meta_prompt_short_query_extra_ms"}, {"prompt_size_scale_thresholds", "meta_prompt_size_scale_thresholds"}, {"prompt_size_scale_extra", "meta_prompt_size_scale_extra"}, {"project_lazy_enabled", "meta_project_lazy_enabled"}, {"project_lazy_disable_headless", "meta_project_lazy_disable_headless"}, {"project_lazy_min_estimated_lines", "meta_project_lazy_min_estimated_lines"}, {"project_lazy_chunk_size", "meta_project_lazy_chunk_size"}, {"project_lazy_frame_budget_ms", "meta_project_lazy_frame_budget_ms"}, {"project_lazy_refresh_debounce_ms", "meta_project_lazy_refresh_debounce_ms"}, {"project_lazy_refresh_min_ms", "meta_project_lazy_refresh_min_ms"}, {"project_lazy_prefilter_enabled", "meta_project_lazy_prefilter_enabled"}, {"project_source_syntax_chunk_lines", "meta_project_source_syntax_chunk_lines"}, {"project_bootstrap_delay_ms", "meta_project_bootstrap_delay_ms"}, {"project_bootstrap_idle_delay_ms", "meta_project_bootstrap_idle_delay_ms"}, {"lgrep_bin", "meta_lgrep_bin"}, {"lgrep_limit", "meta_lgrep_limit"}, {"lgrep_debounce_ms", "meta_lgrep_debounce_ms"}, {"prompt_forced_coalesce_ms", "meta_prompt_forced_coalesce_ms"}, {"preview_source_switch_debounce_ms", "meta_preview_source_switch_debounce_ms"}, {"source_syntax_refresh_debounce_ms", "meta_source_syntax_refresh_debounce_ms"}, {"scroll_sync_debounce_ms", "meta_scroll_sync_debounce_ms"}, {"dep_dir_names", nil}}
local router_option_assignments = {{"history-max", "history_max"}, {"project-max-file-bytes", "project_max_file_bytes"}, {"project-max-total-lines", "project_max_total_lines"}, {"default-include-hidden", "default_include_hidden"}, {"default-include-ignored", "default_include_ignored"}, {"default-include-deps", "default_include_deps"}, {"default-include-binary", "default_include_binary"}, {"default-include-hex", "default_include_hex"}, {"default-include-files", "default_include_files"}, {"default-include-lgrep", "default_include_lgrep"}, {"project-rg-bin", "project_rg_bin"}, {"project-rg-base-args", "project_rg_base_args"}, {"project-rg-include-ignored-args", "project_rg_include_ignored_args"}, {"project-rg-deps-exclude-globs", "project_rg_deps_exclude_globs"}, {"project-fallback-glob-pattern", "project_fallback_glob_pattern"}, {"info-max-lines", "info_max_lines"}, {"info-min-width", "info_min_width"}, {"info-max-width", "info_max_width"}, {"context-height", "context_height"}, {"context-around-lines", "context_around_lines"}, {"context-max-blocks", "context_max_blocks"}, {"info-file-entry-view", "info_file_entry_view"}, {"prompt-update-debounce-ms", "prompt_update_debounce_ms"}, {"prompt-update-idle-ms", "prompt_update_idle_ms"}, {"prompt-short-query-extra-ms", "prompt_short_query_extra_ms"}, {"prompt-size-scale-thresholds", "prompt_size_scale_thresholds"}, {"prompt-size-scale-extra", "prompt_size_scale_extra"}, {"project-lazy-enabled", "project_lazy_enabled"}, {"project-lazy-disable-headless", "project_lazy_disable_headless"}, {"project-lazy-min-estimated-lines", "project_lazy_min_estimated_lines"}, {"project-lazy-chunk-size", "project_lazy_chunk_size"}, {"project-lazy-frame-budget-ms", "project_lazy_frame_budget_ms"}, {"project-lazy-refresh-debounce-ms", "project_lazy_refresh_debounce_ms"}, {"project-lazy-refresh-min-ms", "project_lazy_refresh_min_ms"}, {"project-lazy-prefilter-enabled", "project_lazy_prefilter_enabled"}, {"project-bootstrap-delay-ms", "project_bootstrap_delay_ms"}, {"project-bootstrap-idle-delay-ms", "project_bootstrap_idle_delay_ms"}, {"lgrep-bin", "lgrep_bin"}, {"lgrep-limit", "lgrep_limit"}, {"lgrep-debounce-ms", "lgrep_debounce_ms"}, {"prompt-forced-coalesce-ms", "prompt_forced_coalesce_ms"}, {"preview-source-switch-debounce-ms", "preview_source_switch_debounce_ms"}, {"source-syntax-refresh-debounce-ms", "source_syntax_refresh_debounce_ms"}, {"scroll-sync-debounce-ms", "scroll_sync_debounce_ms"}, {"ui-animations-enabled", "ui_animations_enabled"}, {"ui-animations-time-scale", "ui_animations_time_scale"}, {"ui-animation-backend", "ui_animation_backend"}, {"ui-animation-prompt-enabled", "ui_animation_prompt_enabled"}, {"ui-animation-prompt-ms", "ui_animation_prompt_ms"}, {"ui-animation-prompt-time-scale", "ui_animation_prompt_time_scale"}, {"ui-animation-prompt-backend", "ui_animation_prompt_backend"}, {"ui-animation-preview-enabled", "ui_animation_preview_enabled"}, {"ui-animation-preview-ms", "ui_animation_preview_ms"}, {"ui-animation-preview-time-scale", "ui_animation_preview_time_scale"}, {"ui-animation-info-enabled", "ui_animation_info_enabled"}, {"ui-animation-info-ms", "ui_animation_info_ms"}, {"ui-animation-info-time-scale", "ui_animation_info_time_scale"}, {"ui-animation-info-backend", "ui_animation_info_backend"}, {"ui-animation-loading-enabled", "ui_animation_loading_enabled"}, {"ui-animation-loading-ms", "ui_animation_loading_ms"}, {"ui-animation-loading-time-scale", "ui_animation_loading_time_scale"}, {"ui-loading-indicator", "ui_loading_indicator"}, {"ui-animation-scroll-enabled", "ui_animation_scroll_enabled"}, {"ui-animation-scroll-ms", "ui_animation_scroll_ms"}, {"ui-animation-scroll-time-scale", "ui_animation_scroll_time_scale"}, {"ui-animation-scroll-backend", "ui_animation_scroll_backend"}, {"window-local-layout", "window_local_layout"}, {"dep-dir-names", "dep_dir_names"}}
local function resolve_direct_options(opts, defaults)
  local resolved = {}
  for _, spec in ipairs(direct_option_specs) do
    local key,legacy_g = spec[1], spec[2]
    resolved[key] = opt_value(opts, key, legacy_g, defaults[key])
  end
  return resolved
end
local function resolve_animation_options(opts, defaults)
  return {ui_animations_enabled = nested_value(opts, {"ui", "animation", "enabled"}, opt_value(opts, "ui_animations_enabled", "meta_ui_animations_enabled", opt_value(opts, "ui_animate_enter", "meta_ui_animate_enter", defaults.ui_animations_enabled))), ui_animations_time_scale = nested_value(opts, {"ui", "animation", "time_scale"}, opt_value(opts, "ui_animations_time_scale", "meta_ui_animations_time_scale", defaults.ui_animations_time_scale)), ui_animation_backend = nested_value(opts, {"ui", "animation", "backend"}, opt_value(opts, "ui_animation_backend", "meta_ui_animation_backend", defaults.ui_animation_backend)), ui_animation_prompt_enabled = nested_value(opts, {"ui", "animation", "prompt", "enabled"}, opt_value(opts, "ui_animation_prompt_enabled", "meta_ui_animation_prompt_enabled", defaults.ui_animation_prompt_enabled)), ui_animation_prompt_ms = defaults.ui_animation_prompt_ms, ui_animation_prompt_time_scale = nested_value(opts, {"ui", "animation", "prompt", "time_scale"}, opt_value(opts, "ui_animation_prompt_time_scale", "meta_ui_animation_prompt_time_scale", defaults.ui_animation_prompt_time_scale)), ui_animation_prompt_backend = nested_value(opts, {"ui", "animation", "prompt", "backend"}, opt_value(opts, "ui_animation_prompt_backend", "meta_ui_animation_prompt_backend", nested_value(opts, {"ui", "animation", "backend"}, opt_value(opts, "ui_animation_backend", "meta_ui_animation_backend", defaults.ui_animation_backend)))), ui_animation_preview_enabled = nested_value(opts, {"ui", "animation", "preview", "enabled"}, opt_value(opts, "ui_animation_preview_enabled", "meta_ui_animation_preview_enabled", defaults.ui_animation_preview_enabled)), ui_animation_preview_ms = defaults.ui_animation_preview_ms, ui_animation_preview_time_scale = nested_value(opts, {"ui", "animation", "preview", "time_scale"}, opt_value(opts, "ui_animation_preview_time_scale", "meta_ui_animation_preview_time_scale", defaults.ui_animation_preview_time_scale)), ui_animation_info_enabled = nested_value(opts, {"ui", "animation", "info", "enabled"}, opt_value(opts, "ui_animation_info_enabled", "meta_ui_animation_info_enabled", defaults.ui_animation_info_enabled)), ui_animation_info_ms = defaults.ui_animation_info_ms, ui_animation_info_time_scale = nested_value(opts, {"ui", "animation", "info", "time_scale"}, opt_value(opts, "ui_animation_info_time_scale", "meta_ui_animation_info_time_scale", defaults.ui_animation_info_time_scale)), ui_animation_info_backend = nested_value(opts, {"ui", "animation", "info", "backend"}, opt_value(opts, "ui_animation_info_backend", "meta_ui_animation_info_backend", nested_value(opts, {"ui", "animation", "backend"}, opt_value(opts, "ui_animation_backend", "meta_ui_animation_backend", defaults.ui_animation_backend)))), ui_animation_loading_enabled = nested_value(opts, {"ui", "animation", "loading", "enabled"}, opt_value(opts, "ui_animation_loading_enabled", "meta_ui_animation_loading_enabled", defaults.ui_animation_loading_enabled)), ui_animation_loading_ms = defaults.ui_animation_loading_ms, ui_animation_loading_time_scale = nested_value(opts, {"ui", "animation", "loading", "time_scale"}, opt_value(opts, "ui_animation_loading_time_scale", "meta_ui_animation_loading_time_scale", defaults.ui_animation_loading_time_scale)), ui_loading_indicator = nested_value(opts, {"ui", "animation", "loading_indicator"}, opt_value(opts, "ui_loading_indicator", "meta_ui_loading_indicator", defaults.ui_loading_indicator)), ui_animation_scroll_enabled = nested_value(opts, {"ui", "animation", "scroll", "enabled"}, opt_value(opts, "ui_animation_scroll_enabled", "meta_ui_animation_scroll_enabled", defaults.ui_animation_scroll_enabled)), ui_animation_scroll_ms = defaults.ui_animation_scroll_ms, ui_animation_scroll_time_scale = nested_value(opts, {"ui", "animation", "scroll", "time_scale"}, opt_value(opts, "ui_animation_scroll_time_scale", "meta_ui_animation_scroll_time_scale", defaults.ui_animation_scroll_time_scale)), ui_animation_scroll_backend = nested_value(opts, {"ui", "animation", "scroll", "backend"}, opt_value(opts, "ui_animation_scroll_backend", "meta_ui_animation_scroll_backend", nested_value(opts, {"ui", "animation", "backend"}, opt_value(opts, "ui_animation_backend", "meta_ui_animation_backend", defaults.ui_animation_backend))))}
end
local function resolve_custom_options(opts, defaults)
  local _7_
  if (opt_value(opts, "window_local_layout", "meta_window_local_layout", defaults.window_local_layout) == nil) then
    _7_ = true
  else
    _7_ = opt_value(opts, "window_local_layout", "meta_window_local_layout", defaults.window_local_layout)
  end
  return {custom = vim.deepcopy((nested_value(opts, {"options", "custom"}, nil) or nested_value(opts, {"custom"}, nil) or defaults.custom)), window_local_layout = _7_}
end
local function set_router_options_21(router, options)
  for _, spec in ipairs(router_option_assignments) do
    local router_key,option_key = spec[1], spec[2]
    router[router_key] = options[option_key]
  end
  router["project-file-cache"] = {}
  return nil
end
local function set_router_keymaps_21(router, keymaps)
  router["default-prompt-keymaps"] = M.defaults.keymaps.prompt
  router["default-main-keymaps"] = M.defaults.keymaps.main
  router["default-prompt-fallback-keymaps"] = M.defaults.keymaps.prompt_fallback
  router["prompt-keymaps"] = keymaps.prompt
  router["main-keymaps"] = keymaps.main
  router["prompt-fallback-keymaps"] = keymaps.prompt_fallback
  return nil
end
M.resolve = function(opts)
  local defaults = M.defaults.options
  return {options = vim.tbl_extend("force", resolve_direct_options(opts, defaults), resolve_animation_options(opts, defaults), resolve_custom_options(opts, defaults)), keymaps = resolve_keymaps(opts), ui = resolve_ui(opts)}
end
M["apply-router-defaults"] = function(router, _vim, opts)
  local resolved = M.resolve(opts)
  local options = resolved.options
  local keymaps = resolved.keymaps
  router["option-state"] = options
  router["keymap-state"] = keymaps
  set_router_options_21(router, options)
  router["custom-config"] = options.custom
  set_router_keymaps_21(router, keymaps)
  custom_mod["configure!"](options.custom)
  return resolved
end
return M
