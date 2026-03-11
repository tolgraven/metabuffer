(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local meta_window_mod (require :metabuffer.window.metawindow))
(local floating_window_mod (require :metabuffer.window.floating))
(local preview_window_mod (require :metabuffer.window.preview))
(local info_window_mod (require :metabuffer.window.info))
(local history_browser_window_mod (require :metabuffer.window.history_browser))
(local project_source_mod (require :metabuffer.project.source))
(local base_buffer (require :metabuffer.buffer.base))
(local session_view (require :metabuffer.session.view))
(local debug (require :metabuffer.debug))
(local config (require :metabuffer.config))
(local query_mod (require :metabuffer.query))
(local history_store (require :metabuffer.history_store))
(local prompt_hooks_mod (require :metabuffer.prompt.hooks))
(local router_util_mod (require :metabuffer.router.util))
(local router_history_mod (require :metabuffer.router.history))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local router_query_flow_mod (require :metabuffer.router.query_flow))
(local router_actions_mod (require :metabuffer.router.actions))

(local M {})

(fn sync-prompt-buffer-name!
  [session]
  (when (and session
             session.prompt-buf
             (vim.api.nvim_buf_is_valid session.prompt-buf)
             session.meta
             session.meta.buf
             (= (type session.meta.buf.name) "string")
             (~= session.meta.buf.name ""))
    (pcall
      vim.api.nvim_buf_set_name
      session.prompt-buf
      (.. session.meta.buf.name " [Prompt]"))))

(set M.instances {})
(set M.active-by-source {})
(set M.active-by-prompt {})
(var update-info-window nil)
(var apply-prompt-lines nil)
(var preview-window nil)
(var info-window nil)
(var history-browser-window nil)
(var history-api nil)
(var query-flow-deps nil)
(var actions-deps nil)
(fn M.configure
  [opts]
  "Public API: M.configure."
  (config.apply-router-defaults M vim opts))

(M.configure nil)
(fn debug-log [msg] (debug.log "router" msg))

(local prompt-scheduler-ctx
  {:active-by-prompt M.active-by-prompt
   :apply-prompt-lines (fn [session]
                         (apply-prompt-lines session))
   :prompt-update-delay-ms (fn [session]
                             (router_prompt_mod.prompt-update-delay-ms
                               M
                               query_mod
                               router_util_mod.prompt-lines
                               session))
   :now-ms router_prompt_mod.now-ms
   :cancel-prompt-update! router_prompt_mod.cancel-prompt-update!})

(set preview-window
  (preview_window_mod.new
    {:floating-window-mod floating_window_mod
     :selected-ref router_util_mod.selected-ref
     :read-file-lines-cached (fn [path]
                               (router_util_mod.read-file-lines-cached M path))
     :is-active-session (fn [session]
                          (and session
                               session.prompt-buf
                               (= (. M.active-by-prompt session.prompt-buf) session)))
     :debug-log debug-log
     :source-switch-debounce-ms M.preview-source-switch-debounce-ms}))

(set info-window
  (let [candidate
        (info_window_mod.new
          {:floating-window-mod floating_window_mod
           :info-min-width M.info-min-width
           :info-max-width M.info-max-width
           :info-max-lines M.info-max-lines
           :info-height router_util_mod.info-height
           :debug-log debug-log
           :read-file-lines-cached (fn [path]
                                     (router_util_mod.read-file-lines-cached M path))
           :update-preview (fn [session]
                             (preview-window.maybe-update-for-selection! session))})]
    (if (= (type candidate) "function")
        {:update! candidate
         :close-window! (fn [_] nil)}
        candidate)))

(set history-browser-window
  (history_browser_window_mod.new
    {:floating-window-mod floating_window_mod}))

(set history-api
  (router_history_mod.new
    {:history-store history_store
     :router-util-mod router_util_mod
     :query-mod query_mod
     :history-browser-window history-browser-window
     :settings M}))

(set update-info-window
  (fn [session refresh-lines]
    (when (and info-window info-window.update!)
      (info-window.update! session refresh-lines))))

(local project-source
  (project_source_mod.new
    {:settings M
     :truthy? query_mod.truthy?
     :selected-ref router_util_mod.selected-ref
     :canonical-path router_util_mod.canonical-path
     :current-buffer-path router_util_mod.current-buffer-path
     :path-under-root? router_util_mod.path-under-root?
     :allow-project-path? (fn [rel include-hidden include-deps]
                            (router_util_mod.allow-project-path? M rel include-hidden include-deps))
     :project-file-list (fn [root include-hidden include-ignored include-deps]
                          (router_util_mod.project-file-list M root include-hidden include-ignored include-deps))
     :read-file-lines-cached (fn [path]
                               (router_util_mod.read-file-lines-cached M path))
     :session-active? (fn [session]
                        (router_util_mod.session-active? M.active-by-prompt session))
     :lazy-streaming-allowed? (fn [session]
                                (router_util_mod.lazy-streaming-allowed? M query_mod session))
     :on-prompt-changed (fn [prompt-buf force]
                          (M.on-prompt-changed prompt-buf force))
     :prompt-has-active-query? (fn [session]
                                 (router_prompt_mod.prompt-has-active-query?
                                   query_mod
                                   router_util_mod.prompt-lines
                                   session))
     :now-ms router_prompt_mod.now-ms
     :prompt-update-delay-ms (fn [session]
                               (router_prompt_mod.prompt-update-delay-ms
                                 M
                                 query_mod
                                 router_util_mod.prompt-lines
                                 session))
     :schedule-prompt-update! (fn [session wait-ms]
                                (router_prompt_mod.schedule-prompt-update!
                                  prompt-scheduler-ctx
                                  session
                                  wait-ms))
     :restore-meta-view! session_view.restore-meta-view!
     :update-info-window update-info-window}))

(set query-flow-deps
  {:active-by-prompt M.active-by-prompt
   :query-mod query_mod
   :project-source project-source
   :update-info-window update-info-window
   :settings M
   :prompt-scheduler-ctx prompt-scheduler-ctx
   :merge-history-into-session! history-api.merge-history-into-session!
   :save-current-prompt-tag! history-api.save-current-prompt-tag!
   :restore-saved-prompt-tag! history-api.restore-saved-prompt-tag!
   :open-saved-browser! (fn [session]
                          (history-api.open-history-browser! session "saved"))
   :apply-prompt-lines (fn [session]
                         (apply-prompt-lines session))})

(fn M._store_vars
  [meta]
  "Public API: M._store_vars."
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup
  [meta]
  "Public API: M._wrapup."
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn remove-session
  [session]
  (router_actions_mod.remove-session! actions-deps session))

(set apply-prompt-lines
  (fn [session]
    (router_query_flow_mod.apply-prompt-lines! query-flow-deps session)))

(set actions-deps
  {:active-by-source M.active-by-source
   :active-by-prompt M.active-by-prompt
   :history-api history-api
   :history-store history_store
   :router-util-mod router_util_mod
   :router-prompt-mod router_prompt_mod
   :session-view session_view
   :base-buffer base_buffer
   :info-window info-window
   :preview-window preview-window
   :project-source project-source
   :update-info-window update-info-window
   :sync-prompt-buffer-name! sync-prompt-buffer-name!
   :apply-prompt-lines apply-prompt-lines
   :wrapup M._wrapup})

(fn M.on-prompt-changed
  [prompt-buf force event-tick]
  "Entry point for prompt edits; keeps typing fast by deferring matcher work."
  (router_query_flow_mod.on-prompt-changed!
    query-flow-deps
    prompt-buf
    force
    event-tick)
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session session.history-browser-active)
      (history-api.refresh-history-browser! session))))

(fn M.accept
  [prompt-buf]
  "Accept prompt or apply selected history-browser item."
  (router_actions_mod.accept! actions-deps prompt-buf))

(fn M.cancel
  [prompt-buf]
  "Close history-browser first, otherwise cancel Meta prompt."
  (router_actions_mod.cancel! actions-deps prompt-buf))

(fn M.finish
  [kind prompt-buf]
  "Public API: M.finish."
  (router_actions_mod.finish! actions-deps kind prompt-buf))

(fn M.move-selection
  [prompt-buf delta]
  "Public API: M.move-selection."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                     (let [meta session.meta
                           max (# meta.buf.indices)]
                       (when (> max 0)
                         (set meta.selected_index (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
                         (let [row (+ meta.selected_index 1)]
                           (when (vim.api.nvim_win_is_valid meta.win.window)
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0])))
                         (pcall meta.refresh_statusline)
                         (pcall update-info-window session false))))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn can-refresh-source-syntax?
  [session]
  (let [buf (and session session.meta session.meta.buf)]
    (and session
         session.project-mode
         buf
         buf.show-source-separators
         (= buf.syntax-type "buffer"))))

(fn schedule-source-syntax-refresh!
  [session]
  (when (can-refresh-source-syntax? session)
    (set session.syntax-refresh-dirty true)
    (when-not session.syntax-refresh-pending
      (set session.syntax-refresh-pending true)
      (vim.defer_fn
        (fn []
          (set session.syntax-refresh-pending false)
          (when (and session
                     session.prompt-buf
                     (= (. M.active-by-prompt session.prompt-buf) session))
            (when session.syntax-refresh-dirty
              (set session.syntax-refresh-dirty false)
              (pcall session.meta.buf.apply-source-syntax-regions))
            ;; If additional scroll events arrived while refreshing, ensure we
            ;; run one trailing update.
            (when session.syntax-refresh-dirty
              (schedule-source-syntax-refresh! session))))
        (or M.source-syntax-refresh-debounce-ms 80)))))

(fn M.scroll-main
  [prompt-buf action]
  "Public API: M.scroll-main."
  (let [session (. M.active-by-prompt prompt-buf)]
    (when (and session (vim.api.nvim_win_is_valid session.meta.win.window))
      (let [runner (fn []
                     (vim.api.nvim_win_call session.meta.win.window
                       (fn []
                         (let [line-count (vim.api.nvim_buf_line_count session.meta.buf.buffer)
                               win-height (math.max 1 (vim.api.nvim_win_get_height session.meta.win.window))
                               half-step (math.max 1 (math.floor (/ win-height 2)))
                               page-step (math.max 1 (- win-height 2))
                               step (if (or (= action "line-down") (= action "line-up"))
                                        1
                                        (or (= action "half-down") (= action "half-up"))
                                        half-step
                                        page-step)
                               dir (if (or (= action "line-down") (= action "half-down") (= action "page-down")) 1 -1)
                               max-top (math.max 1 (+ (- line-count win-height) 1))
                               view (vim.fn.winsaveview)
                               old-top (. view :topline)
                               old-lnum (. view :lnum)
                               old-col (or (. view :col) 0)
                               row-off (math.max 0 (- old-lnum old-top))
                               new-top (math.max 1 (math.min (+ old-top (* dir step)) max-top))
                               new-lnum (math.max 1 (math.min (+ new-top row-off) line-count))]
                           (set (. view :topline) new-top)
                           (set (. view :lnum) new-lnum)
                           (set (. view :col) old-col)
                           (vim.fn.winrestview view))))
                     (session_view.sync-selected-from-main-cursor! session)
                     (pcall session.meta.refresh_statusline)
                     (pcall update-info-window session false))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn maybe-sync-from-main!
  [session force-refresh]
  (session_view.maybe-sync-from-main!
    session
    force-refresh
    {:active-by-prompt M.active-by-prompt
     :schedule-source-syntax-refresh! schedule-source-syntax-refresh!
     :update-info-window update-info-window}))

(fn schedule-scroll-sync!
  [session]
  (session_view.schedule-scroll-sync!
    session
    {:scroll-sync-debounce-ms M.scroll-sync-debounce-ms
     :maybe-sync-from-main! maybe-sync-from-main!}))

(fn M.history-or-move
  [prompt-buf delta]
  "Public API: M.history-or-move."
  (history-api.history-or-move
    prompt-buf
    delta
    M.active-by-prompt
    M.move-selection))

(fn M.last-prompt-entry
  [prompt-buf]
  "Return most recent prompt history entry."
  (history-api.last-prompt-entry prompt-buf M.active-by-prompt))

(fn M.last-prompt-token
  [prompt-buf]
  "Return final token of most recent prompt history entry."
  (history-api.last-prompt-token prompt-buf M.active-by-prompt))

(fn M.last-prompt-tail
  [prompt-buf]
  "Return latest prompt entry except its first token."
  (history-api.last-prompt-tail prompt-buf M.active-by-prompt))

(fn M.saved-prompt-entry
  [tag]
  "Return saved prompt text by tag."
  (history-api.saved-prompt-entry tag))

(fn M.prompt-home
  [prompt-buf]
  "Move prompt cursor to start of current line."
  (router_prompt_mod.prompt-home! M.active-by-prompt prompt-buf))

(fn M.prompt-end
  [prompt-buf]
  "Move prompt cursor to end of current line."
  (router_prompt_mod.prompt-end! M.active-by-prompt prompt-buf))

(fn M.prompt-kill-backward
  [prompt-buf]
  "Kill from line start to cursor and store in prompt yank register."
  (router_prompt_mod.prompt-kill-backward! M.active-by-prompt prompt-buf))

(fn M.prompt-kill-forward
  [prompt-buf]
  "Kill from cursor to end of current line and store in prompt yank register."
  (router_prompt_mod.prompt-kill-forward! M.active-by-prompt prompt-buf))

(fn M.prompt-yank
  [prompt-buf]
  "Insert prompt yank register content at cursor."
  (router_prompt_mod.prompt-yank! M.active-by-prompt prompt-buf))

(fn M.prompt-insert-text
  [prompt-buf text]
  "Insert arbitrary text at prompt cursor."
  (router_prompt_mod.prompt-insert-text! M.active-by-prompt prompt-buf text))

(fn M.insert-last-prompt
  [prompt-buf]
  "Insert most recent prompt history entry at cursor."
  (router_prompt_mod.insert-last-prompt! M.active-by-prompt history-api prompt-buf))

(fn M.insert-last-token
  [prompt-buf]
  "Insert last token from most recent prompt history entry at cursor."
  (router_prompt_mod.insert-last-token! M.active-by-prompt history-api prompt-buf))

(fn M.insert-last-tail
  [prompt-buf]
  "Insert most recent prompt entry except first token."
  (router_prompt_mod.insert-last-tail! M.active-by-prompt history-api prompt-buf))

(fn M.negate-current-token
  [prompt-buf]
  "Toggle ! prefix on token under cursor in prompt insert mode."
  (router_prompt_mod.negate-current-token! M.active-by-prompt prompt-buf))

(fn M.open-history-searchback
  [prompt-buf]
  "Open floating searchback browser from prompt (<C-r>)."
  (router_actions_mod.open-history-searchback! actions-deps prompt-buf))

(fn M.merge-history-cache
  [prompt-buf]
  "Merge persisted prompt history into this session's private history cache."
  (router_actions_mod.merge-history-cache! actions-deps prompt-buf))

(fn M.exclude-symbol-under-cursor
  [prompt-buf]
  "Append !<cword> into prompt query."
  (router_actions_mod.exclude-symbol-under-cursor! actions-deps prompt-buf))

(fn M.insert-symbol-under-cursor
  [prompt-buf]
  "Append <cword> from main results window into prompt query."
  (router_actions_mod.insert-symbol-under-cursor! actions-deps prompt-buf))

(fn M.accept-main
  [prompt-buf]
  "Accept current selection from the main results window."
  (router_actions_mod.accept-main! actions-deps prompt-buf))

(fn M.toggle-scan-option
  [prompt-buf which]
  "Toggle include-hidden/include-ignored/include-deps scan flags."
  (router_actions_mod.toggle-scan-option! actions-deps prompt-buf which))

(fn M.toggle-project-mode
  [prompt-buf]
  "Public API: M.toggle-project-mode."
  (router_actions_mod.toggle-project-mode! actions-deps prompt-buf))

(fn M.toggle-info-file-entry-view
  [prompt-buf]
  "Cycle info-window file-entry rendering mode."
  (router_actions_mod.toggle-info-file-entry-view! actions-deps prompt-buf))

(fn register-prompt-hooks
  [session]
  (let [hooks
        (prompt_hooks_mod.new
          {:mark-prompt-buffer! router_util_mod.mark-prompt-buffer!
           :default-prompt-keymaps M.prompt-keymaps
           :default-main-keymaps M.main-keymaps
           :active-by-prompt M.active-by-prompt
           :on-prompt-changed M.on-prompt-changed
           :update-info-window update-info-window
           :maybe-sync-from-main! maybe-sync-from-main!
           :schedule-scroll-sync! schedule-scroll-sync!})]
    (hooks.register! M session)))

(fn M.start
  [query mode _meta project-mode]
  "Create a Meta session and wire prompt/result/project orchestration."
  (pcall vim.cmd "silent! nohlsearch")
  (let [start-query (or query "")
        latest-history (history-api.history-latest nil)
        expanded-query (if (= start-query "!!")
                           latest-history
                           (= start-query "!$")
                           (history-api.history-entry-token latest-history)
                           (= start-query "!^!")
                           (history-api.history-entry-tail latest-history)
                           start-query)
        parsed-query (query_mod.parse-query-text expanded-query)
        query0 (. parsed-query :query)
        start-hidden (if-some [v (. parsed-query :include-hidden)]
                             v
                             (query_mod.truthy? M.default-include-hidden))
        start-ignored (if-some [v (. parsed-query :include-ignored)]
                              v
                              (query_mod.truthy? M.default-include-ignored))
        start-deps (if-some [v (. parsed-query :include-deps)]
                           v
                           (query_mod.truthy? M.default-include-deps))
        start-files (if-some [v (. parsed-query :include-files)]
                            v
                            (query_mod.truthy? M.default-include-files))
        start-prefilter (if-some [v (. parsed-query :prefilter)]
                                v
                                (query_mod.truthy? M.project-lazy-prefilter-enabled))
        start-lazy (if-some [v (. parsed-query :lazy)]
                           v
                           (query_mod.truthy? M.project-lazy-enabled))
        query query0]
  (let [source-buf (vim.api.nvim_get_current_buf)]
    (when (. M.active-by-source source-buf)
      (remove-session (. M.active-by-source source-buf)))
    (let [origin-win (vim.api.nvim_get_current_win)
          origin-buf source-buf
          source-view (vim.fn.winsaveview)
          _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
          condition (session_view.setup-state query mode source-view)
          curr (meta_mod.new vim condition)]
    (set curr.project-mode (or project-mode false))
    (base_buffer.switch-buf curr.buf.buffer)
    (router_util_mod.ensure-source-refs! curr)
    (let [initial-lines (if (and query (~= query ""))
                            (vim.split query "\n" {:plain true})
                            [""])
          prompt-win (prompt_window_mod.new
                       vim
                       {:height (router_util_mod.prompt-height)
                        :window-local-layout M.window-local-layout
                        :origin-win origin-win})
          prompt-buf prompt-win.buffer
          session {:source-buf source-buf
                   :origin-win origin-win
                   :origin-buf origin-buf
                   :source-view source-view
                   :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
                   :prompt-win prompt-win.window
                   :prompt-buf prompt-buf
                   :window-local-layout M.window-local-layout
                   :prompt-keymaps M.prompt-keymaps
                   :main-keymaps M.main-keymaps
                   :prompt-fallback-keymaps M.prompt-fallback-keymaps
                   :info-file-entry-view (or M.info-file-entry-view "meta")
                   :initial-prompt-text (table.concat initial-lines "\n")
                   :last-prompt-text (table.concat initial-lines "\n")
                   :last-history-text ""
                   :history-index 0
                   :history-cache (vim.deepcopy (history_store.list))
                   :prompt-update-pending false
                   :prompt-update-dirty false
                   :prompt-change-seq 0
                   :prompt-last-apply-ms 0
                   :prompt-last-event-text (table.concat initial-lines "\n")
                   :initial-query-active (query_mod.query-lines-has-active? (. parsed-query :lines))
                   :startup-initializing true
                   :project-mode (or project-mode false)
                   :include-hidden start-hidden
                   :include-ignored start-ignored
                   :include-deps start-deps
                   :include-files start-files
                   :effective-include-hidden start-hidden
                   :effective-include-ignored start-ignored
                   :effective-include-deps start-deps
                   :effective-include-files start-files
                   :project-bootstrap-pending false
                   :project-bootstrap-token 0
                   :project-bootstrap-delay-ms (if (query_mod.query-lines-has-active? (. parsed-query :lines))
                                                   M.project-bootstrap-delay-ms
                                                   M.project-bootstrap-idle-delay-ms)
                   :project-bootstrapped (not (or project-mode false))
                   :prefilter-mode start-prefilter
                   :lazy-mode start-lazy
                   :last-parsed-query {:lines (if (and query (~= query ""))
                                                  (vim.split query "\n" {:plain true})
                                                  [""])
                                       :include-hidden start-hidden
                                       :include-ignored start-ignored
                                       :include-deps start-deps
                                       :include-files start-files
                                       :file-lines (or (. parsed-query :file-lines) [])
                                       :prefilter start-prefilter
                                       :lazy start-lazy}
                   :file-query-lines (or (. parsed-query :file-lines) [])
                   :single-content (vim.deepcopy curr.buf.content)
                   :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                   :meta curr}]
      (let [initial-query-active session.initial-query-active]
        (if session.project-mode
            (project-source.apply-minimal-source-set! session)
            (project-source.apply-source-set! session))
        (set curr.status-win (meta_window_mod.new vim prompt-win.window))
        ;; Statusline info should live in prompt window, not result split.
        (curr.win.set-statusline "")
        ;; Initialize/render after prompt split exists so we avoid an extra
        ;; post-split view correction pass that can visually "flash" scroll.
        (curr.on-init)
        (sync-prompt-buffer-name! session)
        ;; Ensure initial selection/view is anchored before attaching prompt
        ;; hooks that may sync from main-window cursor events.
        (when session.project-mode
          (session_view.restore-meta-view! curr session.source-view))
        (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
        (router_util_mod.mark-prompt-buffer! prompt-buf)
        (register-prompt-hooks session)
        (set (. M.active-by-source source-buf) session)
        (set (. M.active-by-prompt prompt-buf) session)
        (when-not (and session.project-mode (not initial-query-active))
          (apply-prompt-lines session))
        (vim.api.nvim_set_current_win prompt-win.window)
        (let [row (math.max 1 (# initial-lines))
              line (or (. initial-lines row) "")
              col (# line)]
          (pcall vim.api.nvim_win_set_cursor prompt-win.window [row col]))
        (vim.cmd "startinsert")
        (vim.schedule
          (fn []
            (set session.startup-initializing false)
            (when (and session.project-mode (not session.project-bootstrapped))
              ;; Start project lazy/eager expansion as soon as UI is ready,
              ;; independent of prompt input.
              (project-source.schedule-project-bootstrap! session 0))))
        (when (and session.project-mode (not initial-query-active))
          ;; Keep startup critical path lean; refresh auxiliary UI right after.
          (vim.schedule
            (fn []
              (when (= (. M.active-by-prompt session.prompt-buf) session)
                (pcall curr.refresh_statusline)
                (pcall update-info-window session)))))
        (set (. M.instances source-buf) curr)
        curr))))))

(fn M.sync
  [meta query]
  "Public API: M.sync."
  (when-not meta
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (meta.set-query-lines (if (and query (~= query "")) [query] []))
    (meta.on-update 0)
    (M._store_vars meta)
    meta))

(fn M.push
  [meta]
  "Public API: M.push."
  (when-not meta
    (vim.notify "No Meta instance" vim.log.levels.WARN))
  (when meta
    (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
      (meta.buf.push-visible-lines lines))))

(fn M.entry_start
  [query _bang]
  "Public API: M.entry_start."
  (M.start query "start" nil _bang))

(fn M.entry_resume
  [query]
  "Public API: M.entry_resume."
  (M.start query "resume" nil))

(fn M.entry_sync
  [query]
  "Public API: M.entry_sync."
  (let [key (vim.api.nvim_get_current_buf)]
    (M.sync (. M.instances key) query)))

(fn M.entry_push
  []
  "Public API: M.entry_push."
  (let [key (vim.api.nvim_get_current_buf)]
    (M.push (. M.instances key))))

(fn M.entry_cursor_word
  [resume]
  "Public API: M.entry_cursor_word."
  (let [w (vim.fn.expand "<cword>")]
    (if resume
        (M.entry_resume w)
        (M.entry_start w false))))

M
