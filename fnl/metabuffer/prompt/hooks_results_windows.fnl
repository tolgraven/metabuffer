(local M {})

(fn M.new
  [opts]
  "Build prompt-hook helpers for result-window overlay and teardown callbacks."
  (let [covered-by-new-window? (. opts :covered-by-new-window?)
        transient-overlay-buffer? (. opts :transient-overlay-buffer?)
        first-window-for-buffer (. opts :first-window-for-buffer)
        hidden-session-reachable? (. opts :hidden-session-reachable?)
        maybe-restore-hidden-ui! (. opts :maybe-restore-hidden-ui!)
        hide-visible-ui! (. opts :hide-visible-ui!)
        rebuild-source-set! (. opts :rebuild-source-set!)]
    (fn handle-results-focus!
      [session session-active?]
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
      [session session-active?]
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
      [session ev session-active?]
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

    (fn handle-hidden-session-gc!
      [router session session-active?]
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
                     (vim.api.nvim_buf_is_valid session.prompt-buf))
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
      [router session ev session-active? emit-query-refresh!]
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

    {:handle-external-write! handle-external-write!
     :handle-hidden-session-gc! handle-hidden-session-gc!
     :handle-overlay-bufwinenter! handle-overlay-bufwinenter!
     :handle-overlay-winnew! handle-overlay-winnew!
     :handle-results-focus! handle-results-focus!
     :handle-results-leave! handle-results-leave!}))

M
