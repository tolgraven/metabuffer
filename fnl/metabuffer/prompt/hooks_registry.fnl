(local M {})
(local events (require :metabuffer.events))

(fn M.new
  [opts]
  "Build prompt/results/global autocmd registration helpers."
  (let [{: active-by-prompt : on-prompt-changed
         : schedule-when-valid : prompt-animation-delay-ms
         : refresh-prompt-highlights!
         : maybe-show-directive-help! : maybe-trigger-directive-complete!
         : hide-directive-help! : apply-keymaps : apply-emacs-insert-fallbacks
         : apply-main-keymaps : apply-results-edit-keymaps
         : capture-expected-layout! : handle-global-resize! : handle-wrap-option-set!
         : handle-results-cursor! : handle-results-edit-enter! : handle-results-text-changed!
         : handle-results-focus! : handle-overlay-winnew! : handle-overlay-bufwinenter!
         : handle-selection-focus! : handle-hidden-session-gc! : handle-results-leave!
         : handle-external-write! : handle-scroll-sync! : handle-results-writecmd!
         : handle-results-wipeout!} (or opts {})]
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
          [evs buf body]
          (vim.api.nvim_create_autocmd evs
            {:group aug
             :buffer buf
             :callback (fn [_]
                         (schedule-when-valid session body))}))
        (fn au-buf!
          [evs buf callback]
          (vim.api.nvim_create_autocmd evs {:group aug :buffer buf :callback callback}))
        (fn au-global!
          [evs callback ?opts]
          (let [base {:group aug :callback callback}]
            (each [k v (pairs (or ?opts {}))]
              (tset base k v))
            (vim.api.nvim_create_autocmd evs base)))

        (fn attach-prompt-buffer!
          []
          (vim.api.nvim_buf_attach session.prompt-buf false
            {:on_lines (fn [_ _ changedtick _ _ _ _ _]
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
                            (set (. active-by-prompt session.prompt-buf) nil)))}))

        (fn register-prompt-autocmds!
          []
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
          (au! "InsertEnter" session.prompt-buf
            (fn []
              (events.send :on-insert-enter! {:session session})
              (apply-keymaps router session)
              (apply-emacs-insert-fallbacks router session)))
          (au! ["BufEnter" "WinEnter" "FocusGained"] session.prompt-buf
            (fn []
              (events.post :on-prompt-focus!
                {:session session}
                {:supersede? true
                 :dedupe-key (.. "on-prompt-focus:" (tostring session.prompt-buf))})))
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
            (fn [] (hide-directive-help! session))))

        (fn register-global-autocmds!
          []
          (au-global! ["VimResized" "WinResized"]
            (fn [ev]
              (handle-global-resize! session ev)))
          (au-global! "OptionSet"
            (fn [_]
              (handle-wrap-option-set! session))
            {:pattern "wrap"})
          (au-global! "WinNew"
            (fn [_]
              (handle-overlay-winnew! session)))
          (au-global! "BufWinEnter"
            (fn [ev]
              (handle-overlay-bufwinenter! session ev)))
          (au-global! ["BufEnter" "WinEnter" "FocusGained"]
            (fn [_]
              (handle-hidden-session-gc! router session)))
          (au-global! "BufWritePost"
            (fn [ev]
              (handle-external-write! router session ev)))
          (au-global! "WinScrolled"
            (fn [_]
              (handle-scroll-sync! session))))

        (fn register-results-autocmds!
          []
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
          (au-buf! ["BufEnter" "WinEnter" "FocusGained"] session.meta.buf.buffer
            (fn []
              (handle-selection-focus! session)))
          (au-buf! "BufLeave" session.meta.buf.buffer
            (fn [_]
              (handle-results-leave! router session)))
          (au-buf! "BufWriteCmd" session.meta.buf.buffer
            (fn [_]
              (handle-results-writecmd! router session)))
          (au-buf! "BufWipeout" session.meta.buf.buffer
            (fn [_]
              (handle-results-wipeout! router session))))

        (fn finalize-registration!
          []
          (refresh-prompt-highlights! session)
          (maybe-show-directive-help! session)
          (vim.defer_fn
            (fn []
              (when (and session.prompt-buf
                         (= (. active-by-prompt session.prompt-buf) session))
                (pcall refresh-prompt-highlights! session)
                (capture-expected-layout! session)))
            (prompt-animation-delay-ms session))
          (apply-keymaps router session)
          (apply-emacs-insert-fallbacks router session)
          (apply-main-keymaps router session)
          (apply-results-edit-keymaps session))

        (attach-prompt-buffer!)
        (register-prompt-autocmds!)
        (register-global-autocmds!)
        (register-results-autocmds!)
        (finalize-registration!)))

    {:register! register!}))

M
