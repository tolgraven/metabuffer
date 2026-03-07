(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
(local M {})

(fn M.new
  [opts]
  "Public API: M.new."
  (let [{: mark-prompt-buffer! : default-prompt-keymaps : active-by-prompt
         : on-prompt-changed : update-info-window : maybe-sync-from-main!
         : schedule-scroll-sync!} opts]
    (fn disable-cmp
  [session]
      (mark-prompt-buffer! session.prompt-buf)
      (let [[ok cmp] [(pcall require :cmp)]]
        (when ok
          (pcall cmp.setup.buffer {:enabled false})
          (pcall cmp.abort))))

    (fn switch-mode
  [session which]
      (let [meta session.meta]
        (meta.switch_mode which)
        (pcall meta.refresh_statusline)))

    (fn session-prompt-valid?
  [session]
      (and session.meta
           session.prompt-buf
           (vim.api.nvim_buf_is_valid session.prompt-buf)))

    (fn schedule-when-valid
  [session f]
      (vim.schedule
        (fn []
          (when (session-prompt-valid? session)
            (f)))))

    (fn refresh-prompt-highlights!
  [session]
      (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
        (let [ns (or session.prompt-hl-ns (vim.api.nvim_create_namespace "metabuffer.prompt"))
              lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
          (set session.prompt-hl-ns ns)
          (vim.api.nvim_buf_clear_namespace session.prompt-buf ns 0 -1)
          (each [row line (ipairs (or lines []))]
            (let [r (- row 1)
                  txt (or line "")]
              (var pos 1)
              (while (<= pos (# txt))
                (let [[s e] [(string.find txt "%S+" pos)]]
                  (if (and s e)
                      (let [token (string.sub txt s e)
                            s0 (- s 1)
                            e0 e]
                        (when (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptNeg" r s0 e0))
                        (let [core (if (and (> (# token) 1) (= (string.sub token 1 1) "!"))
                                        (string.sub token 2)
                                        token)]
                          (when (and (> (# core) 0)
                                     (not (not (string.find core "[\\%[%]%(%)%+%*%?%|]"))))
                            (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptRegex" r s0 e0)))
                        (when (and (> (# token) 0) (= (string.sub token 1 1) "^"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r s0 (+ s0 1)))
                        (when (and (> (# token) 0) (= (string.sub token (# token)) "$"))
                          (vim.api.nvim_buf_add_highlight session.prompt-buf ns "MetaPromptAnchor" r (- e0 1) e0))
                        (set pos (+ e 1)))
                        (set pos (+ (# txt) 1))))))))))

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

    (fn resolve-map-action
  [router session action arg]
      (if
        (= action "accept")
        (fn [] (router.accept session.prompt-buf))
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
        nil))

    (fn apply-keymaps
      [router session]
      (let [base-opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}
            rules (if (= (type vim.g.meta_prompt_keymaps) "table")
                      vim.g.meta_prompt_keymaps
                      default-prompt-keymaps)]
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
      (let [opts {:buffer session.prompt-buf :silent true :noremap true :nowait true}]
        (vim.keymap.set "i" "<C-a>"
          (fn [] (schedule-when-valid session
                   (fn []
                     (router.prompt-home session.prompt-buf))))
          opts)
        (vim.keymap.set "i" "<C-e>"
          (fn [] (schedule-when-valid session
                   (fn []
                     (router.prompt-end session.prompt-buf))))
          opts)
        (vim.keymap.set "i" "<C-u>"
          (fn [] (schedule-when-valid session
                   (fn []
                     (router.prompt-kill-backward session.prompt-buf))))
          opts)
        (vim.keymap.set "i" "<C-k>"
          (fn [] (schedule-when-valid session
                   (fn []
                     (router.prompt-kill-forward session.prompt-buf))))
          opts)
        (vim.keymap.set "i" "<C-y>"
          (fn [] (schedule-when-valid session
                   (fn []
                     (router.prompt-yank session.prompt-buf))))
          opts)))

    (fn register!
  [router session]
      (let [aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true})]
        (set session.augroup aug)
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
        (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (if (maybe-expand-history-shorthand! router session)
                           nil
                           (do
                             (refresh-prompt-highlights! session)
                             (on-prompt-changed
                               session.prompt-buf
                               false
                               (vim.api.nvim_buf_get_changedtick session.prompt-buf)))))})
      ;; Re-assert prompt maps when entering insert mode; this wins over late
      ;; plugin mappings (for example completion plugins).
        (vim.api.nvim_create_autocmd "InsertEnter"
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid
                         session
                         (fn []
                           (disable-cmp session)
                           (apply-keymaps router session)
                           (apply-emacs-insert-fallbacks router session))))})
      ;; Some statusline plugins or focus transitions (for example tmux pane
      ;; switches) can overwrite local statusline state. Re-apply ours when the
      ;; prompt window regains focus.
        (vim.api.nvim_create_autocmd ["BufEnter" "WinEnter" "FocusGained"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (pcall session.meta.refresh_statusline))))})
      ;; Refresh mode segment when switching Insert/Normal/Replace in the prompt.
        (vim.api.nvim_create_autocmd ["ModeChanged" "InsertEnter" "InsertLeave"]
          {:group aug
           :buffer session.prompt-buf
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (pcall session.meta.refresh_statusline))))})
      ;; Recompute floating info rendering/width when editor windows resize.
        (vim.api.nvim_create_autocmd ["VimResized" "WinResized"]
          {:group aug
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (pcall update-info-window session))))})
      ;; Keep selection/status/info synced when user scrolls or moves in the
      ;; main meta window with regular motions/mouse while prompt is open.
        (vim.api.nvim_create_autocmd ["CursorMoved" "CursorMovedI"]
          {:group aug
           :buffer session.meta.buf.buffer
           :callback (fn [_]
                       (schedule-when-valid session
                         (fn []
                           (maybe-sync-from-main! session))))})
        (vim.keymap.set "n" "!"
          (fn []
            (router.exclude-symbol-under-cursor session.prompt-buf))
          {:buffer session.meta.buf.buffer :silent true :noremap true})
        (vim.api.nvim_create_autocmd "WinScrolled"
          {:group aug
           :callback (fn [_]
                       (schedule-scroll-sync! session))})
        (disable-cmp session)
        (mark-prompt-buffer! session.prompt-buf)
        (refresh-prompt-highlights! session)
        (apply-keymaps router session)
        (apply-emacs-insert-fallbacks router session)))

    {:register! register!}))

M
