(import-macros {: when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Build keymap and direct-results-edit helpers for prompt hooks."
  (let [{: default-prompt-keymaps : default-main-keymaps
         : schedule-when-valid : switch-mode : sign-mod} opts]
    (fn resolve-map-action
      [router session action arg]
      (if
        (= action "accept")
        (fn [] (router.accept session.prompt-buf))
        (= action "enter-edit-mode")
        (fn [] (router.enter-edit-mode session.prompt-buf))
        (= action "cancel")
        (fn [] (router.cancel session.prompt-buf))
        (= action "move-selection")
        (fn [] (router.move-selection session.prompt-buf arg))
        (= action "history-or-move")
        (fn [] (router.history-or-move session.prompt-buf arg))
        (= action "prompt-home")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-home session.prompt-buf))))
        (= action "prompt-end")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-end session.prompt-buf))))
        (= action "prompt-kill-backward")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-kill-backward session.prompt-buf))))
        (= action "prompt-kill-forward")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-kill-forward session.prompt-buf))))
        (= action "prompt-yank")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-yank session.prompt-buf))))
        (= action "prompt-newline")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.prompt-newline session.prompt-buf))))
        (= action "insert-last-prompt")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-prompt session.prompt-buf))))
        (= action "insert-last-token")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-token session.prompt-buf))))
        (= action "insert-last-tail")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.insert-last-tail session.prompt-buf))))
        (= action "toggle-prompt-results-focus")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.toggle-prompt-results-focus session.prompt-buf))))
        (= action "negate-current-token")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.negate-current-token session.prompt-buf))))
        (= action "history-searchback")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.open-history-searchback session.prompt-buf))))
        (= action "merge-history")
        (fn [] (schedule-when-valid session
                 (fn []
                   (router.merge-history-cache session.prompt-buf))))
        (= action "switch-mode")
        (fn [] (switch-mode session arg))
        (= action "toggle-scan-option")
        (fn [] (router.toggle-scan-option session.prompt-buf arg))
        (= action "scroll-main")
        (fn [] (router.scroll-main session.prompt-buf arg))
        (= action "toggle-project-mode")
        (fn [] (router.toggle-project-mode session.prompt-buf))
        (= action "toggle-info-file-entry-view")
        (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
        (= action "refresh-files")
        (fn [] (router.refresh-files session.prompt-buf))
        nil))

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
      (if
        (= action "cancel")
        (fn [] (router.cancel session.prompt-buf))
        (= action "accept-main")
        (fn [] (router.accept-main session.prompt-buf))
        (= action "enter-edit-mode")
        (fn [] (router.enter-edit-mode session.prompt-buf))
        (= action "exclude-symbol-under-cursor")
        (fn [] (router.exclude-symbol-under-cursor session.prompt-buf))
        (= action "insert-symbol-under-cursor")
        (fn [] (router.insert-symbol-under-cursor session.prompt-buf))
        (= action "insert-symbol-under-cursor-newline")
        (fn [] (router.insert-symbol-under-cursor-newline session.prompt-buf))
        (= action "toggle-prompt-results-focus")
        (fn [] (router.toggle-prompt-results-focus session.prompt-buf))
        (= action "scroll-main")
        (fn [] (router.scroll-main session.prompt-buf arg))
        (= action "toggle-info-file-entry-view")
        (fn [] (router.toggle-info-file-entry-view session.prompt-buf))
        (= action "refresh-files")
        (fn [] (router.refresh-files session.prompt-buf))
        nil))

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
