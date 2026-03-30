(import-macros {: when-let : if-let} :io.gitlab.andreyorst.cljlib.core)
(local window-util (require :metabuffer.window.util))
(local M {})

(fn M.new
  [session-prompt-valid?]
  "Build prompt-hook helpers for expected layout capture and restore."
  (let [tab-window-count (. window-util :tab-window-count)]
    (fn layout-snapshot
      [session]
      "Capture expected main/prompt/preview heights and tab window count."
      (let [main-win (and session.meta session.meta.win session.meta.win.window)
            prompt-win session.prompt-win
            preview-win session.preview-win]
        (when (and main-win
                   prompt-win
                   preview-win
                   (vim.api.nvim_win_is_valid main-win)
                   (vim.api.nvim_win_is_valid prompt-win)
                   (vim.api.nvim_win_is_valid preview-win))
          {:main-height (vim.api.nvim_win_get_height main-win)
           :prompt-height (vim.api.nvim_win_get_height prompt-win)
           :preview-height (vim.api.nvim_win_get_height preview-win)
           :tab-window-count (tab-window-count main-win)})))

    (fn note-editor-size!
      [session]
      (when session
        (set session.last-editor-columns vim.o.columns)
        (set session.last-editor-lines vim.o.lines)))

    (fn note-global-editor-resize!
      [session]
      (when session
        (set session.preview-user-resized? false)
        (set session.preview-global-resize-token (+ 1 (or session.preview-global-resize-token 0)))
        (let [token session.preview-global-resize-token]
          (vim.defer_fn
            (fn []
              (when (and session
                         (= token session.preview-global-resize-token))
                (set session.preview-global-resize-token nil)))
            120))))

    (fn capture-expected-layout!
      [session]
      "Persist expected layout after startup/manual prompt resize."
      (when (and session
                 (not session.closing)
                 (not session.ui-hidden)
                 (not session.prompt-floating?)
                 (not session.prompt-animating?))
        (when-let [snap (layout-snapshot session)]
          (set session.expected-layout snap))))

    (fn expected-layout-mismatch?
      [session]
      "True when current window heights differ from expected snapshot."
      (if-let [expected session.expected-layout]
        (if-let [current (layout-snapshot session)]
          (or (~= (. current :main-height) (. expected :main-height))
              (~= (. current :prompt-height) (. expected :prompt-height))
              (~= (. current :preview-height) (. expected :preview-height)))
          false)
        false))

    (fn manual-prompt-resize?
      [session resized-wins]
      "Detect prompt separator drag: prompt resized, same tab window count."
      (if-let [expected session.expected-layout]
        (let [prompt-win session.prompt-win
              prompt-valid? (and prompt-win (vim.api.nvim_win_is_valid prompt-win))
              tab-count (and session.meta
                             session.meta.win
                             session.meta.win.window
                             (tab-window-count session.meta.win.window))
              prompt-height (and prompt-valid? (vim.api.nvim_win_get_height prompt-win))
              prompt-hit? false]
          (var hit prompt-hit?)
          (each [_ wid (ipairs (or resized-wins []))]
            (when (= wid prompt-win)
              (set hit true)))
          (and prompt-valid?
               hit
               (= tab-count (. expected :tab-window-count))
               (~= prompt-height (. expected :prompt-height))))
        false))

    (fn restore-expected-layout!
      [session]
      "Restore main/prompt/preview heights from expected snapshot."
      (when-let [expected session.expected-layout]
        (let [main-win (and session.meta session.meta.win session.meta.win.window)
              prompt-win session.prompt-win
              preview-win session.preview-win]
          (when (and main-win
                     prompt-win
                     preview-win
                     (vim.api.nvim_win_is_valid main-win)
                     (vim.api.nvim_win_is_valid prompt-win)
                     (vim.api.nvim_win_is_valid preview-win))
            (set session.handling-layout-change? true)
            (pcall vim.api.nvim_win_set_height main-win (math.max 1 (or (. expected :main-height) 1)))
            (pcall vim.api.nvim_win_set_height prompt-win (math.max 1 (or (. expected :prompt-height) 1)))
            (pcall vim.api.nvim_win_set_height preview-win (math.max 1 (or (. expected :preview-height) 1)))
            (set session.handling-layout-change? false)))))

    (fn schedule-restore-expected-layout!
      [session]
      "Defer restore so transient disturbances can settle first."
      (when session.expected-layout
        (set session.layout-restore-token (+ 1 (or session.layout-restore-token 0)))
        (let [token session.layout-restore-token]
          (vim.defer_fn
            (fn []
              (when (and (session-prompt-valid? session)
                         (= token session.layout-restore-token)
                         session.expected-layout)
                (let [main-win (and session.meta session.meta.win session.meta.win.window)
                      current-count (and main-win (tab-window-count main-win))
                      expected-count (. session.expected-layout :tab-window-count)]
                  (when (and (= current-count expected-count)
                             (expected-layout-mismatch? session))
                    (restore-expected-layout! session)))))
            80))))

    {:capture-expected-layout! capture-expected-layout!
     :manual-prompt-resize? manual-prompt-resize?
     :note-editor-size! note-editor-size!
     :note-global-editor-resize! note-global-editor-resize!
     :schedule-restore-expected-layout! schedule-restore-expected-layout!}))

M
