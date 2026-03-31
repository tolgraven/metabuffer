(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local events (require :metabuffer.events))

(fn M.new
  [opts]
  "Build prompt-hook layout and resize callbacks."
  (let [session-prompt-valid? (. opts :session-prompt-valid?)
        capture-expected-layout! (. opts :capture-expected-layout!)
        note-editor-size! (. opts :note-editor-size!)
        note-global-editor-resize! (. opts :note-global-editor-resize!)
        manual-prompt-resize? (. opts :manual-prompt-resize?)
        schedule-restore-expected-layout! (. opts :schedule-restore-expected-layout!)
        refresh-prompt-highlights! (. opts :refresh-prompt-highlights!)
        rebuild-source-set! (. opts :rebuild-source-set!)]
    (fn emit-query-refresh!
      [session]
      (events.send :on-query-update!
        {:session session
         :query (or session.prompt-last-applied-text "")
         :refresh-lines true}))

    (fn handle-global-resize!
      [session ev]
      (when-not session.handling-layout-change?
        (let [is-vim-resized? (= ev.event "VimResized")
              wins (or (?. vim.v :event :windows) [])
              manual-prompt-resize (and (not is-vim-resized?)
                                        (manual-prompt-resize? session wins))]
          (when is-vim-resized?
            (set session.preview-user-resized? false))
          (let [editor-size-changed? (or (~= (or session.last-editor-columns vim.o.columns) vim.o.columns)
                                         (~= (or session.last-editor-lines vim.o.lines) vim.o.lines))]
            (note-editor-size! session)
            (when (or is-vim-resized? editor-size-changed?)
              (note-global-editor-resize! session))
            (when (and (not is-vim-resized?)
                       (not editor-size-changed?)
                       (not session.preview-global-resize-token)
                       session.preview-win
                       (vim.api.nvim_win_is_valid session.preview-win))
              (each [_ wid (ipairs wins)]
                (when (= wid session.preview-win)
                  (set session.preview-user-resized? true)))))
          (if manual-prompt-resize
              (do
                (set session.prompt-target-height (vim.api.nvim_win_get_height session.prompt-win))
                (capture-expected-layout! session))
              (schedule-restore-expected-layout! session))
          (set session.handling-layout-change? true)
          (vim.schedule
            (fn []
              (when (session-prompt-valid? session)
                (let [results-wrap? (and session.meta
                                         session.meta.win
                                         (vim.api.nvim_win_is_valid session.meta.win.window)
                                         (vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window}))]
                  (when (and results-wrap?
                             rebuild-source-set!
                             (not session.project-mode))
                    (pcall rebuild-source-set! session)
                    (pcall session.meta.on-update 0)))
                (when-not session.prompt-animating?
                  (pcall refresh-prompt-highlights! session)
                  (emit-query-refresh! session))
                (when (= ev.event "VimResized")
                  (capture-expected-layout! session)))
              (set session.handling-layout-change? false))))))

    (fn handle-wrap-option-set!
      [session]
      (when-not session.handling-layout-change?
        (set session.handling-layout-change? true)
        (vim.schedule
          (fn []
            (when (session-prompt-valid? session)
              (when (and session.meta
                         session.meta.win
                         (vim.api.nvim_win_is_valid session.meta.win.window)
                         (= (vim.api.nvim_get_current_win) session.meta.win.window))
                (let [wrap? (not (not (vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window})))]
                  (pcall vim.api.nvim_set_option_value "linebreak" wrap? {:win session.meta.win.window})
                  (when (and rebuild-source-set!
                             (not session.project-mode))
                    (pcall rebuild-source-set! session)
                    (pcall session.meta.on-update 0)
                    (emit-query-refresh! session)))))
            (set session.handling-layout-change? false)))))

    {:handle-global-resize! handle-global-resize!
     :handle-wrap-option-set! handle-wrap-option-set!}))

M
