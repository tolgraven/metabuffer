(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local clj (require :io.gitlab.andreyorst.cljlib.core))
(local M {})
(local animation-mod (require :metabuffer.window.animation))
(local prompt-view-mod (require :metabuffer.buffer.prompt_view))
(local events (require :metabuffer.events))
(local hooks-directive-mod (require :metabuffer.prompt.hooks_directive))
(local hooks-keymaps-mod (require :metabuffer.prompt.hooks_keymaps))
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
          loading-scheduler (. loading-hooks :schedule-loading-indicator!)]
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
            (when-not session.handling-layout-change?
              ;; Synchronous: capture resize info before schedule.
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
                    (schedule-restore-expected-layout! session)))
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
                      (events.send :on-query-update!
                        {:session session
                         :query (or session.prompt-last-applied-text "")
                         :refresh-lines true}))
                    (when (= ev.event "VimResized")
                      (capture-expected-layout! session)))
                  (set session.handling-layout-change? false))))))
        (au-global! "OptionSet"
          (fn [_]
            (when-not session.handling-layout-change?
              (set session.handling-layout-change? true)
              (vim.schedule
                (fn []
                  (when (session-prompt-valid? session)
                    (when (and session.meta
                               session.meta.win
                               (vim.api.nvim_win_is_valid session.meta.win.window)
                               (= (vim.api.nvim_get_current_win) session.meta.win.window))
                      (let [wrap? (clj.boolean (vim.api.nvim_get_option_value "wrap" {:win session.meta.win.window}))]
                        (pcall vim.api.nvim_set_option_value "linebreak" wrap? {:win session.meta.win.window})
                        (when (and rebuild-source-set!
                                   (not session.project-mode))
                          (pcall rebuild-source-set! session)
                          (pcall session.meta.on-update 0)
                          (events.send :on-query-update!
                            {:session session
                             :query (or session.prompt-last-applied-text "")
                             :refresh-lines true})))))
                  (set session.handling-layout-change? false)))))
          {:pattern "wrap"})
      ;; Keep selection/status/info synced when user scrolls or moves in the
      ;; main meta window with regular motions/mouse while prompt is open.
        (au! ["CursorMoved" "CursorMovedI"] session.meta.buf.buffer
          (fn [] (maybe-sync-from-main! session)))
        (au-buf! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn [_]
            (begin-direct-results-edit! session)))
        (au-buf! ["TextChanged" "TextChangedI"] session.meta.buf.buffer
          (fn [_]
            (when (and sign-mod session.meta session.meta.buf)
              (let [buf session.meta.buf.buffer
                    internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                                (and ok v))]
                (when-not internal?
                  (begin-direct-results-edit! session))
                (vim.schedule
                  (fn []
                    (when (and session.prompt-buf
                               (= (. active-by-prompt session.prompt-buf) session))
                      (pcall router.sync-live-edits session.prompt-buf)
                      (pcall maybe-sync-from-main! session true)
                      (events.send :on-query-update!
                        {:session session
                         :query (or session.prompt-last-applied-text "")
                         :refresh-lines true
                         :refresh-signs? true}))))))))
        (au-buf! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn [_]
            (when (and (not session.closing)
                       session.meta
                       session.meta.buf
                       (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
              (let [bo (. vim.bo session.meta.buf.buffer)]
                (set (. bo :buftype) "acwrite")
                (set (. bo :modifiable) true)
                (set (. bo :readonly) false)
                (set (. bo :bufhidden) "hide")))
            (when maybe-restore-hidden-ui!
              ;; Defer UI restoration until after the jump/BufEnter
              ;; command stack settles; restoring windows directly
              ;; inside BufEnter can surface invalid mark jumps.
              (vim.schedule
                (fn []
                  (when (and (not session.closing)
                             session.prompt-buf
                             (= (. active-by-prompt session.prompt-buf) session))
                    (pcall maybe-restore-hidden-ui! session)))))))
        (au-global! "WinNew"
          (fn [_]
            (vim.defer_fn
              (fn []
                (when (and hide-visible-ui!
                           (not session.ui-hidden)
                           session.prompt-buf
                           (= (. active-by-prompt session.prompt-buf) session))
                  (let [win (vim.api.nvim_get_current_win)]
                    (when (covered-by-new-window? session win)
                      (pcall hide-visible-ui! session)))))
              20)))
        (au-global! "BufWinEnter"
          (fn [ev]
            (vim.defer_fn
              (fn []
                (when (and hide-visible-ui!
                           (not session.ui-hidden)
                           session.prompt-buf
                           (= (. active-by-prompt session.prompt-buf) session))
                  (let [buf (or ev.buf (vim.api.nvim_get_current_buf))
                        win (or (first-window-for-buffer buf)
                                (vim.api.nvim_get_current_win))]
                    (when (or (transient-overlay-buffer? buf)
                              (covered-by-new-window? session win))
                      (pcall hide-visible-ui! session)))))
              20)))
        (au! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
          (fn []
            (events.send :on-selection-change!
              {:session session
               :line-nr (+ 1 (or session.meta.selected_index 0))
               :refresh-lines false})))
        (au-global! ["BufEnter" "WinEnter" "FocusGained"]
          (fn [_]
            (vim.schedule
              (fn []
                (when (and session.ui-hidden
                           session.prompt-buf
                           (= (. active-by-prompt session.prompt-buf) session)
                           (not (hidden-session-reachable? session)))
                  (pcall router.remove-session session))))))
        (au-buf! "BufLeave" session.meta.buf.buffer
          (fn [_]
            ;; When leaving the results buffer, check if the window it
            ;; was in is now showing something else. Project-mode
            ;; sessions should hide auxiliary UI and remain resumable;
            ;; regular sessions can close entirely.
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
                                (router.cancel session.prompt-buf)))))))))))
        (apply-main-keymaps router session)
        (apply-results-edit-keymaps session)
      ;; External file writes: invalidate cached file data and rebuild sources
      ;; so the info sidebar reflects the latest on-disk state.
        (au-global! "BufWritePost"
          (fn [ev]
            (vim.schedule
              (fn []
                (when (and session.prompt-buf
                           (= (. active-by-prompt session.prompt-buf) session)
                           (not session.closing))
                  (let [buf (or ev.buf (vim.api.nvim_get_current_buf))]
                    (when (and (vim.api.nvim_buf_is_valid buf)
                               (not= buf session.meta.buf.buffer))
                      (let [raw (vim.api.nvim_buf_get_name buf)
                            path (when (and raw (~= raw ""))
                                   (vim.fn.fnamemodify raw ":p"))]
                        (when path
                          ;; Clear per-session caches for this path.
                          (when session.preview-file-cache
                            (set (. session.preview-file-cache path) nil))
                          (when session.info-file-head-cache
                            (set (. session.info-file-head-cache path) nil))
                          (when session.info-file-meta-cache
                            (set (. session.info-file-meta-cache path) nil))
                          ;; Clear router-level project file cache entry.
                          (when router.project-file-cache
                            (set (. router.project-file-cache path) nil))
                          ;; Rebuild project source set and refresh info window.
                          (when rebuild-source-set!
                            (pcall rebuild-source-set! session))
                          (events.send :on-query-update!
                            {:session session
                             :query (or session.prompt-last-applied-text "")
                             :refresh-lines true}))))))))))
        (au-global! "WinScrolled"
          (fn [_]
            (schedule-scroll-sync! session)))
        (au-buf! "BufWriteCmd" session.meta.buf.buffer
          (fn [_]
            (router.write-results session.prompt-buf)))
        (au-buf! "BufWipeout" session.meta.buf.buffer
          (fn [_]
            (vim.schedule
              (fn []
                (router.results-buffer-wiped session.meta.buf.buffer)))))
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
