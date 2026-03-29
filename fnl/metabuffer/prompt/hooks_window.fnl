(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local window-util (require :metabuffer.window.util))
(local M {})

(fn transient-overlay-buffer?
  [buf]
  (when (and buf (= (type buf) "number") (vim.api.nvim_buf_is_valid buf))
    (let [bo (. vim.bo buf)
          ft (or (. bo :filetype) "")
          bt (or (. bo :buftype) "")]
      (or (= ft "help")
          (= ft "man")
          (= bt "help")))))


(fn M.new
  [session-prompt-valid?]
  (let [window-rect (. window-util :window-rect)
        rect-overlap? (. window-util :rect-overlap?)
        first-window-for-buffer (. window-util :first-window-for-buffer)
        tab-window-count (. window-util :tab-window-count)]
  (fn meta-owned-window?
    [session win]
    (let [meta-win (and session.meta session.meta.win session.meta.win.window)
          prompt-win session.prompt-win
          info-win session.info-win
          preview-win session.preview-win
          history-win session.history-browser-win]
      (or (= win meta-win)
          (= win prompt-win)
          (= win info-win)
          (= win preview-win)
          (= win history-win))))

  (fn covered-by-new-window?
    [session win]
    (let [target (window-rect win)
          prompt-win session.prompt-win
          info-win session.info-win
          preview-win session.preview-win
          history-win session.history-browser-win]
      (and target
           (not (meta-owned-window? session win))
           (or (rect-overlap? target (window-rect info-win))
               (rect-overlap? target (window-rect preview-win))
               (rect-overlap? target (window-rect history-win))
               (and session.prompt-floating?
                    (rect-overlap? target (window-rect prompt-win)))))))

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

  (fn hidden-session-reachable?
    [session]
    (let [results-buf (and session session.meta session.meta.buf session.meta.buf.buffer)]
      (if (not (and results-buf (vim.api.nvim_buf_is_valid results-buf)))
          false
          (if (= (vim.api.nvim_get_current_buf) results-buf)
              true
              (let [raw (vim.fn.getjumplist)
                    jumps (if (and (= (type raw) "table") (= (type (. raw 1)) "table"))
                              (. raw 1)
                              [])]
                (let [hit0 false]
                  (var hit hit0)
                  (each [_ item (ipairs (or jumps []))]
                    (when (= (or (. item :bufnr) (. item "bufnr")) results-buf)
                      (set hit true)))
                  hit))))))

  {:covered-by-new-window? covered-by-new-window?
   :transient-overlay-buffer? transient-overlay-buffer?
   :first-window-for-buffer first-window-for-buffer
   :capture-expected-layout! capture-expected-layout!
   :note-editor-size! note-editor-size!
   :note-global-editor-resize! note-global-editor-resize!
   :manual-prompt-resize? manual-prompt-resize?
   :schedule-restore-expected-layout! schedule-restore-expected-layout!
   :hidden-session-reachable? hidden-session-reachable?}))

M
