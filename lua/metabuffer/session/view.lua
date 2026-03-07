-- [nfnl] fnl/metabuffer/session/view.fnl
local state = require("metabuffer.core.state")
local M = {}
M["wipe-temp-buffers"] = function(meta)
  if meta then
    local main_buf = meta.buf.buffer
    local model_buf = meta.buf.model
    local index_buf = (meta.buf.indexbuf and meta.buf.indexbuf.buffer)
    if (index_buf and not (index_buf == model_buf) and vim.api.nvim_buf_is_valid(index_buf)) then
      pcall(vim.api.nvim_buf_delete, index_buf, {force = true})
    else
    end
    if (main_buf and not (main_buf == model_buf) and vim.api.nvim_buf_is_valid(main_buf)) then
      return pcall(vim.api.nvim_buf_delete, main_buf, {force = true})
    else
      return nil
    end
  else
    return nil
  end
end
M["setup-state"] = function(query, mode, source_view)
  if ((mode == "resume") and vim.b._meta_context) then
    local ctx = vim.deepcopy(vim.b._meta_context)
    if (query and (query ~= "")) then
      ctx.text = query
      ctx["caret-locus"] = #query
    else
    end
    if source_view then
      ctx["source-view"] = source_view
    else
    end
    return ctx
  else
    local ctx = state["default-condition"]((query or ""))
    if source_view then
      ctx["source-view"] = source_view
    else
    end
    return ctx
  end
end
M["restore-meta-view!"] = function(meta, source_view)
  if (meta and vim.api.nvim_win_is_valid(meta.win.window)) then
    local line_count = vim.api.nvim_buf_line_count(meta.buf.buffer)
    local line = math.max(1, math.min(meta.selected_line(), line_count))
    local src_view = (source_view or {})
    local src_lnum = (src_view.lnum or line)
    local src_topline = (src_view.topline or src_lnum)
    local offset = math.max(0, (src_lnum - src_topline))
    local topline = math.max(1, math.min((line - offset), line_count))
    local function _8_()
      local view = vim.fn.winsaveview()
      view["lnum"] = line
      view["topline"] = topline
      if (src_view.leftcol ~= nil) then
        view["leftcol"] = src_view.leftcol
      else
      end
      if (src_view.col ~= nil) then
        view["col"] = src_view.col
      else
      end
      return vim.fn.winrestview(view)
    end
    return vim.api.nvim_win_call(meta.win.window, _8_)
  else
    return nil
  end
end
M["sync-selected-from-main-cursor!"] = function(session)
  local meta = session.meta
  local max = #meta.buf.indices
  if (max <= 0) then
    meta.selected_index = 0
    return nil
  else
    if vim.api.nvim_win_is_valid(meta.win.window) then
      local c = vim.api.nvim_win_get_cursor(meta.win.window)
      local row = c[1]
      local clamped = math.max(1, math.min(row, max))
      if (row ~= clamped) then
        pcall(vim.api.nvim_win_set_cursor, meta.win.window, {clamped, c[2]})
      else
      end
      meta.selected_index = (clamped - 1)
      return nil
    else
      return nil
    end
  end
end
M["maybe-sync-from-main!"] = function(session, force_refresh, opts)
  local _let_15_ = (opts or {})
  local active_by_prompt = _let_15_["active-by-prompt"]
  local schedule_source_syntax_refresh_21 = _let_15_["schedule-source-syntax-refresh!"]
  local update_info_window = _let_15_["update-info-window"]
  if (session and not session["startup-initializing"] and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (vim.api.nvim_get_current_win() == session.meta.win.window) and (active_by_prompt[session["prompt-buf"]] == session)) then
    local before = session.meta.selected_index
    M["sync-selected-from-main-cursor!"](session)
    if force_refresh then
      schedule_source_syntax_refresh_21(session)
    else
    end
    if (force_refresh or (before ~= session.meta.selected_index)) then
      pcall(session.meta.refresh_statusline)
      return pcall(update_info_window, session, false)
    else
      return nil
    end
  else
    return nil
  end
end
M["schedule-scroll-sync!"] = function(session, opts)
  local _let_19_ = (opts or {})
  local maybe_sync_from_main_21 = _let_19_["maybe-sync-from-main!"]
  local scroll_sync_debounce_ms = _let_19_["scroll-sync-debounce-ms"]
  if (session and not session["scroll-sync-pending"]) then
    session["scroll-sync-pending"] = true
    local function _20_()
      session["scroll-sync-pending"] = false
      return maybe_sync_from_main_21(session, true)
    end
    return vim.defer_fn(_20_, (scroll_sync_debounce_ms or 20))
  else
    return nil
  end
end
return M
