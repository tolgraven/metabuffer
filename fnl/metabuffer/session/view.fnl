(import-macros {: when-let : if-let : when-some : if-some : when-not} :io.gitlab.andreyorst.cljlib.core)
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
          (let [view (vim.fn.winsaveview)]
            (set (. view :lnum) line)
            (set (. view :topline) topline)
            (when (~= (. src-view :leftcol) nil)
              (set (. view :leftcol) (. src-view :leftcol)))
            (when (~= (. src-view :col) nil)
              (set (. view :col) (. src-view :col)))
            (vim.fn.winrestview view)))))))

(fn M.sync-selected-from-main-cursor!
  [session]
  "Sync selected index from current cursor row in the main results window."
  (let [meta session.meta
        max (# meta.buf.indices)]
    (if (<= max 0)
        (set meta.selected_index 0)
        (when (vim.api.nvim_win_is_valid meta.win.window)
          (let [c (vim.api.nvim_win_get_cursor meta.win.window)
                row (. c 1)
                clamped (math.max 1 (math.min row max))]
            (when (~= row clamped)
              (pcall vim.api.nvim_win_set_cursor meta.win.window [clamped (. c 2)]))
            (set meta.selected_index (- clamped 1)))))))

(fn M.maybe-sync-from-main!
  [session force-refresh opts]
  "Sync selection and UI state from main window cursor when session is active."
  (let [{: active-by-prompt
         : schedule-source-syntax-refresh!
         : update-info-window
         : update-context-window!}
        (or opts {})]
    (when (and session
               (not session.startup-initializing)
               (vim.api.nvim_win_is_valid session.meta.win.window)
               (vim.api.nvim_buf_is_valid session.prompt-buf)
               (= (. active-by-prompt session.prompt-buf) session))
      (let [before session.meta.selected_index]
        (M.sync-selected-from-main-cursor! session)
        (when force-refresh
          (schedule-source-syntax-refresh! session))
        (when (or force-refresh (~= before session.meta.selected_index))
          (pcall session.meta.refresh_statusline)
          (pcall update-info-window session false)
          (when update-context-window!
            (pcall update-context-window! session)))))))

(fn M.schedule-scroll-sync!
  [session opts]
  "Coalesce high-frequency scroll updates into one trailing sync run."
  (let [{: maybe-sync-from-main!
         : scroll-sync-debounce-ms}
        (or opts {})]
    (when (and session (not session.scroll-sync-pending))
      (set session.scroll-sync-pending true)
      (vim.defer_fn
        (fn []
          (set session.scroll-sync-pending false)
          (maybe-sync-from-main! session true))
        scroll-sync-debounce-ms))))

M
