(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.apply-router-defaults
  [router vim]
  "Public API: M.apply-router-defaults."
  (let [default-prompt-keymaps
        [ [["n" "i"] "<CR>" "accept"]
          ;; In insert mode, <Esc> should only leave insert mode.
          ;; Cancel/close only from normal mode.
          ["n" "<Esc>" "cancel"]
          ["n" "<C-p>" "move-selection" -1]
          ["n" "<C-n>" "move-selection" 1]
          ["i" "<C-p>" "move-selection" -1]
          ["i" "<C-n>" "move-selection" 1]
          ["n" "<C-k>" "move-selection" -1]
          ["n" "<C-j>" "move-selection" 1]
          ["i" "<C-k>" "move-selection" -1]
          ["i" "<C-j>" "move-selection" 1]
          ["i" "<Up>" "history-or-move" 1]
          ["i" "<Down>" "history-or-move" -1]
          ["n" "<Up>" "history-or-move" 1]
          ["n" "<Down>" "history-or-move" -1]
          ;; Statusline keys: C^ (matcher), C_ (case), Cs (syntax)
          [["n" "i"] "<C-^>" "switch-mode" "matcher"]
          [["n" "i"] "<C-6>" "switch-mode" "matcher"]
          [["n" "i"] "<C-_>" "switch-mode" "case"]
          [["n" "i"] "<C-/>" "switch-mode" "case"]
          [["n" "i"] "<C-?>" "switch-mode" "case"]
          [["n" "i"] "<C-->" "switch-mode" "case"]
          [["n" "i"] "<C-o>" "switch-mode" "case"]
          [["n" "i"] "<C-s>" "switch-mode" "syntax"]
          ["n" "<C-g>" "toggle-scan-option" "ignored"]
          ["n" "<C-l>" "toggle-scan-option" "deps"]
          [["n" "i"] "<C-d>" "scroll-main" "half-down"]
          [["n" "i"] "<C-u>" "scroll-main" "half-up"]
          [["n" "i"] "<C-f>" "scroll-main" "page-down"]
          [["n" "i"] "<C-b>" "scroll-main" "page-up"]
          ;; keep project toggle available without conflicting with scroll/page keys
          [["n" "i"] "<C-t>" "toggle-project-mode"]]]
  (set router.history-max 100)
  (set router.project-max-file-bytes (or vim.g.meta_project_max_file_bytes (* 1024 1024)))
  (set router.project-max-total-lines (or vim.g.meta_project_max_total_lines 200000))
  (set router.default-include-hidden (or vim.g.meta_project_include_hidden false))
  (set router.default-include-ignored (or vim.g.meta_project_include_ignored false))
  (set router.default-include-deps (or vim.g.meta_project_include_deps false))
  (set router.project-rg-bin (or vim.g.meta_project_rg_bin "rg"))
  (set router.project-rg-base-args
    (or vim.g.meta_project_rg_base_args ["--files" "--glob" "!.git"]))
  (set router.project-rg-include-ignored-args
    (or vim.g.meta_project_rg_include_ignored_args
        ["--no-ignore" "--no-ignore-vcs" "--no-ignore-parent"]))
  (set router.project-rg-deps-exclude-globs
    (or vim.g.meta_project_rg_deps_exclude_globs
        ["!node_modules/**" "!vendor/**" "!.venv/**" "!venv/**" "!dist/**" "!build/**" "!target/**"]))
  (set router.project-fallback-glob-pattern
    (or vim.g.meta_project_fallback_glob_pattern "**/*"))
  (set router.info-max-lines (or vim.g.meta_info_max_lines 10000))
  (set router.info-min-width (or vim.g.meta_info_width 28))
  (set router.info-max-width (or vim.g.meta_info_max_width 52))
  (set router.prompt-update-debounce-ms (or vim.g.meta_prompt_update_debounce_ms 170))
  (set router.prompt-update-idle-ms (or vim.g.meta_prompt_update_idle_ms 90))
  (set router.prompt-short-query-extra-ms
    (or vim.g.meta_prompt_short_query_extra_ms [180 120 70]))
  (set router.prompt-size-scale-thresholds
    (or vim.g.meta_prompt_size_scale_thresholds [2000 10000 50000]))
  (set router.prompt-size-scale-extra
    (or vim.g.meta_prompt_size_scale_extra [0 2 6 10]))
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
  (set router.source-syntax-refresh-debounce-ms (or vim.g.meta_source_syntax_refresh_debounce_ms 80))
  (set router.scroll-sync-debounce-ms (or vim.g.meta_scroll_sync_debounce_ms 20))
  (set router.default-prompt-keymaps default-prompt-keymaps)
  (when (= vim.g.meta_prompt_keymaps nil)
    (set vim.g.meta_prompt_keymaps (vim.deepcopy default-prompt-keymaps)))
  (set router.dep-dir-names
    {"node_modules" true
     ".venv" true
     "venv" true
     "vendor" true
     "dist" true
     "build" true
     "target" true
     "__pycache__" true
     ".mypy_cache" true
     ".pytest_cache" true
     ".tox" true
     ".next" true
     ".nuxt" true
     ".yarn" true
     ".pnpm-store" true})))

M
