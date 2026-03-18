(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(local default-prompt-keymaps
  [ [["n" "i"] "<CR>" "accept"]
    [["n" "i"] "<M-CR>" "toggle-prompt-results-focus"]
    [["n" "i"] "<A-CR>" "toggle-prompt-results-focus"]
    ["n" "<Esc>" "cancel"]
    ["n" "<C-p>" "move-selection" -1]
    ["n" "<C-n>" "move-selection" 1]
    ["i" "<C-p>" "move-selection" -1]
    ["i" "<C-n>" "move-selection" 1]
    ["n" "<C-k>" "move-selection" -1]
    ["n" "<C-j>" "move-selection" 1]
    ["i" "<C-k>" "move-selection" -1]
    ["i" "<C-j>" "move-selection" 1]
    ["i" "<C-a>" "prompt-home"]
    ["i" "<C-e>" "prompt-end"]
    ["i" "<C-u>" "prompt-kill-backward"]
    ["i" "<C-y>" "prompt-yank"]
    ["i" "<Up>" "history-or-move" 1]
    ["i" "<Down>" "history-or-move" -1]
    ["n" "<Up>" "history-or-move" 1]
    ["n" "<Down>" "history-or-move" -1]
    ["i" "!!" "insert-last-prompt"]
    ["n" "!!" "insert-last-prompt"]
    ["i" "!$" "insert-last-token"]
    ["n" "!$" "insert-last-token"]
    ["i" "!^!" "insert-last-tail"]
    ["n" "!^!" "insert-last-tail"]
    ["i" "<LocalLeader>1" "negate-current-token"]
    ["i" "<LocalLeader>!" "negate-current-token"]
    ["n" "<LocalLeader>h" "merge-history"]
    ["i" "<LocalLeader>h" "merge-history"]
    ["i" "<C-r>" "history-searchback"]
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
    [["n" "i"] "<LocalLeader>i" "toggle-info-file-entry-view"]
    [["n" "i"] "<C-d>" "scroll-main" "half-down"]
    ["n" "<C-u>" "scroll-main" "half-up"]
    [["n" "i"] "<C-f>" "scroll-main" "page-down"]
    [["n" "i"] "<C-b>" "scroll-main" "page-up"]
    [["n" "i"] "<C-t>" "toggle-project-mode"]])

(local default-main-keymaps
  [ ["n" "!" "exclude-symbol-under-cursor"]
    ["n" "#" "insert-symbol-under-cursor-newline"]
    ["n" "<CR>" "accept-main"]
    ["n" "<LocalLeader>i" "toggle-info-file-entry-view"]
    ["n" "<ScrollWheelDown>" "scroll-main" "line-down"]
    ["n" "<ScrollWheelUp>" "scroll-main" "line-up"]
    [["n" "i"] "<M-CR>" "toggle-prompt-results-focus"]
    [["n" "i"] "<A-CR>" "toggle-prompt-results-focus"]])

(local default-prompt-fallback-keymaps
  [ ["i" "<C-a>" "prompt-home"]
    ["i" "<C-e>" "prompt-end"]
    ["i" "<C-u>" "prompt-kill-backward"]
    ["i" "<C-k>" "move-selection" -1]
    ["i" "<C-y>" "prompt-yank"]])

(set M.defaults
  {:options
   {:history_max 100
    :project_max_file_bytes (* 1024 1024)
    :project_max_total_lines 200000
    :default_include_hidden false
    :default_include_ignored false
    :default_include_deps false
    :default_include_binary false
    :default_include_hex false
    :default_include_files false
    :project_rg_bin "rg"
    :project_rg_base_args ["--files" "--glob" "!.git"]
    :project_rg_include_ignored_args ["--no-ignore" "--no-ignore-vcs" "--no-ignore-parent"]
    :project_rg_deps_exclude_globs ["!node_modules/**" "!vendor/**" "!deps/**" "!.venv/**" "!venv/**" "!dist/**" "!build/**" "!target/**"]
    :project_fallback_glob_pattern "**/*"
    :info_max_lines 10000
    :info_min_width 28
    :info_max_width 52
    :context_height 14
    :context_around_lines 3
    :context_max_blocks 24
    :info_file_entry_view "meta"
    :prompt_update_debounce_ms 170
    :prompt_update_idle_ms 90
    :prompt_short_query_extra_ms [180 120 70]
    :prompt_size_scale_thresholds [2000 10000 50000]
    :prompt_size_scale_extra [0 2 6 10]
    :project_lazy_enabled true
    :project_lazy_disable_headless true
    :project_lazy_min_estimated_lines 5000
    :project_lazy_chunk_size 4
    :project_lazy_frame_budget_ms 6
    :project_lazy_refresh_debounce_ms 32
    :project_lazy_refresh_min_ms 8
    :project_lazy_prefilter_enabled true
    :project_source_syntax_chunk_lines 240
    :project_bootstrap_delay_ms 120
    :project_bootstrap_idle_delay_ms 140
    :prompt_forced_coalesce_ms 700
    :preview_source_switch_debounce_ms 60
    :source_syntax_refresh_debounce_ms 80
    :scroll_sync_debounce_ms 20
    :ui_animations_enabled true
    :ui_animations_time_scale 1.5
    :ui_animation_prompt_enabled true
    :ui_animation_prompt_ms 140
    :ui_animation_prompt_time_scale 1.0
    :ui_animation_preview_enabled true
    :ui_animation_preview_ms 180
    :ui_animation_preview_time_scale 1.0
    :ui_animation_info_enabled true
    :ui_animation_info_ms 220
    :ui_animation_info_time_scale 1.0
    :ui_animation_loading_enabled true
    :ui_animation_loading_ms 90
    :ui_animation_loading_time_scale 1.0
    :ui_loading_indicator true
    :ui_animation_scroll_enabled true
    :ui_animation_scroll_ms 140
    :ui_animation_scroll_time_scale 1.0
    :ui_animation_scroll_backend "native"
    :window_local_layout true
    :dep_dir_names
    {"node_modules" true
     ".venv" true
     "venv" true
     "vendor" true
     "deps" true
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
     ".pnpm-store" true}}
   :ui
   {:custom_mappings {}
    :highlight_groups {:All "Title" :Fuzzy "Number" :Regex "Special"}
    :syntax_on_init "buffer"
    :prefix "#"}
   :keymaps
   {:prompt default-prompt-keymaps
    :main default-main-keymaps
    :prompt_fallback default-prompt-fallback-keymaps}})

(fn table?
  [v]
  (= (type v) "table"))

(fn nested
  [opts k]
  (and (table? opts) (table? (. opts k)) (. opts k)))

(fn nested-in
  [root ks]
  (let [cur0 root]
    (var cur cur0)
    (var ok true)
    (each [_ k (ipairs ks)]
      (if (and ok (table? cur) (table? (. cur k)))
          (set cur (. cur k))
          (do
            (set ok false)
            (set cur nil))))
    cur))

(fn opt-value
  [opts k legacy-g default]
  (let [options (nested opts :options)]
    (if (and (table? options) (~= (. options k) nil))
        (. options k)
        (if (and (table? opts) (~= (. opts k) nil))
            (. opts k)
            (if (~= legacy-g nil)
                (or (. vim.g legacy-g) default)
                default)))))

(fn nested-value
  [opts ks default]
  (let [cur0 opts]
    (var cur cur0)
    (var found true)
    (each [_ k (ipairs ks)]
      (if (and found (table? cur) (~= (. cur k) nil))
          (set cur (. cur k))
          (do
            (set found false)
            (set cur nil))))
    (if found cur default)))

(fn resolve-keymaps
  [opts]
  (let [keymaps (nested opts :keymaps)]
    {:prompt (or (and keymaps (. keymaps :prompt))
                 (and (table? opts) (. opts :prompt_keymaps))
                 vim.g.meta_prompt_keymaps
                 (. (. M.defaults :keymaps) :prompt))
     :main (or (and keymaps (. keymaps :main))
               (and (table? opts) (. opts :main_keymaps))
               vim.g.meta_main_keymaps
               (. (. M.defaults :keymaps) :main))
     :prompt_fallback (or (and keymaps (. keymaps :prompt_fallback))
                          (and (table? opts) (. opts :prompt_fallback_keymaps))
                          vim.g.meta_prompt_fallback_keymaps
                          (. (. M.defaults :keymaps) :prompt_fallback))}))

(fn resolve-ui
  [opts]
  (let [ui (nested opts :ui)
        anim (nested-in opts [:ui :animation])]
    {:custom_mappings (or (and ui (~= (. ui :custom_mappings) nil) (. ui :custom_mappings))
                          (. vim.g "meta#custom_mappings")
                          (. (. M.defaults :ui) :custom_mappings))
     :highlight_groups (or (and ui (~= (. ui :highlight_groups) nil) (. ui :highlight_groups))
                           (. vim.g "meta#highlight_groups")
                           (. (. M.defaults :ui) :highlight_groups))
     :syntax_on_init (or (and ui (~= (. ui :syntax_on_init) nil) (. ui :syntax_on_init))
                         (. vim.g "meta#syntax_on_init")
                         (. (. M.defaults :ui) :syntax_on_init))
     :animation anim
     :prefix (or (and ui (~= (. ui :prefix) nil) (. ui :prefix))
                 (. vim.g "meta#prefix")
                 (. (. M.defaults :ui) :prefix))}))

(fn M.resolve
  [opts]
  "Public API: M.resolve."
  (let [defaults (. M.defaults :options)]
    {:options
     {:history_max (opt-value opts :history_max nil (. defaults :history_max))
      :project_max_file_bytes (opt-value opts :project_max_file_bytes :meta_project_max_file_bytes (. defaults :project_max_file_bytes))
      :project_max_total_lines (opt-value opts :project_max_total_lines :meta_project_max_total_lines (. defaults :project_max_total_lines))
      :default_include_hidden (opt-value opts :default_include_hidden :meta_project_include_hidden (. defaults :default_include_hidden))
      :default_include_ignored (opt-value opts :default_include_ignored :meta_project_include_ignored (. defaults :default_include_ignored))
      :default_include_deps (opt-value opts :default_include_deps :meta_project_include_deps (. defaults :default_include_deps))
      :default_include_binary (opt-value opts :default_include_binary :meta_project_include_binary (. defaults :default_include_binary))
      :default_include_hex (opt-value opts :default_include_hex :meta_project_include_hex (. defaults :default_include_hex))
      :default_include_files (opt-value opts :default_include_files :meta_project_include_files (. defaults :default_include_files))
      :project_rg_bin (opt-value opts :project_rg_bin :meta_project_rg_bin (. defaults :project_rg_bin))
      :project_rg_base_args (opt-value opts :project_rg_base_args :meta_project_rg_base_args (. defaults :project_rg_base_args))
      :project_rg_include_ignored_args (opt-value opts :project_rg_include_ignored_args :meta_project_rg_include_ignored_args (. defaults :project_rg_include_ignored_args))
      :project_rg_deps_exclude_globs (opt-value opts :project_rg_deps_exclude_globs :meta_project_rg_deps_exclude_globs (. defaults :project_rg_deps_exclude_globs))
      :project_fallback_glob_pattern (opt-value opts :project_fallback_glob_pattern :meta_project_fallback_glob_pattern (. defaults :project_fallback_glob_pattern))
      :info_max_lines (opt-value opts :info_max_lines :meta_info_max_lines (. defaults :info_max_lines))
      :info_min_width (opt-value opts :info_min_width :meta_info_width (. defaults :info_min_width))
      :info_max_width (opt-value opts :info_max_width :meta_info_max_width (. defaults :info_max_width))
      :context_height (opt-value opts :context_height :meta_context_height (. defaults :context_height))
      :context_around_lines (opt-value opts :context_around_lines :meta_context_around_lines (. defaults :context_around_lines))
      :context_max_blocks (opt-value opts :context_max_blocks :meta_context_max_blocks (. defaults :context_max_blocks))
      :info_file_entry_view (opt-value opts :info_file_entry_view :meta_info_file_entry_view (. defaults :info_file_entry_view))
      :prompt_update_debounce_ms (opt-value opts :prompt_update_debounce_ms :meta_prompt_update_debounce_ms (. defaults :prompt_update_debounce_ms))
      :prompt_update_idle_ms (opt-value opts :prompt_update_idle_ms :meta_prompt_update_idle_ms (. defaults :prompt_update_idle_ms))
      :prompt_short_query_extra_ms (opt-value opts :prompt_short_query_extra_ms :meta_prompt_short_query_extra_ms (. defaults :prompt_short_query_extra_ms))
      :prompt_size_scale_thresholds (opt-value opts :prompt_size_scale_thresholds :meta_prompt_size_scale_thresholds (. defaults :prompt_size_scale_thresholds))
      :prompt_size_scale_extra (opt-value opts :prompt_size_scale_extra :meta_prompt_size_scale_extra (. defaults :prompt_size_scale_extra))
      :project_lazy_enabled (opt-value opts :project_lazy_enabled :meta_project_lazy_enabled (. defaults :project_lazy_enabled))
      :project_lazy_disable_headless (opt-value opts :project_lazy_disable_headless :meta_project_lazy_disable_headless (. defaults :project_lazy_disable_headless))
      :project_lazy_min_estimated_lines (opt-value opts :project_lazy_min_estimated_lines :meta_project_lazy_min_estimated_lines (. defaults :project_lazy_min_estimated_lines))
      :project_lazy_chunk_size (opt-value opts :project_lazy_chunk_size :meta_project_lazy_chunk_size (. defaults :project_lazy_chunk_size))
      :project_lazy_frame_budget_ms (opt-value opts :project_lazy_frame_budget_ms :meta_project_lazy_frame_budget_ms (. defaults :project_lazy_frame_budget_ms))
      :project_lazy_refresh_debounce_ms (opt-value opts :project_lazy_refresh_debounce_ms :meta_project_lazy_refresh_debounce_ms (. defaults :project_lazy_refresh_debounce_ms))
      :project_lazy_refresh_min_ms (opt-value opts :project_lazy_refresh_min_ms :meta_project_lazy_refresh_min_ms (. defaults :project_lazy_refresh_min_ms))
      :project_lazy_prefilter_enabled (opt-value opts :project_lazy_prefilter_enabled :meta_project_lazy_prefilter_enabled (. defaults :project_lazy_prefilter_enabled))
      :project_source_syntax_chunk_lines (opt-value opts :project_source_syntax_chunk_lines :meta_project_source_syntax_chunk_lines (. defaults :project_source_syntax_chunk_lines))
      :project_bootstrap_delay_ms (opt-value opts :project_bootstrap_delay_ms :meta_project_bootstrap_delay_ms (. defaults :project_bootstrap_delay_ms))
      :project_bootstrap_idle_delay_ms (opt-value opts :project_bootstrap_idle_delay_ms :meta_project_bootstrap_idle_delay_ms (. defaults :project_bootstrap_idle_delay_ms))
      :prompt_forced_coalesce_ms (opt-value opts :prompt_forced_coalesce_ms :meta_prompt_forced_coalesce_ms (. defaults :prompt_forced_coalesce_ms))
      :preview_source_switch_debounce_ms (opt-value opts :preview_source_switch_debounce_ms :meta_preview_source_switch_debounce_ms (. defaults :preview_source_switch_debounce_ms))
      :source_syntax_refresh_debounce_ms (opt-value opts :source_syntax_refresh_debounce_ms :meta_source_syntax_refresh_debounce_ms (. defaults :source_syntax_refresh_debounce_ms))
      :scroll_sync_debounce_ms (opt-value opts :scroll_sync_debounce_ms :meta_scroll_sync_debounce_ms (. defaults :scroll_sync_debounce_ms))
      :ui_animations_enabled (nested-value opts [:ui :animation :enabled]
                                           (opt-value opts :ui_animations_enabled :meta_ui_animations_enabled
                                                      (opt-value opts :ui_animate_enter :meta_ui_animate_enter (. defaults :ui_animations_enabled))))
      :ui_animations_time_scale (nested-value opts [:ui :animation :time_scale]
                                              (opt-value opts :ui_animations_time_scale :meta_ui_animations_time_scale (. defaults :ui_animations_time_scale)))
      :ui_animation_prompt_enabled (nested-value opts [:ui :animation :prompt :enabled]
                                                   (opt-value opts :ui_animation_prompt_enabled :meta_ui_animation_prompt_enabled (. defaults :ui_animation_prompt_enabled)))
      :ui_animation_prompt_ms (. defaults :ui_animation_prompt_ms)
      :ui_animation_prompt_time_scale (nested-value opts [:ui :animation :prompt :time_scale]
                                                      (opt-value opts :ui_animation_prompt_time_scale :meta_ui_animation_prompt_time_scale
                                                                 (. defaults :ui_animation_prompt_time_scale)))
      :ui_animation_preview_enabled (nested-value opts [:ui :animation :preview :enabled]
                                                    (opt-value opts :ui_animation_preview_enabled :meta_ui_animation_preview_enabled (. defaults :ui_animation_preview_enabled)))
      :ui_animation_preview_ms (. defaults :ui_animation_preview_ms)
      :ui_animation_preview_time_scale (nested-value opts [:ui :animation :preview :time_scale]
                                                       (opt-value opts :ui_animation_preview_time_scale :meta_ui_animation_preview_time_scale
                                                                  (. defaults :ui_animation_preview_time_scale)))
      :ui_animation_info_enabled (nested-value opts [:ui :animation :info :enabled]
                                                 (opt-value opts :ui_animation_info_enabled :meta_ui_animation_info_enabled (. defaults :ui_animation_info_enabled)))
      :ui_animation_info_ms (. defaults :ui_animation_info_ms)
      :ui_animation_info_time_scale (nested-value opts [:ui :animation :info :time_scale]
                                                    (opt-value opts :ui_animation_info_time_scale :meta_ui_animation_info_time_scale
                                                               (. defaults :ui_animation_info_time_scale)))
      :ui_animation_loading_enabled (nested-value opts [:ui :animation :loading :enabled]
                                                    (opt-value opts :ui_animation_loading_enabled :meta_ui_animation_loading_enabled (. defaults :ui_animation_loading_enabled)))
      :ui_animation_loading_ms (. defaults :ui_animation_loading_ms)
      :ui_animation_loading_time_scale (nested-value opts [:ui :animation :loading :time_scale]
                                                       (opt-value opts :ui_animation_loading_time_scale :meta_ui_animation_loading_time_scale
                                                                  (. defaults :ui_animation_loading_time_scale)))
      :ui_loading_indicator (nested-value opts [:ui :animation :loading_indicator]
                                          (opt-value opts :ui_loading_indicator :meta_ui_loading_indicator (. defaults :ui_loading_indicator)))
      :ui_animation_scroll_enabled (nested-value opts [:ui :animation :scroll :enabled]
                                                   (opt-value opts :ui_animation_scroll_enabled :meta_ui_animation_scroll_enabled (. defaults :ui_animation_scroll_enabled)))
      :ui_animation_scroll_ms (. defaults :ui_animation_scroll_ms)
      :ui_animation_scroll_time_scale (nested-value opts [:ui :animation :scroll :time_scale]
                                                      (opt-value opts :ui_animation_scroll_time_scale :meta_ui_animation_scroll_time_scale
                                                                 (. defaults :ui_animation_scroll_time_scale)))
      :ui_animation_scroll_backend (nested-value opts [:ui :animation :scroll :backend]
                                                   (opt-value opts :ui_animation_scroll_backend :meta_ui_animation_scroll_backend
                                                              (. defaults :ui_animation_scroll_backend)))
      :window_local_layout (if (= (opt-value opts :window_local_layout :meta_window_local_layout (. defaults :window_local_layout)) nil)
                               true
                               (opt-value opts :window_local_layout :meta_window_local_layout (. defaults :window_local_layout)))
      :dep_dir_names (opt-value opts :dep_dir_names nil (. defaults :dep_dir_names))}
     :keymaps (resolve-keymaps opts)
     :ui (resolve-ui opts)}))

(fn M.apply-router-defaults
  [router _vim opts]
  "Public API: M.apply-router-defaults."
  (let [resolved (M.resolve opts)
        options (. resolved :options)
        keymaps (. resolved :keymaps)]
    (set router.option-state options)
    (set router.keymap-state keymaps)
    (set router.history-max (. options :history_max))
    (set router.project-max-file-bytes (. options :project_max_file_bytes))
    (set router.project-max-total-lines (. options :project_max_total_lines))
    (set router.default-include-hidden (. options :default_include_hidden))
    (set router.default-include-ignored (. options :default_include_ignored))
    (set router.default-include-deps (. options :default_include_deps))
    (set router.default-include-binary (. options :default_include_binary))
    (set router.default-include-hex (. options :default_include_hex))
    (set router.default-include-files (. options :default_include_files))
    (set router.project-rg-bin (. options :project_rg_bin))
    (set router.project-rg-base-args (. options :project_rg_base_args))
    (set router.project-rg-include-ignored-args (. options :project_rg_include_ignored_args))
    (set router.project-rg-deps-exclude-globs (. options :project_rg_deps_exclude_globs))
    (set router.project-fallback-glob-pattern (. options :project_fallback_glob_pattern))
    (set router.info-max-lines (. options :info_max_lines))
    (set router.info-min-width (. options :info_min_width))
    (set router.info-max-width (. options :info_max_width))
    (set router.context-height (. options :context_height))
    (set router.context-around-lines (. options :context_around_lines))
    (set router.context-max-blocks (. options :context_max_blocks))
    (set router.info-file-entry-view (. options :info_file_entry_view))
    (set router.prompt-update-debounce-ms (. options :prompt_update_debounce_ms))
    (set router.prompt-update-idle-ms (. options :prompt_update_idle_ms))
    (set router.prompt-short-query-extra-ms (. options :prompt_short_query_extra_ms))
    (set router.prompt-size-scale-thresholds (. options :prompt_size_scale_thresholds))
    (set router.prompt-size-scale-extra (. options :prompt_size_scale_extra))
    (set router.project-file-cache {})
    (set router.project-lazy-enabled (. options :project_lazy_enabled))
    (set router.project-lazy-disable-headless (. options :project_lazy_disable_headless))
    (set router.project-lazy-min-estimated-lines (. options :project_lazy_min_estimated_lines))
    (set router.project-lazy-chunk-size (. options :project_lazy_chunk_size))
    (set router.project-lazy-frame-budget-ms (. options :project_lazy_frame_budget_ms))
    (set router.project-lazy-refresh-debounce-ms (. options :project_lazy_refresh_debounce_ms))
    (set router.project-lazy-refresh-min-ms (. options :project_lazy_refresh_min_ms))
    (set router.project-lazy-prefilter-enabled (. options :project_lazy_prefilter_enabled))
    (set router.project-bootstrap-delay-ms (. options :project_bootstrap_delay_ms))
    (set router.project-bootstrap-idle-delay-ms (. options :project_bootstrap_idle_delay_ms))
    (set router.prompt-forced-coalesce-ms (. options :prompt_forced_coalesce_ms))
    (set router.preview-source-switch-debounce-ms (. options :preview_source_switch_debounce_ms))
    (set router.source-syntax-refresh-debounce-ms (. options :source_syntax_refresh_debounce_ms))
    (set router.scroll-sync-debounce-ms (. options :scroll_sync_debounce_ms))
    (set router.ui-animations-enabled (. options :ui_animations_enabled))
    (set router.ui-animations-time-scale (. options :ui_animations_time_scale))
    (set router.ui-animation-prompt-enabled (. options :ui_animation_prompt_enabled))
    (set router.ui-animation-prompt-ms (. options :ui_animation_prompt_ms))
    (set router.ui-animation-prompt-time-scale (. options :ui_animation_prompt_time_scale))
    (set router.ui-animation-preview-enabled (. options :ui_animation_preview_enabled))
    (set router.ui-animation-preview-ms (. options :ui_animation_preview_ms))
    (set router.ui-animation-preview-time-scale (. options :ui_animation_preview_time_scale))
    (set router.ui-animation-info-enabled (. options :ui_animation_info_enabled))
    (set router.ui-animation-info-ms (. options :ui_animation_info_ms))
    (set router.ui-animation-info-time-scale (. options :ui_animation_info_time_scale))
    (set router.ui-animation-loading-enabled (. options :ui_animation_loading_enabled))
    (set router.ui-animation-loading-ms (. options :ui_animation_loading_ms))
    (set router.ui-animation-loading-time-scale (. options :ui_animation_loading_time_scale))
    (set router.ui-loading-indicator (. options :ui_loading_indicator))
    (set router.ui-animation-scroll-enabled (. options :ui_animation_scroll_enabled))
    (set router.ui-animation-scroll-ms (. options :ui_animation_scroll_ms))
    (set router.ui-animation-scroll-time-scale (. options :ui_animation_scroll_time_scale))
    (set router.ui-animation-scroll-backend (. options :ui_animation_scroll_backend))
    (set router.window-local-layout (. options :window_local_layout))
    (set router.default-prompt-keymaps (. (. M.defaults :keymaps) :prompt))
    (set router.default-main-keymaps (. (. M.defaults :keymaps) :main))
    (set router.default-prompt-fallback-keymaps (. (. M.defaults :keymaps) :prompt_fallback))
    (set router.prompt-keymaps (. keymaps :prompt))
    (set router.main-keymaps (. keymaps :main))
    (set router.prompt-fallback-keymaps (. keymaps :prompt_fallback))
    (set router.dep-dir-names (. options :dep_dir_names))
    resolved))

M
