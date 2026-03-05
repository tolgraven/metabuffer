(import-macros {: when-let : if-let : when-some : if-some} :io.gitlab.andreyorst.cljlib.core)
(local state (require :metabuffer.core.state))

(local M {})

(fn M.wipe-temp-buffers
  [meta]
  "Delete temporary Meta buffers while preserving the original model buffer."
  (when meta
    (let [main-buf meta.buf.buffer
          model-buf meta.buf.model
          index-buf (and meta.buf.indexbuf meta.buf.indexbuf.buffer)]
      (when (and index-buf (not (= index-buf model-buf)) (vim.api.nvim_buf_is_valid index-buf))
        (pcall vim.api.nvim_buf_delete index-buf {:force true}))
      (when (and main-buf (not (= main-buf model-buf)) (vim.api.nvim_buf_is_valid main-buf))
        (pcall vim.api.nvim_buf_delete main-buf {:force true})))))

(fn M.setup-state
  [query mode source-view]
  "Build initial prompt/query state for start/resume flows."
  (if (and (= mode "resume") vim.b._meta_context)
      (let [ctx (vim.deepcopy vim.b._meta_context)]
        (when (and query (~= query ""))
          (set ctx.text query)
          (set ctx.caret-locus (# query)))
        (when source-view
          (set ctx.source-view source-view))
        ctx)
      (let [ctx (state.default-condition (or query ""))]
        (when source-view
          (set ctx.source-view source-view))
        ctx)))

(fn M.restore-meta-view!
  [meta source-view]
  "Restore cursor and viewport in the results window from stored source view."
  (when (and meta (vim.api.nvim_win_is_valid meta.win.window))
    (let [line-count (vim.api.nvim_buf_line_count meta.buf.buffer)
          line (math.max 1 (math.min (meta.selected_line) line-count))
          src-view (or source-view {})
          src-lnum (or (. src-view :lnum) line)
          src-topline (or (. src-view :topline) src-lnum)
          offset (math.max 0 (- src-lnum src-topline))
          topline (math.max 1 (math.min (- line offset) line-count))]
      (vim.api.nvim_win_call meta.win.window
        (fn []
          (local view (vim.fn.winsaveview))
          (set (. view :lnum) line)
          (set (. view :topline) topline)
          (when (~= (. src-view :leftcol) nil)
            (set (. view :leftcol) (. src-view :leftcol)))
          (when (~= (. src-view :col) nil)
            (set (. view :col) (. src-view :col)))
          (vim.fn.winrestview view))))))

M
