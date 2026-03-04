(local M {})

(fn M.apply-router-defaults [router vim]
  (set router.history-max 100)
  (set router.project-max-file-bytes (or vim.g.meta_project_max_file_bytes (* 1024 1024)))
  (set router.project-max-total-lines (or vim.g.meta_project_max_total_lines 200000))
  (set router.default-include-hidden (or vim.g.meta_project_include_hidden false))
  (set router.default-include-ignored (or vim.g.meta_project_include_ignored false))
  (set router.default-include-deps (or vim.g.meta_project_include_deps false))
  (set router.info-max-lines (or vim.g.meta_info_max_lines 10000))
  (set router.info-min-width (or vim.g.meta_info_width 28))
  (set router.info-max-width (or vim.g.meta_info_max_width 52))
  (set router.prompt-update-debounce-ms (or vim.g.meta_prompt_update_debounce_ms 100))
  (set router.prompt-update-idle-ms (or vim.g.meta_prompt_update_idle_ms 90))
  (set router.project-file-cache {})
  (set router.project-lazy-enabled (if (= vim.g.meta_project_lazy_enabled nil) true vim.g.meta_project_lazy_enabled))
  (set router.project-lazy-disable-headless (if (= vim.g.meta_project_lazy_disable_headless nil) true vim.g.meta_project_lazy_disable_headless))
  (set router.project-lazy-min-estimated-lines (or vim.g.meta_project_lazy_min_estimated_lines 10000))
  (set router.project-lazy-chunk-size (or vim.g.meta_project_lazy_chunk_size 8))
  (set router.project-lazy-refresh-debounce-ms (or vim.g.meta_project_lazy_refresh_debounce_ms 80))
  (set router.project-lazy-prefilter-enabled (if (= vim.g.meta_project_lazy_prefilter_enabled nil) true vim.g.meta_project_lazy_prefilter_enabled))
  (set router.project-bootstrap-delay-ms (or vim.g.meta_project_bootstrap_delay_ms 120))
  (set router.project-bootstrap-idle-delay-ms (or vim.g.meta_project_bootstrap_idle_delay_ms 700))
  (set router.prompt-forced-coalesce-ms (or vim.g.meta_prompt_forced_coalesce_ms 700))
  (set router.preview-source-switch-debounce-ms (or vim.g.meta_preview_source_switch_debounce_ms 60))
  (set router.dep-dir-names
    {"node_modules" true
     ".venv" true
     "venv" true
     "vendor" true
     "dist" true
     "build" true
     ".next" true
     ".nuxt" true
     "target" true
     ".git" true}))

M
