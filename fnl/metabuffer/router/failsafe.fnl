(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn clear-table!
  [tbl]
  (each [k _ (pairs (or tbl {}))]
    (set (. tbl k) nil)))

(fn add-session!
  [seen sessions session]
  (when (and session
             (= (type session) "table")
             (not (. seen session)))
    (set (. seen session) true)
    (table.insert sessions session)))

(fn maybe-close-win!
  [win]
  (when (and win (vim.api.nvim_win_is_valid win))
    (pcall vim.api.nvim_win_close win true)))

(fn maybe-delete-buf!
  [base-buffer buf]
  (when (and buf (vim.api.nvim_buf_is_valid buf))
    (base-buffer.clear-modified! buf)
    (pcall vim.api.nvim_buf_delete buf {:force true})))

(fn M.new
  [opts]
  "Build router fail-safe teardown and wrapper helpers."
  (let [router (. opts :router)
        base-buffer (. opts :base-buffer)
        router-actions-mod (. opts :router-actions-mod)
        actions-deps (. opts :actions-deps)
        info-window (. opts :info-window)
        preview-window (. opts :preview-window)
        context-window (. opts :context-window)
        history-api (. opts :history-api)]
    (fn fail-safe-teardown!
      [where err]
      (set router._last-failsafe {:where where :error (tostring err)})
      (when-not router._teardown-in-progress
        (set router._teardown-in-progress true)
        (let [seen {}
              sessions []]
          (each [_ session (pairs (or router.instances {}))]
            (add-session! seen sessions session))
          (each [_ session (pairs (or router.active-by-prompt {}))]
            (add-session! seen sessions session))
          (each [_ session (pairs (or router.active-by-source {}))]
            (add-session! seen sessions session))
          (each [_ session (ipairs sessions)]
            (pcall router-actions-mod.remove-session! actions-deps session)
            (maybe-close-win! session.prompt-win)
            (maybe-delete-buf! base-buffer session.prompt-buf)
            (when (and session.meta session.meta.win)
              (maybe-close-win! session.meta.win.window))
            (when (and session.meta session.meta.buf)
              (maybe-delete-buf! base-buffer session.meta.buf.buffer))
            (when (and (= (type info-window) "table")
                       info-window.close-window!)
              (pcall info-window.close-window! session))
            (when (and (= (type preview-window) "table")
                       preview-window.close-window!)
              (pcall preview-window.close-window! session))
            (when (and (= (type context-window) "table")
                       context-window.close-window!)
              (pcall context-window.close-window! session))
            (when history-api
              (pcall history-api.close-history-browser! session))))
        (clear-table! router.instances)
        (clear-table! router.active-by-prompt)
        (clear-table! router.active-by-source)
        (clear-table! router.launching-by-source)
        (set router._teardown-in-progress false))
      (vim.schedule
        (fn []
          (vim.notify
            (.. "metabuffer: torn down after error in " (tostring where) "\n" (tostring err))
            vim.log.levels.ERROR))))

    (fn wrap-public-api-with-failsafe!
      []
      (when-not router._failsafe-wrapped
        (each [k v (pairs router)]
          (when (and (= (type k) "string")
                     (= (type v) "function")
                     (not (vim.startswith k "_"))
                     (~= k "configure")
                     (~= k "fail-safe-teardown!"))
            (set (. router k)
                 (fn [...]
                   (let [res [(pcall v ...)]
                         ok (. res 1)
                         result (. res 2)]
                     (if ok
                         (unpack res 2)
                         (do
                           (fail-safe-teardown! k result)
                           (error result))))))))
        (set router._failsafe-wrapped true)))

    {:fail-safe-teardown! fail-safe-teardown!
     :wrap-public-api-with-failsafe! wrap-public-api-with-failsafe!}))

M
