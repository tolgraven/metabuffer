(local events (require :metabuffer.events))
(local M {})

(fn M.new
  [opts]
  "Build prompt-hook helpers for result/event-side refresh callbacks."
  (let [active-by-prompt (. opts :active-by-prompt)
        maybe-sync-from-main! (. opts :maybe-sync-from-main!)
        schedule-scroll-sync! (. opts :schedule-scroll-sync!)
        begin-direct-results-edit! (. opts :begin-direct-results-edit!)
        sign-mod (. opts :sign-mod)]
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
          (when (not internal?)
            (begin-direct-results-edit! session))
          (vim.schedule
            (fn []
              (when (session-active? session)
                (pcall router.sync-live-edits session.prompt-buf)
                (pcall maybe-sync-from-main! session true)
                (emit-query-refresh! session {:refresh-signs? true})))))))

    (fn handle-selection-focus!
      [session]
      (events.send :on-selection-change!
        {:session session
         :line-nr (+ 1 (or session.meta.selected_index 0))
         :refresh-lines false}))

    (fn handle-scroll-sync!
      [session]
      (schedule-scroll-sync! session))

    {:emit-query-refresh! emit-query-refresh!
     :handle-results-cursor! handle-results-cursor!
     :handle-results-edit-enter! handle-results-edit-enter!
     :handle-results-text-changed! handle-results-text-changed!
     :handle-scroll-sync! handle-scroll-sync!
     :handle-selection-focus! handle-selection-focus!
     :session-active? session-active?}))

M
