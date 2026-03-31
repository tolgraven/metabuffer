(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Build keymap and direct-results-edit helpers for prompt hooks."
  (let [{: default-prompt-keymaps : default-main-keymaps
         : schedule-when-valid : switch-mode : sign-mod} opts]
    (fn resolve-map-action
      [router session action arg]
      (let [defer-router (fn [method]
                           (fn []
                             (schedule-when-valid session
                               (fn []
                                 (method router session.prompt-buf)))))
            dispatch
            {:accept (fn [] (router.accept session.prompt-buf))
             :enter-edit-mode (fn [] (router.enter-edit-mode session.prompt-buf))
             :cancel (fn [] (router.cancel session.prompt-buf))
             :move-selection (fn [] (router.move-selection session.prompt-buf arg))
             :history-or-move (fn [] (router.history-or-move session.prompt-buf arg))
             :prompt-home (defer-router (. router :prompt-home))
             :prompt-end (defer-router (. router :prompt-end))
             :prompt-kill-backward (defer-router (. router :prompt-kill-backward))
             :prompt-kill-forward (defer-router (. router :prompt-kill-forward))
             :prompt-yank (defer-router (. router :prompt-yank))
             :prompt-newline (defer-router (. router :prompt-newline))
             :insert-last-prompt (defer-router (. router :insert-last-prompt))
             :insert-last-token (defer-router (. router :insert-last-token))
             :insert-last-tail (defer-router (. router :insert-last-tail))
             :toggle-prompt-results-focus (defer-router (. router :toggle-prompt-results-focus))
             :negate-current-token (defer-router (. router :negate-current-token))
             :history-searchback (defer-router (. router :open-history-searchback))
             :merge-history (defer-router (. router :merge-history-cache))
             :switch-mode (fn [] (switch-mode session arg))
             :toggle-scan-option (fn [] (router.toggle-scan-option session.prompt-buf arg))
             :scroll-main (fn [] (router.scroll-main session.prompt-buf arg))
             :toggle-project-mode (fn [] (router.toggle-project-mode session.prompt-buf))
             :toggle-info-file-entry-view (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
             :refresh-files (fn [] (router.refresh-files session.prompt-buf))}]
        (. dispatch action)))

    (fn apply-keymaps
      [router session]
      (let [base-opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}
            rules (or session.prompt-keymaps default-prompt-keymaps)]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                opts (if (or (= action "insert-last-prompt")
                             (= action "insert-last-token")
                             (= action "insert-last-tail"))
                         (vim.tbl_extend "force" base-opts {:nowait false})
                         base-opts)
                rhs (resolve-map-action router session action arg)]
            (if rhs
                (vim.keymap.set mode lhs rhs opts)
                (vim.notify
                  (.. "metabuffer: unknown prompt keymap action '" (tostring action) "' for " (tostring lhs))
                  vim.log.levels.WARN))))))

    (fn apply-emacs-insert-fallbacks
      [router session]
      (let [base-opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}
            rules (or session.prompt-fallback-keymaps [])]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                rhs (resolve-map-action router session action arg)]
            (when rhs
              (vim.keymap.set mode lhs rhs base-opts))))))

    (fn resolve-main-map-action
      [router session action arg]
      (let [dispatch
            {:cancel (fn [] (router.cancel session.prompt-buf))
             :accept-main (fn [] (router.accept-main session.prompt-buf))
             :enter-edit-mode (fn [] (router.enter-edit-mode session.prompt-buf))
             :exclude-symbol-under-cursor (fn [] (router.exclude-symbol-under-cursor session.prompt-buf))
             :insert-symbol-under-cursor (fn [] (router.insert-symbol-under-cursor session.prompt-buf))
             :insert-symbol-under-cursor-newline (fn [] (router.insert-symbol-under-cursor-newline session.prompt-buf))
             :toggle-prompt-results-focus (fn [] (router.toggle-prompt-results-focus session.prompt-buf))
             :scroll-main (fn [] (router.scroll-main session.prompt-buf arg))
             :toggle-info-file-entry-view (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
             :refresh-files (fn [] (router.refresh-files session.prompt-buf))}]
        (. dispatch action)))

    (fn apply-main-keymaps
      [router session]
      (let [base-opts {:buffer session.meta.buf.buffer :silent true :noremap true :nowait true}
            rules (or session.main-keymaps default-main-keymaps)]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                rhs (resolve-main-map-action router session action arg)]
            (if rhs
                (vim.keymap.set mode lhs rhs base-opts)
                (vim.notify
                  (.. "metabuffer: unknown main keymap action '" (tostring action) "' for " (tostring lhs))
                  vim.log.levels.WARN))))))

    (fn feed-results-normal-key!
      [key]
      (vim.api.nvim_feedkeys
        (vim.api.nvim_replace_termcodes key true false true)
        "n"
        false))

    (fn set-pending-structural-edit!
      [session side]
      (when (and session.results-edit-mode session.meta session.meta.win
                 (vim.api.nvim_win_is_valid session.meta.win.window))
        (let [row (. (vim.api.nvim_win_get_cursor session.meta.win.window) 1)
              idx (. (or session.meta.buf.indices []) row)
              ref (and idx (. (or session.meta.buf.source-refs []) idx))]
          (when (and ref ref.path ref.lnum)
            (set session.pending-structural-edit
                 {:path ref.path
                  :lnum ref.lnum
                  :side side
                  :kind (or ref.kind "")})))))

    (fn apply-results-edit-keymaps
      [session]
      (let [opts {:buffer session.meta.buf.buffer :silent true :noremap true :nowait true}]
        (vim.keymap.set "n" "o"
          (fn []
            (set-pending-structural-edit! session "after")
            (feed-results-normal-key! "o"))
          opts)
        (vim.keymap.set "n" "O"
          (fn []
            (set-pending-structural-edit! session "before")
            (feed-results-normal-key! "O"))
          opts)
        (vim.keymap.set "n" "p"
          (fn []
            (set-pending-structural-edit! session "after")
            (feed-results-normal-key! "p"))
          opts)
        (vim.keymap.set "n" "P"
          (fn []
            (set-pending-structural-edit! session "before")
            (feed-results-normal-key! "P"))
          opts)))

    (fn begin-direct-results-edit!
      [session]
      (when (and sign-mod session.meta session.meta.buf
                 (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
        (let [buf session.meta.buf.buffer
              internal? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_internal_render")]]
                          (and ok v))
              manual? (let [[ok v] [(pcall vim.api.nvim_buf_get_var buf "meta_manual_edit_active")]]
                        (and ok v))]
          (when-not (or internal? manual?)
            (set session.results-edit-mode true)
            (pcall sign-mod.capture-baseline! session)
            (pcall vim.api.nvim_buf_set_var buf "meta_manual_edit_active" true)))))

    {:apply-keymaps apply-keymaps
     :apply-emacs-insert-fallbacks apply-emacs-insert-fallbacks
     :apply-main-keymaps apply-main-keymaps
     :apply-results-edit-keymaps apply-results-edit-keymaps
     :begin-direct-results-edit! begin-direct-results-edit!}))

M
