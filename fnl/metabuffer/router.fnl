(local prompt_mod (require :metabuffer.prompt.prompt))
(local meta_mod (require :metabuffer.meta))
(local base_buffer (require :metabuffer.buffer.base))
(local state (require :metabuffer.core.state))

(local M {})
(set M.instances {})

(fn setup_state [query mode]
  (if (and (= mode "resume") vim.b._meta_context)
      (let [ctx (vim.deepcopy vim.b._meta_context)]
        (when (and query (~= query ""))
          (tset ctx :text query)
          (tset ctx :caret-locus (# query)))
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

(fn M.start [query mode meta]
  (let [condition (setup_state query mode)
        curr (or meta (meta_mod.new vim condition))
        _ (curr.on_init)
        _ (curr.on_update prompt_mod.STATUS_PROGRESS)
        _ (curr.on_redraw)
        status prompt_mod.STATUS_PAUSE]

    (when (or (= status prompt_mod.STATUS_ACCEPT)
              (= status prompt_mod.STATUS_CANCEL))
      (pcall vim.cmd (.. "sign unplace * buffer=" (vim.api.nvim_get_current_buf)))
      (base_buffer.switch-buf curr.buf.model))

    (when (= status prompt_mod.STATUS_ACCEPT)
      (curr.win.set-row (curr.selected_line) true)
      (vim.cmd "normal! zv")
      (let [vq (curr.vim_query)]
        (when (~= vq "")
          (vim.fn.setreg "/" vq))))

    (when (= status prompt_mod.STATUS_PAUSE)
      (base_buffer.switch-buf curr.buf.model))

    (M._wrapup curr)
    curr))

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
