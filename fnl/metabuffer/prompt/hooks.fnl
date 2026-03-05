(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
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

    (fn resolve-map-action
  [router session action arg]
      (if
        (= action "accept")
        (fn [] (router.finish "accept" session.prompt-buf))
        (= action "cancel")
        (fn [] (router.finish "cancel" session.prompt-buf))
        (= action "move-selection")
        (fn [] (router.move-selection session.prompt-buf arg))
        (= action "history-or-move")
        (fn [] (router.history-or-move session.prompt-buf arg))
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
      (local opts {:buffer session.prompt-buf :silent true :noremap true :nowait true})
      (fn map!
  [m lhs rhs]
        (vim.keymap.set m lhs rhs opts))
      (fn map-rules!
  [rules]
        (each [_ r (ipairs rules)]
          (let [mode (. r 1)
                lhs (. r 2)
                action (. r 3)
                arg (. r 4)
                rhs (resolve-map-action router session action arg)]
            (if rhs
                (map! mode lhs rhs)
                (vim.notify
                  (.. "metabuffer: unknown prompt keymap action '" (tostring action) "' for " (tostring lhs))
                  vim.log.levels.WARN)))))
      (local rules
        (if (= (type vim.g.meta_prompt_keymaps) "table")
            vim.g.meta_prompt_keymaps
            default-prompt-keymaps))
      (map-rules! rules))

    (fn register!
  [router session]
      (local aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true}))
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
                           (on-prompt-changed session.prompt-buf false changedtick)))))
         :on_detach (fn []
                      (when session.prompt-buf
                        (set (. active-by-prompt session.prompt-buf) nil)))})
      ;; Prompt text updates: rely on post-change autocmds to avoid pre-edit race
      ;; behavior that can leave matcher one character behind while typing.
      (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
        {:group aug
         :buffer session.prompt-buf
         :callback (fn [_]
                     (on-prompt-changed
                       session.prompt-buf
                       false
                       (vim.api.nvim_buf_get_changedtick session.prompt-buf)))})
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
                         (apply-keymaps router session))))})
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
      (vim.api.nvim_create_autocmd "WinScrolled"
        {:group aug
         :callback (fn [_]
                     (schedule-scroll-sync! session))})
      (disable-cmp session)
      (mark-prompt-buffer! session.prompt-buf)
      (apply-keymaps router session))

    {:register! register!}))

M
