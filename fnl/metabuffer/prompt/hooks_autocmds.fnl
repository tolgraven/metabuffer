(local events (require :metabuffer.events))
(local M {})

(fn M.new
  [opts]
  "Build grouped prompt, results, and global autocmd registration helpers."
  (let [{: active-by-prompt : prompt-animation-delay-ms
         : refresh-prompt-highlights!
         : maybe-expand-history-shorthand! : on-prompt-changed
         : maybe-show-directive-help! : maybe-trigger-directive-complete!
         : hide-directive-help! : apply-keymaps : apply-emacs-insert-fallbacks
         : apply-main-keymaps : apply-results-edit-keymaps
         : capture-expected-layout! : handle-global-resize! : handle-wrap-option-set!
         : handle-results-cursor! : handle-results-edit-enter! : handle-results-text-changed!
         : handle-results-focus! : handle-overlay-winnew! : handle-overlay-bufwinenter!
         : handle-selection-focus! : handle-hidden-session-gc! : handle-results-leave!
         : handle-external-write! : handle-scroll-sync! : handle-results-writecmd!
         : handle-results-wipeout!} (or opts {})]
    (fn attach-prompt-buffer!
      [router session]
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
      [router session au! au-buf!]
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
      [router session au-global!]
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
      [router session au! au-buf!]
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
      [router session]
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

    {:attach-prompt-buffer! attach-prompt-buffer!
     :register-prompt-autocmds! register-prompt-autocmds!
     :register-global-autocmds! register-global-autocmds!
     :register-results-autocmds! register-results-autocmds!
     :finalize-registration! finalize-registration!}))

M
