(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})
(local animation-mod (require :metabuffer.window.animation))
(local prompt-view-mod (require :metabuffer.buffer.prompt_view))
(local events (require :metabuffer.events))
(local hooks-directive-mod (require :metabuffer.prompt.hooks_directive))
(local hooks-keymaps-mod (require :metabuffer.prompt.hooks_keymaps))
(local hooks-layout-mod (require :metabuffer.prompt.hooks_layout))
(local hooks-results-mod (require :metabuffer.prompt.hooks_results))
(local loading-state-mod (require :metabuffer.widgets.loading_state))
(local hooks-window-mod (require :metabuffer.prompt.hooks_window))

(fn M.new
  [opts]
  "Public API: M.new."
    (let [{: default-prompt-keymaps : active-by-prompt
         : default-main-keymaps
         : on-prompt-changed
         : maybe-sync-from-main!
         : schedule-scroll-sync! : maybe-restore-hidden-ui!
         : hide-visible-ui!
         : rebuild-source-set!
         : sign-mod} opts]
    (let [animation-enabled? (. animation-mod :enabled?)
          animation-duration-ms (. animation-mod :duration-ms)]
    (fn prompt-animation-delay-ms
      [session]
      (if (and animation-mod
               animation-enabled?
               (animation-enabled? session :prompt))
          (animation-duration-ms session :prompt 140)
          0))

    (fn switch-mode
  [session which]
      (let [meta session.meta]
        (fn mode-label
          [value]
          (if (= (type value) "table")
              (or (. value :name) (tostring value))
              (tostring value)))
        (let [old (mode-label ((. (. meta.mode which) :current)))]
        (meta.switch_mode which)
        (events.post :on-mode-switch!
          {:session session
           :kind which
           :old old
           :new (mode-label ((. (. meta.mode which) :current)))}
          {:supersede? true
           :dedupe-key (.. "on-mode-switch:" (tostring session.prompt-buf) ":" which)}))))

    (fn nvim-exiting?
      []
      (let [v (and vim.v (. vim.v :exiting))]
        (and (~= v nil)
             (~= v vim.NIL)
             (~= v 0)
             (~= v ""))))

    (fn session-prompt-valid?
  [session]
      (and (not (nvim-exiting?))
           session
           (not session.ui-hidden)
           (not session.closing)
           session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)
           (= (. active-by-prompt session.prompt-buf) session)))

    (fn schedule-when-valid
  [session f]
      (vim.schedule
        (fn []
          (when (session-prompt-valid? session)
            (f)))))

	    (fn option-prefix
	      []
	      (let [p (. vim.g "meta#prefix")]
	        (if (and (= (type p) "string") (~= p ""))
	            p
	            "#")))
        (let [window-hooks (hooks-window-mod.new session-prompt-valid?)
              covered-by-new-window? (. window-hooks :covered-by-new-window?)
              transient-overlay-buffer? (. window-hooks :transient-overlay-buffer?)
              first-window-for-buffer (. window-hooks :first-window-for-buffer)
              capture-expected-layout! (. window-hooks :capture-expected-layout!)
              note-editor-size! (. window-hooks :note-editor-size!)
              note-global-editor-resize! (. window-hooks :note-global-editor-resize!)
              manual-prompt-resize? (. window-hooks :manual-prompt-resize?)
              schedule-restore-expected-layout! (. window-hooks :schedule-restore-expected-layout!)
              hidden-session-reachable? (. window-hooks :hidden-session-reachable?)]

    (var refresh-prompt-highlights! nil)
    (var schedule-loading-indicator! nil)
    (let [prompt-view (prompt-view-mod.new
                        {:option-prefix option-prefix
                         :session-prompt-valid? session-prompt-valid?
                         :schedule-loading-indicator! (fn [session]
                                                        (when schedule-loading-indicator!
                                                          (schedule-loading-indicator! session)))})
          directive-hooks (hooks-directive-mod.new
                            {:option-prefix option-prefix
                             :highlight-prompt-like-line! (. prompt-view :highlight-like-line!)})
          keymap-hooks (hooks-keymaps-mod.new
                         {:default-prompt-keymaps default-prompt-keymaps
                          :default-main-keymaps default-main-keymaps
                          :schedule-when-valid schedule-when-valid
                          :switch-mode switch-mode
                          :sign-mod sign-mod})
          hide-directive-help! (. directive-hooks :hide-directive-help!)
          maybe-show-directive-help! (. directive-hooks :maybe-show-directive-help!)
          maybe-trigger-directive-complete! (. directive-hooks :maybe-trigger-directive-complete!)
          apply-keymaps (. keymap-hooks :apply-keymaps)
          apply-emacs-insert-fallbacks (. keymap-hooks :apply-emacs-insert-fallbacks)
          apply-main-keymaps (. keymap-hooks :apply-main-keymaps)
          apply-results-edit-keymaps (. keymap-hooks :apply-results-edit-keymaps)
          begin-direct-results-edit! (. keymap-hooks :begin-direct-results-edit!)
          loading-hooks (loading-state-mod.new
                          {:session-prompt-valid? session-prompt-valid?
                           :animation-enabled? animation-enabled?
                           :animation-duration-ms animation-duration-ms
                           :refresh-prompt-highlights! (fn [session]
                                                         (refresh-prompt-highlights! session))})
          loading-scheduler (. loading-hooks :schedule-loading-indicator!)
          layout-hooks (hooks-layout-mod.new
                         {:session-prompt-valid? session-prompt-valid?
                          :capture-expected-layout! capture-expected-layout!
                          :note-editor-size! note-editor-size!
                          :note-global-editor-resize! note-global-editor-resize!
                          :manual-prompt-resize? manual-prompt-resize?
                          :schedule-restore-expected-layout! schedule-restore-expected-layout!
                          :refresh-prompt-highlights! (fn [session]
                                                        (refresh-prompt-highlights! session))
                          :rebuild-source-set! rebuild-source-set!})
          handle-global-resize! (. layout-hooks :handle-global-resize!)
          handle-wrap-option-set! (. layout-hooks :handle-wrap-option-set!)
          results-hooks (hooks-results-mod.new
                          {:active-by-prompt active-by-prompt
                           :sign-mod sign-mod
                           :maybe-sync-from-main! maybe-sync-from-main!
                           :schedule-scroll-sync! schedule-scroll-sync!
                           :maybe-restore-hidden-ui! maybe-restore-hidden-ui!
                           :hide-visible-ui! hide-visible-ui!
                           :rebuild-source-set! rebuild-source-set!
                           :covered-by-new-window? covered-by-new-window?
                           :transient-overlay-buffer? transient-overlay-buffer?
                           :first-window-for-buffer first-window-for-buffer
                           :hidden-session-reachable? hidden-session-reachable?
                           :begin-direct-results-edit! begin-direct-results-edit!})
          handle-results-cursor! (. results-hooks :handle-results-cursor!)
          handle-results-edit-enter! (. results-hooks :handle-results-edit-enter!)
          handle-results-text-changed! (. results-hooks :handle-results-text-changed!)
          handle-results-focus! (. results-hooks :handle-results-focus!)
          handle-overlay-winnew! (. results-hooks :handle-overlay-winnew!)
          handle-overlay-bufwinenter! (. results-hooks :handle-overlay-bufwinenter!)
          handle-selection-focus! (. results-hooks :handle-selection-focus!)
          handle-hidden-session-gc! (. results-hooks :handle-hidden-session-gc!)
          handle-results-leave! (. results-hooks :handle-results-leave!)
          handle-external-write! (. results-hooks :handle-external-write!)
          handle-scroll-sync! (. results-hooks :handle-scroll-sync!)
          handle-results-writecmd! (. results-hooks :handle-results-writecmd!)
          handle-results-wipeout! (. results-hooks :handle-results-wipeout!)]
      (set refresh-prompt-highlights! (. prompt-view :refresh-highlights!))
      (set schedule-loading-indicator! loading-scheduler)

    (fn maybe-expand-history-shorthand!
  [router session]
      (if session._expanding-history-shorthand
          false
          (if (and session
                   session.prompt-buf
                   session.prompt-win
                   (vim.api.nvim_buf_is_valid session.prompt-buf)
                   (vim.api.nvim_win_is_valid session.prompt-win))
              (let [[row col] (vim.api.nvim_win_get_cursor session.prompt-win)
                    row0 (math.max 0 (- row 1))
                    line (or (. (vim.api.nvim_buf_get_lines session.prompt-buf row0 (+ row0 1) false) 1) "")
                    left (if (> col 0) (string.sub line 1 col) "")
                    saved-tag (string.match left "##([%w_%-]+)$")
                    saved-replacement (if saved-tag
                                          (router.saved-prompt-entry saved-tag)
                                          "")
                    trigger (if (and (>= col 3) (vim.endswith left "!^!"))
                                "!^!"
                                (and (>= col 2) (vim.endswith left "!!"))
                                "!!"
                                (and (>= col 2) (vim.endswith left "!$"))
                                "!$"
                                nil)
                    replacement (if (= trigger "!!")
                                    (router.last-prompt-entry session.prompt-buf)
                                    (= trigger "!$")
                                    (router.last-prompt-token session.prompt-buf)
                                    (= trigger "!^!")
                                    (router.last-prompt-tail session.prompt-buf)
                                    "")]
                (if (and trigger (= (type replacement) "string") (~= replacement ""))
                    (do
                      (set session._expanding-history-shorthand true)
                      (let [start-col (- col (if (= trigger "!^!") 3 2))]
                        (vim.api.nvim_buf_set_text session.prompt-buf row0 start-col row0 col [""])
                        (pcall vim.api.nvim_win_set_cursor session.prompt-win [row start-col]))
                      (if (= trigger "!!")
                          (router.insert-last-prompt session.prompt-buf)
                          (= trigger "!$")
                          (router.insert-last-token session.prompt-buf)
                          (router.insert-last-tail session.prompt-buf))
                      (set session._expanding-history-shorthand false)
                      true)
                    (if (and saved-tag
                             (= (type saved-replacement) "string")
                             (~= saved-replacement ""))
                        (do
                          (set session._expanding-history-shorthand true)
                          (let [tag-len (+ 2 (# saved-tag))
                                start-col (- col tag-len)]
                            (vim.api.nvim_buf_set_text session.prompt-buf row0 start-col row0 col [""])
                            (pcall vim.api.nvim_win_set_cursor session.prompt-win [row start-col]))
                          (router.prompt-insert-text session.prompt-buf saved-replacement)
                          (set session._expanding-history-shorthand false)
                          true)
                        false)))
              false)))

    (fn register!
  [router session]
      (let [aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true})]
        (set session.augroup aug)

        (capture-expected-layout! session)

    (fn au!
      [events buf body]
      "Create buffer-local autocmd with schedule-when-valid session guard.
       `body` is a zero-arg function called inside the scheduled guard."
      (vim.api.nvim_create_autocmd events
        {:group aug
         :buffer buf
         :callback (fn [_]
                     (schedule-when-valid session body))}))
    (fn au-buf!
      [events buf callback]
      "Create buffer-local autocmd with a raw event callback."
      (vim.api.nvim_create_autocmd events {:group aug :buffer buf :callback callback}))
    (fn au-global!
      [events callback ?opts]
      "Create global autocmd with a raw callback and optional opts override."
      (let [base {:group aug :callback callback}]
        (each [k v (pairs (or ?opts {}))]
          (tset base k v))
        (vim.api.nvim_create_autocmd events base)))
      ;; Some environments/plugins do not reliably emit TextChangedI for this
      ;; scratch prompt buffer; keep a low-level line-change hook as a fallback.
        (vim.api.nvim_buf_attach session.prompt-buf false
          {:on_lines (fn [_ _ changedtick _ _ _ _ _]
                       ;; on_lines can fire before insert-state buffer text is fully
                       ;; visible; defer one tick so we observe the committed prompt.
                       (vim.schedule
                         (fn []
                           (when (and session.prompt-buf
                                      (= (. active-by-prompt session.prompt-buf) session))
                             (if (maybe-expand-history-shorthand! router session)
                                 nil
                                 (do
                                   (refresh-prompt-highlights! session)
                                   (on-prompt-changed session.prompt-buf false changedtick)))))))
           :on_detach (fn []
                        (when session.prompt-buf
                          (set (. active-by-prompt session.prompt-buf) nil)))})
      ;; Prompt text updates: rely on post-change autocmds to avoid pre-edit race
      ;; behavior that can leave matcher one character behind while typing.
        (au-buf! ["TextChanged" "TextChangedI"] session.prompt-buf
          (fn [_]
            (if (maybe-expand-history-shorthand! router session)
                nil
                (do
                  (refresh-prompt-highlights! session)
                  (maybe-show-directive-help! session)
                  (maybe-trigger-directive-complete! session)
                  (on-prompt-changed
                    session.prompt-buf
                    false
                    (vim.api.nvim_buf_get_changedtick session.prompt-buf))))))
        (au! "CompleteChanged" session.prompt-buf
          (fn [ev]
            (let [item (and ev (= (type ev) "table") (. ev :completed_item))]
              (maybe-show-directive-help! session item))))
        (au! "CompleteDone" session.prompt-buf
          (fn [] (maybe-show-directive-help! session)))
      ;; Re-assert prompt maps when entering insert mode; this wins over late
      ;; plugin mappings (for example completion plugins).
        (au! "InsertEnter" session.prompt-buf
          (fn []
            (events.send :on-insert-enter! {:session session})
            (apply-keymaps router session)
            (apply-emacs-insert-fallbacks router session)))
      ;; Some statusline plugins or focus transitions (for example tmux pane
      ;; switches) can overwrite local statusline state. Re-apply ours when the
      ;; prompt window regains focus.
        (au! ["BufEnter" "WinEnter" "FocusGained"] session.prompt-buf
          (fn []
            (events.post :on-prompt-focus!
                         {:session session}
                         {:supersede? true
                          :dedupe-key (.. "on-prompt-focus:" (tostring session.prompt-buf))})))
      ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
        (au! ["ModeChanged" "InsertEnter" "InsertLeave"] session.prompt-buf
          (fn []
            (events.post :on-prompt-focus!
                         {:session session}
                         {:supersede? true
                          :dedupe-key (.. "on-prompt-focus:" (tostring session.prompt-buf))})
            (maybe-show-directive-help! session)))
        (au! ["CursorMoved" "CursorMovedI"] session.prompt-buf
          (fn [] (maybe-show-directive-help! session)))
      (au! ["BufLeave" "WinLeave"] session.prompt-buf
        (fn [] (hide-directive-help! session)))
      ;; Recompute floating info rendering/width when editor windows resize.
      ;; Guard: both VimResized/WinResized and OptionSet "wrap" can trigger
      ;; on-update which re-renders and may cause further resize/option events.
      ;; The reentrancy flag is set synchronously in the autocmd callback
      ;; (before vim.schedule) so that additional events queued before the
      ;; scheduled callback runs are suppressed.
      ;; On WinResized, capture v:event.windows synchronously — if the preview
      ;; window is in the list (user dragged a split border), latch
      ;; preview-user-resized? so ensure-preview-width! respects the manual
      ;; width.  VimResized (terminal resize) clears the latch.
        (au-global! ["VimResized" "WinResized"]
          (fn [ev]
            (handle-global-resize! session ev)))
        (au-global! "OptionSet"
          (fn [_]
            (handle-wrap-option-set! session))
          {:pattern "wrap"})
      ;; Keep selection/status/info synced when user scrolls or moves in the
      ;; main meta window with regular motions/mouse while prompt is open.
        (au! ["CursorMoved" "CursorMovedI"] session.meta.buf.buffer
          (fn [] (handle-results-cursor! session)))
        (au-buf! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn [_]
            (handle-results-edit-enter! session)))
        (au-buf! ["TextChanged" "TextChangedI"] session.meta.buf.buffer
          (fn [_]
            (handle-results-text-changed! router session)))
        (au-buf! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn [_]
            (handle-results-focus! session)))
        (au-global! "WinNew"
          (fn [_]
            (handle-overlay-winnew! session)))
        (au-global! "BufWinEnter"
          (fn [ev]
            (handle-overlay-bufwinenter! session ev)))
        (au! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn []
            (handle-selection-focus! session)))
        (au-global! ["BufEnter" "WinEnter" "FocusGained"]
          (fn [_]
            (handle-hidden-session-gc! router session)))
        (au-buf! "BufLeave" session.meta.buf.buffer
          (fn [_]
            (handle-results-leave! router session)))
        (apply-main-keymaps router session)
        (apply-results-edit-keymaps session)
      ;; External file writes: invalidate cached file data and rebuild sources
      ;; so the info sidebar reflects the latest on-disk state.
        (au-global! "BufWritePost"
          (fn [ev]
            (handle-external-write! router session ev)))
        (au-global! "WinScrolled"
          (fn [_]
            (handle-scroll-sync! session)))
        (au-buf! "BufWriteCmd" session.meta.buf.buffer
          (fn [_]
            (handle-results-writecmd! router session)))
        (au-buf! "BufWipeout" session.meta.buf.buffer
          (fn [_]
            (handle-results-wipeout! router session)))
        (refresh-prompt-highlights! session)
        (maybe-show-directive-help! session)
        ;; Prompt/footer layout can change one tick later after split/floating
        ;; windows settle; rerender so wrapped footer lines are visible at open.
        (vim.defer_fn
          (fn []
            (when (and session.prompt-buf
                       (= (. active-by-prompt session.prompt-buf) session))
              (pcall refresh-prompt-highlights! session)
              (capture-expected-layout! session)))
          (prompt-animation-delay-ms session))
        (apply-keymaps router session)
        (apply-emacs-insert-fallbacks router session)))

	    {:register! register!
	     :refresh! refresh-prompt-highlights!
	     :loading! schedule-loading-indicator!})))))

M
