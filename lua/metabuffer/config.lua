-- [nfnl] fnl/metabuffer/config.fnl
local M = {}
M["apply-router-defaults"] = function(router, vim)
  local default_prompt_keymaps = {{{"n", "i"}, "<CR>", "accept"}, {"n", "<Esc>", "cancel"}, {"n", "<C-p>", "move-selection", -1}, {"n", "<C-n>", "move-selection", 1}, {"i", "<C-p>", "move-selection", -1}, {"i", "<C-n>", "move-selection", 1}, {"n", "<C-k>", "move-selection", -1}, {"n", "<C-j>", "move-selection", 1}, {"i", "<C-k>", "prompt-kill-forward"}, {"i", "<C-j>", "move-selection", 1}, {"i", "<C-a>", "prompt-home"}, {"i", "<C-e>", "prompt-end"}, {"i", "<C-u>", "prompt-kill-backward"}, {"i", "<C-y>", "prompt-yank"}, {"i", "<Up>", "history-or-move", 1}, {"i", "<Down>", "history-or-move", -1}, {"n", "<Up>", "history-or-move", 1}, {"n", "<Down>", "history-or-move", -1}, {"i", "!!", "insert-last-prompt"}, {"n", "!!", "insert-last-prompt"}, {"i", "!$", "insert-last-token"}, {"n", "!$", "insert-last-token"}, {"i", "!^!", "insert-last-tail"}, {"n", "!^!", "insert-last-tail"}, {"i", "<LocalLeader>1", "negate-current-token"}, {"i", "<LocalLeader>!", "negate-current-token"}, {"n", "<LocalLeader>h", "merge-history"}, {"i", "<LocalLeader>h", "merge-history"}, {"i", "<C-r>", "history-searchback"}, {{"n", "i"}, "<C-^>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-6>", "switch-mode", "matcher"}, {{"n", "i"}, "<C-_>", "switch-mode", "case"}, {{"n", "i"}, "<C-/>", "switch-mode", "case"}, {{"n", "i"}, "<C-?>", "switch-mode", "case"}, {{"n", "i"}, "<C-->", "switch-mode", "case"}, {{"n", "i"}, "<C-o>", "switch-mode", "case"}, {{"n", "i"}, "<C-s>", "switch-mode", "syntax"}, {"n", "<C-g>", "toggle-scan-option", "ignored"}, {"n", "<C-l>", "toggle-scan-option", "deps"}, {{"n", "i"}, "<C-d>", "scroll-main", "half-down"}, {"n", "<C-u>", "scroll-main", "half-up"}, {{"n", "i"}, "<C-f>", "scroll-main", "page-down"}, {{"n", "i"}, "<C-b>", "scroll-main", "page-up"}, {{"n", "i"}, "<C-t>", "toggle-project-mode"}}
  router["history-max"] = 100
  router["project-max-file-bytes"] = (vim.g.meta_project_max_file_bytes or (1024 * 1024))
  router["project-max-total-lines"] = (vim.g.meta_project_max_total_lines or 200000)
  router["default-include-hidden"] = (vim.g.meta_project_include_hidden or false)
  router["default-include-ignored"] = (vim.g.meta_project_include_ignored or false)
  router["default-include-deps"] = (vim.g.meta_project_include_deps or false)
  router["project-rg-bin"] = (vim.g.meta_project_rg_bin or "rg")
  router["project-rg-base-args"] = (vim.g.meta_project_rg_base_args or {"--files", "--glob", "!.git"})
  router["project-rg-include-ignored-args"] = (vim.g.meta_project_rg_include_ignored_args or {"--no-ignore", "--no-ignore-vcs", "--no-ignore-parent"})
  router["project-rg-deps-exclude-globs"] = (vim.g.meta_project_rg_deps_exclude_globs or {"!node_modules/**", "!vendor/**", "!.venv/**", "!venv/**", "!dist/**", "!build/**", "!target/**"})
  router["project-fallback-glob-pattern"] = (vim.g.meta_project_fallback_glob_pattern or "**/*")
  router["info-max-lines"] = (vim.g.meta_info_max_lines or 10000)
  router["info-min-width"] = (vim.g.meta_info_width or 28)
  router["info-max-width"] = (vim.g.meta_info_max_width or 52)
  router["prompt-update-debounce-ms"] = (vim.g.meta_prompt_update_debounce_ms or 170)
  router["prompt-update-idle-ms"] = (vim.g.meta_prompt_update_idle_ms or 90)
  router["prompt-short-query-extra-ms"] = (vim.g.meta_prompt_short_query_extra_ms or {180, 120, 70})
  router["prompt-size-scale-thresholds"] = (vim.g.meta_prompt_size_scale_thresholds or {2000, 10000, 50000})
  router["prompt-size-scale-extra"] = (vim.g.meta_prompt_size_scale_extra or {0, 2, 6, 10})
  router["project-file-cache"] = {}
  if (vim.g.meta_project_lazy_enabled == nil) then
    router["project-lazy-enabled"] = true
  else
    router["project-lazy-enabled"] = vim.g.meta_project_lazy_enabled
  end
  if (vim.g.meta_project_lazy_disable_headless == nil) then
    router["project-lazy-disable-headless"] = true
  else
    router["project-lazy-disable-headless"] = vim.g.meta_project_lazy_disable_headless
  end
  router["project-lazy-min-estimated-lines"] = (vim.g.meta_project_lazy_min_estimated_lines or 10000)
  router["project-lazy-chunk-size"] = (vim.g.meta_project_lazy_chunk_size or 8)
  router["project-lazy-refresh-debounce-ms"] = (vim.g.meta_project_lazy_refresh_debounce_ms or 80)
  if (vim.g.meta_project_lazy_prefilter_enabled == nil) then
    router["project-lazy-prefilter-enabled"] = true
  else
    router["project-lazy-prefilter-enabled"] = vim.g.meta_project_lazy_prefilter_enabled
  end
  router["project-bootstrap-delay-ms"] = (vim.g.meta_project_bootstrap_delay_ms or 120)
  router["project-bootstrap-idle-delay-ms"] = (vim.g.meta_project_bootstrap_idle_delay_ms or 700)
  router["prompt-forced-coalesce-ms"] = (vim.g.meta_prompt_forced_coalesce_ms or 700)
  router["preview-source-switch-debounce-ms"] = (vim.g.meta_preview_source_switch_debounce_ms or 60)
  router["source-syntax-refresh-debounce-ms"] = (vim.g.meta_source_syntax_refresh_debounce_ms or 80)
  router["scroll-sync-debounce-ms"] = (vim.g.meta_scroll_sync_debounce_ms or 20)
  router["default-prompt-keymaps"] = default_prompt_keymaps
  if (vim.g.meta_prompt_keymaps == nil) then
    vim.g.meta_prompt_keymaps = vim.deepcopy(default_prompt_keymaps)
  else
  end
  router["dep-dir-names"] = {node_modules = true, [".venv"] = true, venv = true, vendor = true, dist = true, build = true, target = true, __pycache__ = true, [".mypy_cache"] = true, [".pytest_cache"] = true, [".tox"] = true, [".next"] = true, [".nuxt"] = true, [".yarn"] = true, [".pnpm-store"] = true}
  return nil
end
return M
