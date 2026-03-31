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
  []
  "Build prompt-hook helpers for overlay window detection."
  (let [window-rect (. window-util :window-rect)
        rect-overlap? (. window-util :rect-overlap?)
        first-window-for-buffer (. window-util :first-window-for-buffer)]
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
     :first-window-for-buffer first-window-for-buffer
     :hidden-session-reachable? hidden-session-reachable?
     :transient-overlay-buffer? transient-overlay-buffer?}))

M
