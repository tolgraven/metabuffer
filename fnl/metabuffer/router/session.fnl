(import-macros {: if-some : when-not} :io.gitlab.andreyorst.cljlib.core)

(local M {})

(fn register-prompt-hooks!
  [deps session]
  (let [prompt-hooks-mod (. deps :prompt-hooks-mod)
        router-util-mod (. deps :router-util-mod)
        default-prompt-keymaps (. deps :default-prompt-keymaps)
        default-main-keymaps (. deps :default-main-keymaps)
        active-by-prompt (. deps :active-by-prompt)
        on-prompt-changed (. deps :on-prompt-changed)
        update-info-window (. deps :update-info-window)
        maybe-sync-from-main! (. deps :maybe-sync-from-main!)
        schedule-scroll-sync! (. deps :schedule-scroll-sync!)
        maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)
        preview-window (. deps :preview-window)
        context-window (. deps :context-window)
        sign-mod (. deps :sign-mod)
        router-api (. deps :router-api)
        hooks
        (prompt-hooks-mod.new
          {:mark-prompt-buffer! router-util-mod.mark-prompt-buffer!
           :default-prompt-keymaps default-prompt-keymaps
           :default-main-keymaps default-main-keymaps
           :active-by-prompt active-by-prompt
           :on-prompt-changed on-prompt-changed
           :update-info-window update-info-window
           :maybe-sync-from-main! maybe-sync-from-main!
           :schedule-scroll-sync! schedule-scroll-sync!
           :maybe-restore-hidden-ui! maybe-restore-hidden-ui!
          :maybe-refresh-preview-statusline! (fn [s]
                                              (when (and preview-window
                                                         preview-window.refresh-statusline!)
                                                 (preview-window.refresh-statusline! s)))
           :update-context-window! (fn [s]
                                     (when (and context-window context-window.update!)
                                       (context-window.update! s)))
           :sign-mod sign-mod})]
    (hooks.register! router-api session)))

(fn activate-session-ui!
  [deps session initial-lines]
  (let [router-util-mod (. deps :router-util-mod)
        active-by-source (. deps :active-by-source)
        active-by-prompt (. deps :active-by-prompt)
        sync-prompt-buffer-name! (. deps :sync-prompt-buffer-name!)
        prompt-buf session.prompt-buf
        prompt-win session.prompt-win]
    (sync-prompt-buffer-name! session)
    (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
    (router-util-mod.mark-prompt-buffer! prompt-buf)
    (register-prompt-hooks! deps session)
    (set (. active-by-source session.source-buf) session)
    (set (. active-by-prompt prompt-buf) session)
    (vim.api.nvim_set_current_win prompt-win)
    (let [row (math.max 1 (# initial-lines))
          line (or (. initial-lines row) "")
          col (# line)]
      (pcall vim.api.nvim_win_set_cursor prompt-win [row col]))
    (vim.cmd "startinsert")))

(fn finish-session-startup!
  [deps curr session initial-query-active]
  (let [project-source (. deps :project-source)
        meta-window-mod (. deps :meta-window-mod)
        sign-mod (. deps :sign-mod)
        session-view (. deps :session-view)
        apply-prompt-lines (. deps :apply-prompt-lines)
        update-info-window (. deps :update-info-window)
        context-window (. deps :context-window)
        instances (. deps :instances)]
    (if session.project-mode
        (project-source.apply-minimal-source-set! session)
        (project-source.apply-source-set! session))
    (set curr.status-win (meta-window-mod.new vim session.prompt-win))
    (curr.win.set-statusline "")
    (curr.on-init)
    (when sign-mod
      (pcall sign-mod.capture-baseline! session))
    (when session.project-mode
      (session-view.restore-meta-view! curr session.source-view))
    (when-not (and session.project-mode (not initial-query-active))
      (apply-prompt-lines session))
    (vim.schedule
      (fn []
        (set session.startup-initializing false)
        (when (and session.project-mode (not session.project-bootstrapped))
          (project-source.schedule-project-bootstrap! session 0))))
    (when (and session.project-mode (not initial-query-active))
      (vim.schedule
        (fn []
          (when (= (. (. deps :active-by-prompt) session.prompt-buf) session)
            (pcall curr.refresh_statusline)
            (pcall update-info-window session)
            (when (and context-window context-window.update!)
              (pcall context-window.update! session))))))
    (when (and context-window context-window.update!)
      (vim.schedule (fn [] (pcall context-window.update! session))))
    (set (. instances session.instance-id) session)))

(fn M.start!
  [deps query mode _meta project-mode]
  (let [history-api (. deps :history-api)
        query-mod (. deps :query-mod)
        remove-session! (. deps :remove-session!)
        active-by-source (. deps :active-by-source)
        session-view (. deps :session-view)
        meta-mod (. deps :meta-mod)
        base-buffer (. deps :base-buffer)
        router-util-mod (. deps :router-util-mod)
        prompt-window-mod (. deps :prompt-window-mod)
        history-store (. deps :history-store)
        read-file-lines-cached (. deps :read-file-lines-cached)
        settings (. deps :settings)
        next-instance-id! (. deps :next-instance-id!)
        maybe-restore-hidden-ui! (. deps :maybe-restore-hidden-ui!)]
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
          parsed-query (query-mod.parse-query-text expanded-query)
          query0 (. parsed-query :query)
          prompt-query (if (~= (. parsed-query :include-files) nil)
                           expanded-query
                           query0)
          prompt-query (if (and (= (type prompt-query) "string")
                                (~= prompt-query "")
                                (not (vim.endswith prompt-query " "))
                                (not (vim.endswith prompt-query "\n")))
                           (.. prompt-query " ")
                           prompt-query)
          start-hidden (if-some [v (. parsed-query :include-hidden)]
                               v
                               (query-mod.truthy? settings.default-include-hidden))
          start-ignored (if-some [v (. parsed-query :include-ignored)]
                                v
                                (query-mod.truthy? settings.default-include-ignored))
          start-deps (if-some [v (. parsed-query :include-deps)]
                             v
                             (query-mod.truthy? settings.default-include-deps))
          start-binary (if-some [v (. parsed-query :include-binary)]
                               v
                               (query-mod.truthy? settings.default-include-binary))
          start-hex (if-some [v (. parsed-query :include-hex)]
                           v
                           (query-mod.truthy? settings.default-include-hex))
          start-files (if-some [v (. parsed-query :include-files)]
                              v
                              (query-mod.truthy? settings.default-include-files))
          start-prefilter (if-some [v (. parsed-query :prefilter)]
                                  v
                                  (query-mod.truthy? settings.project-lazy-prefilter-enabled))
          start-lazy (if-some [v (. parsed-query :lazy)]
                             v
                             (query-mod.truthy? settings.project-lazy-enabled))
          start-expansion (or (. parsed-query :expansion) "none")
          query query0]
      (let [source-buf (vim.api.nvim_get_current_buf)
            existing (. active-by-source source-buf)]
        (if (and existing
                 existing.ui-hidden
                 maybe-restore-hidden-ui!
                 existing.meta
                 existing.meta.buf
                 (= source-buf existing.meta.buf.buffer))
            (do
              (maybe-restore-hidden-ui! existing true)
              existing.meta)
            (do
              (when (and existing (not existing.ui-hidden))
                (remove-session! existing))
              (let [origin-win (vim.api.nvim_get_current_win)
                    origin-buf source-buf
                    source-view (vim.fn.winsaveview)
                    _ (set (. source-view :_meta_win_height) (vim.api.nvim_win_get_height origin-win))
                    condition (session-view.setup-state query mode source-view)
                    curr (meta-mod.new vim condition)]
                (set curr.project-mode (or project-mode false))
                (base-buffer.switch-buf curr.buf.buffer)
                (router-util-mod.ensure-source-refs! curr)
                (set curr.buf.keep-modifiable true)
                (let [bo (. vim.bo curr.buf.buffer)]
                  (set (. bo :buftype) "acwrite")
                  (set (. bo :modifiable) true)
                  (set (. bo :readonly) false)
                  (set (. bo :bufhidden) "hide"))
                (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_manual_edit_active" false)
                (pcall vim.api.nvim_buf_set_var curr.buf.buffer "meta_internal_render" false)
                (let [initial-lines (if (and prompt-query (~= prompt-query ""))
                                        (vim.split prompt-query "\n" {:plain true})
                                        [""])
                      prompt-win (prompt-window-mod.new
                                   vim
                                   {:height (router-util-mod.prompt-height)
                                    :window-local-layout settings.window-local-layout
                                    :origin-win origin-win})
                      prompt-buf prompt-win.buffer
                      session {:source-buf source-buf
                               :origin-win origin-win
                               :origin-buf origin-buf
                               :source-view source-view
                               :initial-source-line (math.max 1 (or (. source-view :lnum) (+ (or condition.selected-index 0) 1)))
                               :prompt-win prompt-win.window
                               :prompt-buf prompt-buf
                               :window-local-layout settings.window-local-layout
                               :prompt-keymaps settings.prompt-keymaps
                               :main-keymaps settings.main-keymaps
                               :prompt-fallback-keymaps settings.prompt-fallback-keymaps
                               :info-file-entry-view (or settings.info-file-entry-view "meta")
                               :initial-prompt-text (table.concat initial-lines "\n")
                               :last-prompt-text (table.concat initial-lines "\n")
                               :last-history-text ""
                               :history-index 0
                               :history-cache (vim.deepcopy (history-store.list))
                               :prompt-update-pending false
                               :prompt-update-dirty false
                               :prompt-change-seq 0
                               :prompt-last-apply-ms 0
                               :prompt-last-event-text (table.concat initial-lines "\n")
                               :initial-query-active (query-mod.query-lines-has-active? (. parsed-query :lines))
                               :startup-initializing true
                               :project-mode (or project-mode false)
                               :read-file-lines-cached read-file-lines-cached
                               :include-hidden start-hidden
                               :include-ignored start-ignored
                               :include-deps start-deps
                               :include-binary start-binary
                               :include-hex start-hex
                               :include-files start-files
                               :effective-include-hidden start-hidden
                               :effective-include-ignored start-ignored
                               :effective-include-deps start-deps
                               :effective-include-binary start-binary
                               :effective-include-hex start-hex
                               :effective-include-files start-files
                               :project-bootstrap-pending false
                               :project-bootstrap-token 0
                               :project-bootstrap-delay-ms (if (query-mod.query-lines-has-active? (. parsed-query :lines))
                                                               settings.project-bootstrap-delay-ms
                                                               settings.project-bootstrap-idle-delay-ms)
                               :project-bootstrapped (not (or project-mode false))
                               :prefilter-mode start-prefilter
                               :lazy-mode start-lazy
                               :expansion-mode start-expansion
                               :last-parsed-query {:lines (if (and query (~= query ""))
                                                              (vim.split query "\n" {:plain true})
                                                              [""])
                                                   :include-hidden start-hidden
                                                   :include-ignored start-ignored
                                                   :include-deps start-deps
                                                   :include-binary start-binary
                                                   :include-hex start-hex
                                                   :include-files start-files
                                                   :file-lines (or (. parsed-query :file-lines) [])
                                                   :prefilter start-prefilter
                                                   :lazy start-lazy
                                                   :expansion start-expansion}
                               :file-query-lines (or (. parsed-query :file-lines) [])
                               :single-content (vim.deepcopy curr.buf.content)
                               :single-refs (vim.deepcopy (or curr.buf.source-refs []))
                               :instance-id (next-instance-id!)
                               :meta curr}]
                  (let [initial-query-active session.initial-query-active]
                    (set curr.session session)
                    (activate-session-ui! deps session initial-lines)
                    (finish-session-startup!
                      deps
                      curr
                      session
                      initial-query-active)
                    curr)))))))))

M
