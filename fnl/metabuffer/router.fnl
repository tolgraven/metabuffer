(local prompt_mod (require :metabuffer.prompt.prompt))
(local meta_mod (require :metabuffer.meta))
(local base_buffer (require :metabuffer.buffer.base))
(local state (require :metabuffer.core.state))

(local M {})
(set M.instances {})

(fn wipe-temp-buffers [meta]
  (when meta
    (let [main-buf meta.buf.buffer
          model-buf meta.buf.model
          index-buf (and meta.buf.indexbuf meta.buf.indexbuf.buffer)]
      (when (and index-buf (not (= index-buf model-buf)) (vim.api.nvim_buf_is_valid index-buf))
        (pcall vim.api.nvim_buf_delete index-buf {:force true}))
      (when (and main-buf (not (= main-buf model-buf)) (vim.api.nvim_buf_is_valid main-buf))
        (pcall vim.api.nvim_buf_delete main-buf {:force true})))))

(fn setup_state [query mode]
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

(fn M.start [query mode _meta]
  (let [origin-win (vim.api.nvim_get_current_win)
        origin-buf (vim.api.nvim_get_current_buf)
        condition (setup_state query mode)
        curr (meta_mod.new vim condition)]
    (base_buffer.switch-buf curr.buf.buffer)
    (var status nil)
    (var err nil)
    (let [ok (xpcall
               (fn []
                 (set status (curr.start))
                 true)
               (fn [e]
                 (set err e)
                 e))
          resolved-status (if ok status prompt_mod.STATUS_INTERRUPT)]
      (let [matcher (curr.matcher)]
        (when matcher
          (pcall matcher.remove-highlight matcher)))

      (pcall vim.cmd (.. "sign unplace * buffer=" (vim.api.nvim_get_current_buf)))

      (when (and (vim.api.nvim_win_is_valid origin-win)
                 (vim.api.nvim_buf_is_valid origin-buf))
        (pcall vim.api.nvim_win_set_buf origin-win origin-buf)
        (pcall vim.api.nvim_set_current_win origin-win))

      (when (or (= resolved-status prompt_mod.STATUS_ACCEPT)
                (= resolved-status prompt_mod.STATUS_CANCEL)
                (not ok))
        (wipe-temp-buffers curr))

      (when (= resolved-status prompt_mod.STATUS_ACCEPT)
        (base_buffer.switch-buf curr.buf.model)
        (let [row (curr.selected_line)]
          (curr.win.set-row row true)
          (let [vq (curr.vim_query)]
            (when (~= vq "")
              ;; Position cursor at first hit on selected line.
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
            (set vim.o.hlsearch true))))

      (when (or (= resolved-status prompt_mod.STATUS_CANCEL)
                (= resolved-status prompt_mod.STATUS_INTERRUPT))
        (vim.cmd "silent! nohlsearch")
        (base_buffer.switch-buf curr.buf.model))

      (when (= resolved-status prompt_mod.STATUS_PAUSE)
        (base_buffer.switch-buf curr.buf.model))

      (M._wrapup curr)
      (if ok
          curr
          (error err)))))

(fn M.sync [meta query]
  (if (not meta)
      (do (vim.notify "No Meta instance" vim.log.levels.WARN) nil)
      (do
        (set meta.text (or query ""))
        (meta.on_update prompt_mod.STATUS_PROGRESS)
        (M._store_vars meta)
        meta)))

(fn M.push [meta]
  (if (not meta)
      (vim.notify "No Meta instance" vim.log.levels.WARN)
      (let [lines (vim.api.nvim_buf_get_lines meta.buf.buffer 0 -1 false)]
        (meta.buf.push-visible-lines lines))))

(fn M.entry_start [query bang]
  (local key (vim.api.nvim_get_current_buf))
  (when (or bang (not (. M.instances key)))
    (tset M.instances key (meta_mod.new vim (state.default-condition ""))))
  (tset M.instances key (M.start query "start" (. M.instances key))))

(fn M.entry_resume [query]
  (local key (vim.api.nvim_get_current_buf))
  (tset M.instances key (M.start query "resume" (. M.instances key))))

(fn M.entry_sync [query]
  (local key (vim.api.nvim_get_current_buf))
  (tset M.instances key (M.sync (. M.instances key) query)))

(fn M.entry_push []
  (local key (vim.api.nvim_get_current_buf))
  (M.push (. M.instances key)))

(fn M.entry_cursor_word [resume]
  (local w (vim.fn.expand "<cword>"))
  (if resume
      (M.entry_resume w)
      (M.entry_start w false)))

M
