(local hooks-window-layout-mod (require :metabuffer.prompt.hooks_window_layout))
(local hooks-window-overlay-mod (require :metabuffer.prompt.hooks_window_overlay))
(local M {})

(fn M.new
  [session-prompt-valid?]
  (let [overlay-hooks (hooks-window-overlay-mod.new)
        layout-hooks (hooks-window-layout-mod.new session-prompt-valid?)]
    {:covered-by-new-window? (. overlay-hooks :covered-by-new-window?)
     :transient-overlay-buffer? (. overlay-hooks :transient-overlay-buffer?)
     :first-window-for-buffer (. overlay-hooks :first-window-for-buffer)
     :capture-expected-layout! (. layout-hooks :capture-expected-layout!)
     :note-editor-size! (. layout-hooks :note-editor-size!)
     :note-global-editor-resize! (. layout-hooks :note-global-editor-resize!)
     :manual-prompt-resize? (. layout-hooks :manual-prompt-resize?)
     :schedule-restore-expected-layout! (. layout-hooks :schedule-restore-expected-layout!)
     :hidden-session-reachable? (. overlay-hooks :hidden-session-reachable?)}))

M
