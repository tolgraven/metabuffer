(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local events (require :metabuffer.events))

(fn M.new
  [opts]
  "Build prompt-hook callbacks for results-buffer and external window events."
  (let [active-by-prompt (. opts :active-by-prompt)
        sign-mod (. opts :sign-mod)
        maybe-sync-from-main! (. opts :maybe-sync-from-main!)
        schedule-scroll-sync! (. opts :schedule-scroll-sync!)
        maybe-restore-hidden-ui! (. opts :maybe-restore-hidden-ui!)
        hide-visible-ui! (. opts :hide-visible-ui!)
        rebuild-source-set! (. opts :rebuild-source-set!)
        covered-by-new-window? (. opts :covered-by-new-window?)
        transient-overlay-buffer? (. opts :transient-overlay-buffer?)
        first-window-for-buffer (. opts :first-window-for-buffer)
        hidden-session-reachable? (. opts :hidden-session-reachable?)
        begin-direct-results-edit! (. opts :begin-direct-results-edit!)]
    (fn session-active?
      [session]
      (and session
           session.prompt-buf
           (= (. active-by-prompt session.prompt-buf) session)))

    (fn emit-query-refresh!
      [session ?opts]
      (let [extra (or ?opts {})]
        (events.send :on-query-update!
          {:session session
           :query (or session.prompt-last-applied-text "")
           :refresh-lines (if (= (. extra :refresh-lines) nil) true (. extra :refresh-lines))
           :refresh-signs? (not (not (. extra :refresh-signs?)))})))

    (fn handle-results-cursor!
      [session]
      (maybe-sync-from-main! session))

    (fn handle-results-edit-enter!
      [session]
      (begin-direct-results-edit! session))

    (fn handle-results-text-changed!
      [router session]
      (when (and sign-mod session.meta session.meta.buf)
        (let [buf session.meta.buf.buffer
              internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                          (and ok v))]
          (when-not internal?
            (begin-direct-results-edit! session))
          (vim.schedule
            (fn []
              (when (session-active? session)
                (pcall router.sync-live-edits session.prompt-buf)
                (pcall maybe-sync-from-main! session true)
                (emit-query-refresh! session {:refresh-signs? true})))))))

    (fn handle-results-focus!
      [session]
      (when (and (not session.closing)
                 session.meta
                 session.meta.buf
                 (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
        (session.meta.buf.prepare-visible-edit!))
      (when maybe-restore-hidden-ui!
        (vim.schedule
          (fn []
            (when (and (not session.closing)
                       (session-active? session))
              (pcall maybe-restore-hidden-ui! session))))))

    (fn handle-overlay-winnew!
      [session]
      (vim.defer_fn
        (fn []
          (when (and hide-visible-ui!
                     (not session.ui-hidden)
                     (session-active? session))
            (let [win (vim.api.nvim_get_current_win)]
              (when (covered-by-new-window? session win)
                (pcall hide-visible-ui! session)))))
        20))

    (fn handle-overlay-bufwinenter!
      [session ev]
      (vim.defer_fn
        (fn []
          (when (and hide-visible-ui!
                     (not session.ui-hidden)
                     (session-active? session))
            (let [buf (or ev.buf (vim.api.nvim_get_current_buf))
                  win (or (first-window-for-buffer buf)
                          (vim.api.nvim_get_current_win))]
              (when (or (transient-overlay-buffer? buf)
                        (covered-by-new-window? session win))
                (pcall hide-visible-ui! session)))))
        20))

    (fn handle-selection-focus!
      [session]
      (events.send :on-selection-change!
        {:session session
         :line-nr (+ 1 (or session.meta.selected_index 0))
         :refresh-lines false}))

    (fn handle-hidden-session-gc!
      [router session]
      (vim.schedule
        (fn []
          (when (and session.ui-hidden
                     (session-active? session)
                     (not (hidden-session-reachable? session)))
            (pcall router.remove-session session)))))

    (fn handle-results-leave!
      [router session]
      (vim.schedule
        (fn []
          (when (and (not session.ui-hidden)
                     session.prompt-buf
                     (vim.api.nvim_buf_is_valid session.prompt-buf)
                     (= (. active-by-prompt session.prompt-buf) session))
            (let [win session.meta.win.window]
              (if (not (vim.api.nvim_win_is_valid win))
                  (router.cancel session.prompt-buf)
                  (let [buf (vim.api.nvim_win_get_buf win)]
                    (when (not= buf session.meta.buf.buffer)
                      (if (and session.project-mode hide-visible-ui!)
                          (hide-visible-ui! session.prompt-buf)
                          (router.cancel session.prompt-buf))))))))))

    (fn invalidate-path-caches!
      [router session path]
      (when session.preview-file-cache
        (set (. session.preview-file-cache path) nil))
      (when session.info-file-head-cache
        (set (. session.info-file-head-cache path) nil))
      (when session.info-file-meta-cache
        (set (. session.info-file-meta-cache path) nil))
      (when router.project-file-cache
        (set (. router.project-file-cache path) nil)))

    (fn handle-external-write!
      [router session ev]
      (vim.schedule
        (fn []
          (when (and (session-active? session)
                     (not session.closing))
            (let [buf (or ev.buf (vim.api.nvim_get_current_buf))]
              (when (and (vim.api.nvim_buf_is_valid buf)
                         (not= buf session.meta.buf.buffer))
                (let [raw (vim.api.nvim_buf_get_name buf)
                      path (when (and raw (~= raw ""))
                             (vim.fn.fnamemodify raw ":p"))]
                  (when path
                    (invalidate-path-caches! router session path)
                    (when rebuild-source-set!
                      (pcall rebuild-source-set! session))
                    (emit-query-refresh! session)))))))))

    (fn handle-scroll-sync!
      [session]
      (schedule-scroll-sync! session))

    (fn handle-results-writecmd!
      [router session]
      (router.write-results session.prompt-buf))

    (fn handle-results-wipeout!
      [router session]
      (vim.schedule
        (fn []
          (router.results-buffer-wiped session.meta.buf.buffer))))

    {:handle-results-cursor! handle-results-cursor!
     :handle-results-edit-enter! handle-results-edit-enter!
     :handle-results-text-changed! handle-results-text-changed!
     :handle-results-focus! handle-results-focus!
     :handle-overlay-winnew! handle-overlay-winnew!
     :handle-overlay-bufwinenter! handle-overlay-bufwinenter!
     :handle-selection-focus! handle-selection-focus!
     :handle-hidden-session-gc! handle-hidden-session-gc!
     :handle-results-leave! handle-results-leave!
     :handle-external-write! handle-external-write!
     :handle-scroll-sync! handle-scroll-sync!
     :handle-results-writecmd! handle-results-writecmd!
     :handle-results-wipeout! handle-results-wipeout!}))

M
