(local meta_mod (require :metabuffer.meta))
(local prompt_window_mod (require :metabuffer.window.prompt))
(local base_buffer (require :metabuffer.buffer.base))
(local state (require :metabuffer.core.state))

(local M {})
(set M.instances {})
(set M.active-by-source {})
(set M.active-by-prompt {})
(set M.history-max 100)

(fn history-list []
  (if (= (type vim.g.metabuffer_prompt_history) "table")
      vim.g.metabuffer_prompt_history
      (do
        (set vim.g.metabuffer_prompt_history [])
        vim.g.metabuffer_prompt_history)))

(fn push-history! [text]
  (when (and (= (type text) "string") (~= (vim.trim text) ""))
    (local h (history-list))
    (if (or (= (# h) 0) (~= (. h (# h)) text))
        (table.insert h text))
    (while (> (# h) M.history-max)
      (table.remove h 1))))

(fn prompt-lines [session]
  (if (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
      (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)
      []))

(fn prompt-text [session]
  (table.concat (prompt-lines session) "\n"))

(fn set-prompt-text! [session text]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (local lines (if (= text "") [""] (vim.split text "\n" {:plain true})))
    (vim.api.nvim_buf_set_lines session.prompt-buf 0 -1 false lines)
    (let [row (# lines)
          col (# (. lines row))]
      (pcall vim.api.nvim_win_set_cursor session.prompt-win [row col]))))

(fn history-entry [session idx]
  (let [h (history-list)
        n (# h)]
    (if (and (> idx 0) (<= idx n))
        (. h (+ (- n idx) 1))
        nil)))

(fn wipe-temp-buffers [meta]
  (when meta
    (let [main-buf meta.buf.buffer
          model-buf meta.buf.model
          index-buf (and meta.buf.indexbuf meta.buf.indexbuf.buffer)]
      (when (and index-buf (not (= index-buf model-buf)) (vim.api.nvim_buf_is_valid index-buf))
        (pcall vim.api.nvim_buf_delete index-buf {:force true}))
      (when (and main-buf (not (= main-buf model-buf)) (vim.api.nvim_buf_is_valid main-buf))
        (pcall vim.api.nvim_buf_delete main-buf {:force true})))))

(fn setup-state [query mode]
  (if (and (= mode "resume") vim.b._meta_context)
      (let [ctx (vim.deepcopy vim.b._meta_context)]
        (when (and query (~= query ""))
          (set ctx.text query)
          (set ctx.caret-locus (# query)))
        ctx)
      (state.default-condition (or query ""))))

(fn M._store_vars [meta]
  (set vim.b._meta_context (meta.store))
  (set vim.b._meta_indexes meta.buf.indices)
  (set vim.b._meta_updates meta.updates)
  (set vim.b._meta_source_bufnr meta.buf.model)
  meta)

(fn M._wrapup [meta]
  (vim.cmd "redraw|redrawstatus")
  (M._store_vars meta))

(fn remove-session [session]
  (when session
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (push-history! (prompt-text session)))
    (when session.augroup
      (pcall vim.api.nvim_del_augroup_by_id session.augroup))
    (when (and session.prompt-win (vim.api.nvim_win_is_valid session.prompt-win))
      (pcall vim.api.nvim_win_close session.prompt-win true))
    (when (and session.prompt-buf (vim.api.nvim_buf_is_valid session.prompt-buf))
      (pcall vim.api.nvim_buf_delete session.prompt-buf {:force true}))
    (when session.source-buf
      (tset M.active-by-source session.source-buf nil))
    (when session.prompt-buf
      (tset M.active-by-prompt session.prompt-buf nil))))

(fn apply-prompt-lines [session]
  (when (and session (vim.api.nvim_buf_is_valid session.prompt-buf))
    (let [lines (vim.api.nvim_buf_get_lines session.prompt-buf 0 -1 false)]
      (session.meta.set-query-lines lines)
      (let [[ok err] [(pcall session.meta.on-update 0)]]
        (if ok
            (session.meta.refresh_statusline)
            (when (string.find (tostring err) "E565")
              ;; Textlock race: retry right after current input cycle.
              (vim.defer_fn (fn []
                              (when (and session.meta
                                         (vim.api.nvim_buf_is_valid session.meta.buf.buffer))
                                (pcall session.meta.on-update 0)
                                (pcall session.meta.refresh_statusline)))
                            1)))))))

(fn M.on-prompt-changed [prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      ;; Buffer change callbacks run under textlock; schedule updates so
      ;; rendering and window mutations are allowed.
      (vim.schedule (fn []
                      (apply-prompt-lines session))))))

(fn finish-accept [session]
  (local curr session.meta)
  (apply-prompt-lines session)
  (pcall vim.cmd "stopinsert")
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher)))
  (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
  (when (and (vim.api.nvim_win_is_valid session.origin-win)
             (vim.api.nvim_buf_is_valid session.origin-buf))
    (pcall vim.api.nvim_set_current_win session.origin-win)
    (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
  (base_buffer.switch-buf curr.buf.model)
  (let [row (curr.selected_line)]
    (curr.win.set-row row true)
    (let [vq (curr.vim_query)]
      (when (~= vq "")
        (vim.api.nvim_win_set_cursor 0 [row 0])
        (let [pos (vim.fn.searchpos vq "cnW" row)
              hit-row (. pos 1)
              hit-col (. pos 2)]
          (when (and (= hit-row row) (> hit-col 0))
            (vim.api.nvim_win_set_cursor 0 [row (- hit-col 1)]))))))
  (vim.cmd "normal! zv")
  (let [vq (curr.vim_query)]
    (when (~= vq "")
      (vim.fn.setreg "/" vq)
      (set vim.o.hlsearch true)))
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn finish-cancel [session]
  (local curr session.meta)
  (pcall vim.cmd "stopinsert")
  (let [matcher (curr.matcher)]
    (when matcher
      (pcall matcher.remove-highlight matcher)))
  (pcall vim.cmd (.. "sign unplace * buffer=" curr.buf.buffer))
  (vim.cmd "silent! nohlsearch")
  (when (and (vim.api.nvim_win_is_valid session.origin-win)
             (vim.api.nvim_buf_is_valid session.origin-buf))
    (pcall vim.api.nvim_set_current_win session.origin-win)
    (pcall vim.api.nvim_win_set_buf session.origin-win session.origin-buf))
  (base_buffer.switch-buf curr.buf.model)
  (wipe-temp-buffers curr)
  (remove-session session)
  (M._wrapup curr)
  curr)

(fn M.finish [kind prompt-buf]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (if (= kind "accept")
          (finish-accept session)
          (finish-cancel session)))))

(fn M.move-selection [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [runner (fn []
                     (let [meta session.meta
                           max (# meta.buf.indices)]
                       (when (> max 0)
                         (set meta.selected_index (math.max 0 (math.min (+ meta.selected_index delta) (- max 1))))
                         (let [row (+ meta.selected_index 1)]
                           (when (vim.api.nvim_win_is_valid meta.win.window)
                             (pcall vim.api.nvim_win_set_cursor meta.win.window [row 0])))
                         (pcall meta.refresh_statusline))))
            mode (. (vim.api.nvim_get_mode) :mode)]
        (if (and (= (type mode) "string") (vim.startswith mode "i"))
            (vim.schedule runner)
            (runner))))))

(fn M.history-or-move [prompt-buf delta]
  (let [session (. M.active-by-prompt prompt-buf)]
    (when session
      (let [txt (prompt-text session)
            can-history (or (= txt "")
                            (= txt session.initial-prompt-text)
                            (= txt session.last-history-text))]
        (if can-history
            (let [h (history-list)
                  n (# h)]
              (when (> n 0)
                (set session.history-index (math.max 0 (math.min (+ session.history-index delta) n)))
                (if (= session.history-index 0)
                    (do
                      (set session.last-history-text "")
                      (set-prompt-text! session session.initial-prompt-text))
                    (let [entry (history-entry session session.history-index)]
                      (when entry
                        (set session.last-history-text entry)
                        (set-prompt-text! session entry))))))
            (M.move-selection prompt-buf delta))))))

(fn register-prompt-hooks [session]
  (fn disable-cmp []
    (let [[ok cmp] [(pcall require :cmp)]]
      (when ok
        (pcall cmp.setup.buffer {:enabled false})
        (pcall cmp.abort))))
  (fn switch-mode [which]
    (let [meta session.meta]
      (meta.switch_mode which)
      (pcall meta.refresh_statusline)))
  (fn apply-keymaps []
    (vim.keymap.set ["n" "i"] "<CR>"
      (fn [] (M.finish "accept" session.prompt-buf))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    ;; In insert mode, <Esc> should only leave insert mode.
    ;; Cancel/close only from normal mode.
    (vim.keymap.set "n" "<Esc>"
      (fn [] (M.finish "cancel" session.prompt-buf))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "n" "<C-p>"
      (fn [] (M.move-selection session.prompt-buf -1))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "n" "<C-n>"
      (fn [] (M.move-selection session.prompt-buf 1))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "i" "<C-p>"
      "<Cmd>lua require('metabuffer.router')['move-selection'](vim.api.nvim_get_current_buf(), -1)<CR>"
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "i" "<C-n>"
      "<Cmd>lua require('metabuffer.router')['move-selection'](vim.api.nvim_get_current_buf(), 1)<CR>"
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "i" "<Up>"
      "<Cmd>lua require('metabuffer.router')['history-or-move'](vim.api.nvim_get_current_buf(), 1)<CR>"
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set "i" "<Down>"
      "<Cmd>lua require('metabuffer.router')['history-or-move'](vim.api.nvim_get_current_buf(), -1)<CR>"
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    ;; Statusline keys: C^ (matcher), C_ (case), Cs (syntax)
    (vim.keymap.set ["n" "i"] "<C-^>"
      (fn [] (switch-mode "matcher"))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set ["n" "i"] "<C-6>"
      (fn [] (switch-mode "matcher"))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set ["n" "i"] "<C-_>"
      (fn [] (switch-mode "case"))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set ["n" "i"] "<C-o>"
      (fn [] (switch-mode "case"))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true})
    (vim.keymap.set ["n" "i"] "<C-s>"
      (fn [] (switch-mode "syntax"))
      {:buffer session.prompt-buf :silent true :noremap true :nowait true}))
  (local aug (vim.api.nvim_create_augroup (.. "MetaPrompt" session.prompt-buf) {:clear true}))
  (set session.augroup aug)
  ;; Low-level buffer attach catches edits reliably across Insert/Normal modes
  ;; and user configs where TextChangedI autocmds may not fire as expected.
  (vim.api.nvim_buf_attach session.prompt-buf false
    {:on_lines (fn [_ _ _ _ _ _ _ _]
                 (M.on-prompt-changed session.prompt-buf))
     :on_detach (fn []
                  (when session.prompt-buf
                    (tset M.active-by-prompt session.prompt-buf nil)))})
  ;; Keep autocmd hooks as a fallback.
  (vim.api.nvim_create_autocmd ["TextChanged" "TextChangedI"]
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (M.on-prompt-changed session.prompt-buf))})
  ;; Re-assert prompt maps when entering insert mode; this wins over late
  ;; plugin mappings (for example completion plugins).
  (vim.api.nvim_create_autocmd "InsertEnter"
    {:group aug
     :buffer session.prompt-buf
     :callback (fn [_]
                 (vim.schedule
                   (fn []
                     (disable-cmp)
                     (apply-keymaps))))})
  (disable-cmp)
  (apply-keymaps)
  )

(fn M.start [query mode _meta]
  (local source-buf (vim.api.nvim_get_current_buf))
  (when (. M.active-by-source source-buf)
    (remove-session (. M.active-by-source source-buf)))
  (let [origin-win (vim.api.nvim_get_current_win)
        origin-buf source-buf
        condition (setup-state query mode)
        curr (meta_mod.new vim condition)]
    (base_buffer.switch-buf curr.buf.buffer)
    (curr.on-init)
    (let [initial-lines (if (and query (~= query ""))
                            (vim.split query "\n" {:plain true})
                            [""])
          prompt-win (prompt_window_mod.new vim {:height (or vim.g.meta_prompt_height 3)})
          prompt-buf prompt-win.buffer
          session {:source-buf source-buf
                   :origin-win origin-win
                   :origin-buf origin-buf
                   :prompt-win prompt-win.window
                   :prompt-buf prompt-buf
                   :initial-prompt-text (table.concat initial-lines "\n")
                   :last-history-text ""
                   :history-index 0
                   :meta curr}]
      (vim.api.nvim_buf_set_lines prompt-buf 0 -1 false initial-lines)
      (register-prompt-hooks session)
      (tset M.active-by-source source-buf session)
      (tset M.active-by-prompt prompt-buf session)
      (apply-prompt-lines session)
      (vim.api.nvim_set_current_win prompt-win.window)
      (vim.cmd "startinsert")
      (tset M.instances source-buf curr)
      curr)))

(fn M.sync [meta query]
  (if (not meta)
      (do (vim.notify "No Meta instance" vim.log.levels.WARN) nil)
      (do
        (meta.set-query-lines (if (and query (~= query "")) [query] []))
        (meta.on-update 0)
        (M._store_vars meta)
        meta)))

(fn M.push [meta]
  (if (not meta)
      (vim.notify "No Meta instance" vim.log.levels.WARN)
      (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
        (meta.buf.push-visible-lines lines))))

(fn M.entry_start [query _bang]
  (M.start query "start" nil))

(fn M.entry_resume [query]
  (M.start query "resume" nil))

(fn M.entry_sync [query]
  (local key (vim.api.nvim_get_current_buf))
  (M.sync (. M.instances key) query))

(fn M.entry_push []
  (local key (vim.api.nvim_get_current_buf))
  (M.push (. M.instances key)))

(fn M.entry_cursor_word [resume]
  (local w (vim.fn.expand "<cword>"))
  (if resume
      (M.entry_resume w)
      (M.entry_start w false)))

M
