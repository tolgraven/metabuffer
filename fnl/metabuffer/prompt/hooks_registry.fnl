(local M {})
(local hooks-autocmds-mod (require :metabuffer.prompt.hooks_autocmds))
(local hooks-history-expand-mod (require :metabuffer.prompt.hooks_history_expand))

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
         : handle-results-wipeout!} (or opts {})
        history-expand (hooks-history-expand-mod.new
                         {:active-by-prompt active-by-prompt})
        maybe-expand-history-shorthand! (. history-expand :maybe-expand-history-shorthand!)
        autocmds (hooks-autocmds-mod.new
                   {:active-by-prompt active-by-prompt
                    :schedule-when-valid schedule-when-valid
                    :prompt-animation-delay-ms prompt-animation-delay-ms
                    :refresh-prompt-highlights! refresh-prompt-highlights!
                    :maybe-expand-history-shorthand! maybe-expand-history-shorthand!
                    :on-prompt-changed on-prompt-changed
                    :maybe-show-directive-help! maybe-show-directive-help!
                    :maybe-trigger-directive-complete! maybe-trigger-directive-complete!
                    :hide-directive-help! hide-directive-help!
                    :apply-keymaps apply-keymaps
                    :apply-emacs-insert-fallbacks apply-emacs-insert-fallbacks
                    :apply-main-keymaps apply-main-keymaps
                    :apply-results-edit-keymaps apply-results-edit-keymaps
                    :capture-expected-layout! capture-expected-layout!
                    :handle-global-resize! handle-global-resize!
                    :handle-wrap-option-set! handle-wrap-option-set!
                    :handle-results-cursor! handle-results-cursor!
                    :handle-results-edit-enter! handle-results-edit-enter!
                    :handle-results-text-changed! handle-results-text-changed!
                    :handle-results-focus! handle-results-focus!
                    :handle-overlay-winnew! handle-overlay-winnew!
                    :handle-overlay-bufwinenter! handle-overlay-bufwinenter!
                    :handle-selection-focus! handle-selection-focus!
                    :handle-hidden-session-gc! handle-hidden-session-gc!
                    :handle-results-leave! handle-results-leave!
                    :handle-external-write! handle-external-write!
                    :handle-scroll-sync! handle-scroll-sync!
                    :handle-results-writecmd! handle-results-writecmd!
                    :handle-results-wipeout! handle-results-wipeout!})
        attach-prompt-buffer! (. autocmds :attach-prompt-buffer!)
        register-prompt-autocmds! (. autocmds :register-prompt-autocmds!)
        register-global-autocmds! (. autocmds :register-global-autocmds!)
        register-results-autocmds! (. autocmds :register-results-autocmds!)
        finalize-registration! (. autocmds :finalize-registration!)]

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

        (attach-prompt-buffer! router session)
        (register-prompt-autocmds! router session au! au-buf!)
        (register-global-autocmds! router session au-global!)
        (register-results-autocmds! router session au! au-buf!)
        (finalize-registration! router session)))

    {:register! register!}))

M
