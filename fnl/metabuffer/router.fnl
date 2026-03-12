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
(local sign_mod (require :metabuffer.sign))
(local prompt_hooks_mod (require :metabuffer.prompt.hooks))
(local router_util_mod (require :metabuffer.router.util))
(local router_history_mod (require :metabuffer.router.history))
(local router_prompt_mod (require :metabuffer.router.prompt))
(local router_query_flow_mod (require :metabuffer.router.query_flow))
(local router_actions_mod (require :metabuffer.router.actions))
(local router_navigation_mod (require :metabuffer.router.navigation))
(local router_session_mod (require :metabuffer.router.session))

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
(var navigation-deps nil)
(var session-deps nil)
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
    (when session
      (if session.ui-hidden
          (when (and info-window info-window.close-window!)
            (info-window.close-window! session))
          (when (and info-window info-window.update!)
            (info-window.update! session refresh-lines))))))

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
   :refresh-change-signs! sign_mod.refresh-change-signs!
   :capture-sign-baseline! sign_mod.capture-baseline!
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
   :settings M
   :history-api history-api
   :history-store history_store
   :sign-mod sign_mod
   :prompt-window-mod prompt_window_mod
   :meta-window-mod meta_window_mod
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

(set navigation-deps
  {:active-by-prompt M.active-by-prompt
   :update-info-window update-info-window
   :session-view session_view
   :scroll-sync-debounce-ms M.scroll-sync-debounce-ms
   :source-syntax-refresh-debounce-ms M.source-syntax-refresh-debounce-ms})

(set session-deps
  {:router-api M
   :settings M
   :history-api history-api
   :query-mod query_mod
   :remove-session! remove-session
   :active-by-source M.active-by-source
   :active-by-prompt M.active-by-prompt
   :instances M.instances
   :session-view session_view
   :meta-mod meta_mod
   :base-buffer base_buffer
   :router-util-mod router_util_mod
   :prompt-window-mod prompt_window_mod
   :project-source project-source
   :meta-window-mod meta_window_mod
   :history-store history_store
   :sign-mod sign_mod
   :sync-prompt-buffer-name! sync-prompt-buffer-name!
   :apply-prompt-lines apply-prompt-lines
   :update-info-window update-info-window
   :prompt-hooks-mod prompt_hooks_mod
   :default-prompt-keymaps M.prompt-keymaps
   :default-main-keymaps M.main-keymaps
   :on-prompt-changed (fn [prompt-buf force event-tick]
                        (M.on-prompt-changed prompt-buf force event-tick))
   :maybe-sync-from-main! (fn [session force-refresh]
                            (router_navigation_mod.maybe-sync-from-main!
                              navigation-deps
                              session
                              force-refresh))
   :schedule-scroll-sync! (fn [session]
                            (router_navigation_mod.schedule-scroll-sync!
                              navigation-deps
                              session))
   :maybe-restore-hidden-ui! (fn [session force]
                               (router_actions_mod.maybe-restore-ui!
                                 actions-deps
                                 session.prompt-buf
                                 (if (= force nil) false force)))})

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
  (router_navigation_mod.move-selection! navigation-deps prompt-buf delta))

(fn M.scroll-main
  [prompt-buf action]
  "Public API: M.scroll-main."
  (router_navigation_mod.scroll-main! navigation-deps prompt-buf action))

(fn maybe-sync-from-main!
  [session force-refresh]
  (router_navigation_mod.maybe-sync-from-main! navigation-deps session force-refresh))

(fn schedule-scroll-sync!
  [session]
  (router_navigation_mod.schedule-scroll-sync! navigation-deps session))

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

(fn M.enter-edit-mode
  [prompt-buf]
  "Hide prompt/info and switch to editable results buffer."
  (router_actions_mod.enter-edit-mode! actions-deps prompt-buf))

(fn M.write-results
  [prompt-buf]
  "Propagate edited results lines back to their source files."
  (router_actions_mod.write-results! actions-deps prompt-buf))

(fn M.maybe-restore-hidden-ui
  [prompt-buf]
  "Restore hidden prompt/info UI when revisiting a preserved results buffer."
  (router_actions_mod.maybe-restore-ui! actions-deps prompt-buf false))

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

(fn M.start
  [query mode _meta project-mode]
  "Create a Meta session and wire prompt/result/project orchestration."
  (router_session_mod.start! session-deps query mode _meta project-mode))

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
