-- [nfnl] fnl/metabuffer/config.fnl
local M = {}
local default_prompt_keymaps = {{{"n", "i"}, "<CR>", "accept"}, {{"n", "i"}, "<M-CR>", "enter-edit-mode"}, {{"n", "i"}, "<A-CR>", "enter-edit-mode"}, {"n", "<Esc>", "cancel"}, {"n", "<C-p>", "move-selection", -1}, {"n", "<C-n>", "move-selection", 1}, {"i", "<C-p>", "move-selection", -1}, {"i", "<C-n>", "move-selection", 1}, {"n", "<C-k>", "move-selection", -1}, {"n", "<C-j>", "move-selection", 1}, {"i", "<C-k>", "move-selection", -1}, {"i", "<C-j>", "move-selection", 1}, {"i", "<C-a>", "prompt-home"}, {"i", "<C-e>", "prompt-end"}, {"i", "<C-u>", "prompt-kill-backward"}, {"i", "<C-y>", "prompt-yank"}, {"i", "<Up>", "history-or-move", 1}, {"i", "<Down>", "history-or-move", -1}, {"n", "<Up>", "history-or-move", 1}, {"n", "<Down>", "history-or-move", -1}, {"i", "!!", "insert-last-prompt"}, {"n", "!!", "insert-last-prompt"}, {"i", "!$", "insert-last-token"}, {"n", "!$", "insert-last-token"}, {"i", "!^!", "insert-last-tail"}, {"n", "!^!", "insert-last-tail"}, {"i", "<LocalLeader>1", "negate-current-token"}, {"i", "<LocalLeader>!", "negate-current-token"}, {"n", "<LocalLeader>h", "merge-history"}, {"i", "<LocalLeader>h", "merge-history"}, {"i", "<C-r>", "history-searchback"}, {{"n", "i"}, "<C-^>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-6>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-_>", "switch-mode", "case"}, {{"n", "i"}, "<C-/>", "switch-mode", "case"}, {{"n", "i"}, "<C-?>", "switch-mode", "case"}, {{"n", "i"}, "<C-->", "switch-mode", "case"}, {{"n", "i"}, "<C-o>", "switch-mode", "case"}, {{"n", "i"}, "<C-s>", "switch-mode", "syntax"}, {"n", "<C-g>", "toggle-scan-option", "ignored"}, {"n", "<C-l>", "toggle-scan-option", "deps"}, {{"n", "i"}, "<LocalLeader>i", "toggle-info-file-entry-view"}, {{"n", "i"}, "<C-d>", "scroll-main", "half-down"}, {"n", "<C-u>", "scroll-main", "half-up"}, {{"n", "i"}, "<C-f>", "scroll-main", "page-down"}, {{"n", "i"}, "<C-b>", "scroll-main", "page-up"}, {{"n", "i"}, "<C-t>", "toggle-project-mode"}}
local default_main_keymaps = {{"n", "!", "exclude-symbol-under-cursor"}, {"n", "<CR>", "accept-main"}, {"n", "<M-CR>", "enter-edit-mode"}, {"n", "<A-CR>", "enter-edit-mode"}, {"n", "<LocalLeader>i", "toggle-info-file-entry-view"}, {"n", "<ScrollWheelDown>", "scroll-main", "line-down"}, {"n", "<ScrollWheelUp>", "scroll-main", "line-up"}, {"n", "<M-S-CR>", "insert-symbol-under-cursor"}, {"n", "<A-S-CR>", "insert-symbol-under-cursor"}}
local default_prompt_fallback_keymaps = {{"i", "<C-a>", "prompt-home"}, {"i", "<C-e>", "prompt-end"}, {"i", "<C-u>", "prompt-kill-backward"}, {"i", "<C-k>", "move-selection", -1}, {"i", "<C-y>", "prompt-yank"}}
M.defaults = {options = {history_max = 100, project_max_file_bytes = (1024 * 1024), project_max_total_lines = 200000, project_rg_bin = "rg", project_rg_base_args = {"--files", "--glob", "!.git"}, project_rg_include_ignored_args = {"--no-ignore", "--no-ignore-vcs", "--no-ignore-parent"}, project_rg_deps_exclude_globs = {"!node_modules/**", "!vendor/**", "!deps/**", "!.venv/**", "!venv/**", "!dist/**", "!build/**", "!target/**"}, project_fallback_glob_pattern = "**/*", info_max_lines = 10000, info_min_width = 28, info_max_width = 52, info_file_entry_view = "meta", prompt_update_debounce_ms = 170, prompt_update_idle_ms = 90, prompt_short_query_extra_ms = {180, 120, 70}, prompt_size_scale_thresholds = {2000, 10000, 50000}, prompt_size_scale_extra = {0, 2, 6, 10}, project_lazy_enabled = true, project_lazy_disable_headless = true, project_lazy_min_estimated_lines = 10000, project_lazy_chunk_size = 8, project_lazy_refresh_debounce_ms = 80, project_lazy_refresh_min_ms = 20, project_lazy_prefilter_enabled = true, project_bootstrap_delay_ms = 120, project_bootstrap_idle_delay_ms = 700, prompt_forced_coalesce_ms = 700, preview_source_switch_debounce_ms = 60, source_syntax_refresh_debounce_ms = 80, scroll_sync_debounce_ms = 20, window_local_layout = true, dep_dir_names = {node_modules = true, [".venv"] = true, venv = true, vendor = true, deps = true, dist = true, build = true, target = true, __pycache__ = true, [".mypy_cache"] = true, [".pytest_cache"] = true, [".tox"] = true, [".next"] = true, [".nuxt"] = true, [".yarn"] = true, [".pnpm-store"] = true}, default_include_deps = false, default_include_files = false, default_include_hidden = false, default_include_ignored = false}, ui = {custom_mappings = {}, highlight_groups = {All = "Title", Fuzzy = "Number", Regex = "Special"}, syntax_on_init = "buffer", prefix = "#"}, keymaps = {prompt = default_prompt_keymaps, main = default_main_keymaps, prompt_fallback = default_prompt_fallback_keymaps}}
local function table_3f(v)
  return (type(v) == "table")
end
local function nested(opts, k)
  return (table_3f(opts) and table_3f(opts[k]) and opts[k])
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
local function resolve_keymaps(opts)
  local keymaps = nested(opts, "keymaps")
  return {prompt = ((keymaps and keymaps.prompt) or (table_3f(opts) and opts.prompt_keymaps) or vim.g.meta_prompt_keymaps or M.defaults.keymaps.prompt), main = ((keymaps and keymaps.main) or (table_3f(opts) and opts.main_keymaps) or vim.g.meta_main_keymaps or M.defaults.keymaps.main), prompt_fallback = ((keymaps and keymaps.prompt_fallback) or (table_3f(opts) and opts.prompt_fallback_keymaps) or vim.g.meta_prompt_fallback_keymaps or M.defaults.keymaps.prompt_fallback)}
end
local function resolve_ui(opts)
  local ui = nested(opts, "ui")
  return {custom_mappings = ((ui and (ui.custom_mappings ~= nil) and ui.custom_mappings) or vim.g["meta#custom_mappings"] or M.defaults.ui.custom_mappings), highlight_groups = ((ui and (ui.highlight_groups ~= nil) and ui.highlight_groups) or vim.g["meta#highlight_groups"] or M.defaults.ui.highlight_groups), syntax_on_init = ((ui and (ui.syntax_on_init ~= nil) and ui.syntax_on_init) or vim.g["meta#syntax_on_init"] or M.defaults.ui.syntax_on_init), prefix = ((ui and (ui.prefix ~= nil) and ui.prefix) or vim.g["meta#prefix"] or M.defaults.ui.prefix)}
end
M.resolve = function(opts)
  local defaults = M.defaults.options
  local _4_
  if (opt_value(opts, "window_local_layout", "meta_window_local_layout", defaults.window_local_layout) == nil) then
    _4_ = true
  else
    _4_ = opt_value(opts, "window_local_layout", "meta_window_local_layout", defaults.window_local_layout)
  end
  return {options = {history_max = opt_value(opts, "history_max", nil, defaults.history_max), project_max_file_bytes = opt_value(opts, "project_max_file_bytes", "meta_project_max_file_bytes", defaults.project_max_file_bytes), project_max_total_lines = opt_value(opts, "project_max_total_lines", "meta_project_max_total_lines", defaults.project_max_total_lines), default_include_hidden = opt_value(opts, "default_include_hidden", "meta_project_include_hidden", defaults.default_include_hidden), default_include_ignored = opt_value(opts, "default_include_ignored", "meta_project_include_ignored", defaults.default_include_ignored), default_include_deps = opt_value(opts, "default_include_deps", "meta_project_include_deps", defaults.default_include_deps), default_include_files = opt_value(opts, "default_include_files", "meta_project_include_files", defaults.default_include_files), project_rg_bin = opt_value(opts, "project_rg_bin", "meta_project_rg_bin", defaults.project_rg_bin), project_rg_base_args = opt_value(opts, "project_rg_base_args", "meta_project_rg_base_args", defaults.project_rg_base_args), project_rg_include_ignored_args = opt_value(opts, "project_rg_include_ignored_args", "meta_project_rg_include_ignored_args", defaults.project_rg_include_ignored_args), project_rg_deps_exclude_globs = opt_value(opts, "project_rg_deps_exclude_globs", "meta_project_rg_deps_exclude_globs", defaults.project_rg_deps_exclude_globs), project_fallback_glob_pattern = opt_value(opts, "project_fallback_glob_pattern", "meta_project_fallback_glob_pattern", defaults.project_fallback_glob_pattern), info_max_lines = opt_value(opts, "info_max_lines", "meta_info_max_lines", defaults.info_max_lines), info_min_width = opt_value(opts, "info_min_width", "meta_info_width", defaults.info_min_width), info_max_width = opt_value(opts, "info_max_width", "meta_info_max_width", defaults.info_max_width), info_file_entry_view = opt_value(opts, "info_file_entry_view", "meta_info_file_entry_view", defaults.info_file_entry_view), prompt_update_debounce_ms = opt_value(opts, "prompt_update_debounce_ms", "meta_prompt_update_debounce_ms", defaults.prompt_update_debounce_ms), prompt_update_idle_ms = opt_value(opts, "prompt_update_idle_ms", "meta_prompt_update_idle_ms", defaults.prompt_update_idle_ms), prompt_short_query_extra_ms = opt_value(opts, "prompt_short_query_extra_ms", "meta_prompt_short_query_extra_ms", defaults.prompt_short_query_extra_ms), prompt_size_scale_thresholds = opt_value(opts, "prompt_size_scale_thresholds", "meta_prompt_size_scale_thresholds", defaults.prompt_size_scale_thresholds), prompt_size_scale_extra = opt_value(opts, "prompt_size_scale_extra", "meta_prompt_size_scale_extra", defaults.prompt_size_scale_extra), project_lazy_enabled = opt_value(opts, "project_lazy_enabled", "meta_project_lazy_enabled", defaults.project_lazy_enabled), project_lazy_disable_headless = opt_value(opts, "project_lazy_disable_headless", "meta_project_lazy_disable_headless", defaults.project_lazy_disable_headless), project_lazy_min_estimated_lines = opt_value(opts, "project_lazy_min_estimated_lines", "meta_project_lazy_min_estimated_lines", defaults.project_lazy_min_estimated_lines), project_lazy_chunk_size = opt_value(opts, "project_lazy_chunk_size", "meta_project_lazy_chunk_size", defaults.project_lazy_chunk_size), project_lazy_refresh_debounce_ms = opt_value(opts, "project_lazy_refresh_debounce_ms", "meta_project_lazy_refresh_debounce_ms", defaults.project_lazy_refresh_debounce_ms), project_lazy_refresh_min_ms = opt_value(opts, "project_lazy_refresh_min_ms", "meta_project_lazy_refresh_min_ms", defaults.project_lazy_refresh_min_ms), project_lazy_prefilter_enabled = opt_value(opts, "project_lazy_prefilter_enabled", "meta_project_lazy_prefilter_enabled", defaults.project_lazy_prefilter_enabled), project_bootstrap_delay_ms = opt_value(opts, "project_bootstrap_delay_ms", "meta_project_bootstrap_delay_ms", defaults.project_bootstrap_delay_ms), project_bootstrap_idle_delay_ms = opt_value(opts, "project_bootstrap_idle_delay_ms", "meta_project_bootstrap_idle_delay_ms", defaults.project_bootstrap_idle_delay_ms), prompt_forced_coalesce_ms = opt_value(opts, "prompt_forced_coalesce_ms", "meta_prompt_forced_coalesce_ms", defaults.prompt_forced_coalesce_ms), preview_source_switch_debounce_ms = opt_value(opts, "preview_source_switch_debounce_ms", "meta_preview_source_switch_debounce_ms", defaults.preview_source_switch_debounce_ms), source_syntax_refresh_debounce_ms = opt_value(opts, "source_syntax_refresh_debounce_ms", "meta_source_syntax_refresh_debounce_ms", defaults.source_syntax_refresh_debounce_ms), scroll_sync_debounce_ms = opt_value(opts, "scroll_sync_debounce_ms", "meta_scroll_sync_debounce_ms", defaults.scroll_sync_debounce_ms), window_local_layout = _4_, dep_dir_names = opt_value(opts, "dep_dir_names", nil, defaults.dep_dir_names)}, keymaps = resolve_keymaps(opts), ui = resolve_ui(opts)}
end
M["apply-router-defaults"] = function(router, _vim, opts)
  local resolved = M.resolve(opts)
  local options = resolved.options
  local keymaps = resolved.keymaps
  router["option-state"] = options
  router["keymap-state"] = keymaps
  router["history-max"] = options.history_max
  router["project-max-file-bytes"] = options.project_max_file_bytes
  router["project-max-total-lines"] = options.project_max_total_lines
  router["default-include-hidden"] = options.default_include_hidden
  router["default-include-ignored"] = options.default_include_ignored
  router["default-include-deps"] = options.default_include_deps
  router["default-include-files"] = options.default_include_files
  router["project-rg-bin"] = options.project_rg_bin
  router["project-rg-base-args"] = options.project_rg_base_args
  router["project-rg-include-ignored-args"] = options.project_rg_include_ignored_args
  router["project-rg-deps-exclude-globs"] = options.project_rg_deps_exclude_globs
  router["project-fallback-glob-pattern"] = options.project_fallback_glob_pattern
  router["info-max-lines"] = options.info_max_lines
  router["info-min-width"] = options.info_min_width
  router["info-max-width"] = options.info_max_width
  router["info-file-entry-view"] = options.info_file_entry_view
  router["prompt-update-debounce-ms"] = options.prompt_update_debounce_ms
  router["prompt-update-idle-ms"] = options.prompt_update_idle_ms
  router["prompt-short-query-extra-ms"] = options.prompt_short_query_extra_ms
  router["prompt-size-scale-thresholds"] = options.prompt_size_scale_thresholds
  router["prompt-size-scale-extra"] = options.prompt_size_scale_extra
  router["project-file-cache"] = {}
  router["project-lazy-enabled"] = options.project_lazy_enabled
  router["project-lazy-disable-headless"] = options.project_lazy_disable_headless
  router["project-lazy-min-estimated-lines"] = options.project_lazy_min_estimated_lines
  router["project-lazy-chunk-size"] = options.project_lazy_chunk_size
  router["project-lazy-refresh-debounce-ms"] = options.project_lazy_refresh_debounce_ms
  router["project-lazy-refresh-min-ms"] = options.project_lazy_refresh_min_ms
  router["project-lazy-prefilter-enabled"] = options.project_lazy_prefilter_enabled
  router["project-bootstrap-delay-ms"] = options.project_bootstrap_delay_ms
  router["project-bootstrap-idle-delay-ms"] = options.project_bootstrap_idle_delay_ms
  router["prompt-forced-coalesce-ms"] = options.prompt_forced_coalesce_ms
  router["preview-source-switch-debounce-ms"] = options.preview_source_switch_debounce_ms
  router["source-syntax-refresh-debounce-ms"] = options.source_syntax_refresh_debounce_ms
  router["scroll-sync-debounce-ms"] = options.scroll_sync_debounce_ms
  router["window-local-layout"] = options.window_local_layout
  router["default-prompt-keymaps"] = M.defaults.keymaps.prompt
  router["default-main-keymaps"] = M.defaults.keymaps.main
  router["default-prompt-fallback-keymaps"] = M.defaults.keymaps.prompt_fallback
  router["prompt-keymaps"] = keymaps.prompt
  router["main-keymaps"] = keymaps.main
  router["prompt-fallback-keymaps"] = keymaps.prompt_fallback
  router["dep-dir-names"] = options.dep_dir_names
  return resolved
end
return M
