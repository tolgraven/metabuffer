-- [nfnl] fnl/metabuffer/session/view.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local state = require("metabuffer.core.state")
local util = require("metabuffer.util")
local M = {}
M["wipe-temp-buffers"] = function(meta)
  if meta then
    local main_buf = meta.buf.buffer
    local model_buf = meta.buf.model
    local index_buf = (meta.buf.indexbuf and meta.buf.indexbuf.buffer)
    if (index_buf and not (index_buf == model_buf) and vim.api.nvim_buf_is_valid(index_buf)) then
      util["restore-heavy-buffer-features!"](index_buf)
      pcall(vim.api.nvim_buf_delete, index_buf, {force = true})
    else
    end
    if (main_buf and not (main_buf == model_buf) and vim.api.nvim_buf_is_valid(main_buf)) then
      util["restore-heavy-buffer-features!"](main_buf)
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
M["restore-meta-view!"] = function(meta, source_view, session, update_info_window)
  if (meta and vim.api.nvim_win_is_valid(meta.win.window)) then
    local line_count = vim.api.nvim_buf_line_count(meta.buf.buffer)
    local line = math.max(1, math.min(meta.selected_line(), line_count))
    local win_height = math.max(1, vim.api.nvim_win_get_height(meta.win.window))
    local current_view
    local function _8_()
      return vim.fn.winsaveview()
    end
    current_view = vim.api.nvim_win_call(meta.win.window, _8_)
    local src_view = (source_view or {})
    local use_src_scroll_3f = ((src_view.topline ~= nil) and (not (session and session["project-mode"]) or session["startup-initializing"] or clj.boolean(session["project-mode-starting?"])))
    local base_view
    if use_src_scroll_3f then
      base_view = src_view
    else
      base_view = current_view
    end
    local base_lnum = (base_view.lnum or line)
    local base_topline = (base_view.topline or base_lnum)
    local offset = math.max(0, (base_lnum - base_topline))
    local unclamped_topline = math.max(1, math.min((line - offset), line_count))
    local topline
    if (line_count <= win_height) then
      topline = 1
    else
      topline = math.max(1, math.min(unclamped_topline, math.max(1, ((line_count - win_height) + 1))))
    end
    local function _11_()
      local view = vim.fn.winsaveview()
      view["lnum"] = line
      view["topline"] = topline
      if (base_view.leftcol ~= nil) then
        view["leftcol"] = base_view.leftcol
      else
      end
      if (base_view.col ~= nil) then
        view["col"] = base_view.col
      else
      end
      vim.fn.winrestview(view)
      if (update_info_window and session) then
        local function _14_()
          return pcall(update_info_window, session, true)
        end
        return vim.defer_fn(_14_, 50)
      else
        return nil
      end
    end
    return vim.api.nvim_win_call(meta.win.window, _11_)
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
  local _let_20_ = (opts or {})
  local active_by_prompt = _let_20_["active-by-prompt"]
  local schedule_source_syntax_refresh_21 = _let_20_["schedule-source-syntax-refresh!"]
  local update_info_window = _let_20_["update-info-window"]
  local update_preview_window_21 = _let_20_["update-preview-window!"]
  local update_context_window_21 = _let_20_["update-context-window!"]
  if (session and (not session["startup-initializing"] or session["project-mode"]) and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session)) then
    local before = session.meta.selected_index
    M["sync-selected-from-main-cursor!"](session)
    if force_refresh then
      schedule_source_syntax_refresh_21(session)
    else
    end
    if (force_refresh or (before ~= session.meta.selected_index)) then
      pcall(session.meta.refresh_statusline)
      if update_preview_window_21 then
        pcall(update_preview_window_21, session)
      else
      end
      pcall(update_info_window, session, false)
      if update_context_window_21 then
        return pcall(update_context_window_21, session)
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
M["schedule-scroll-sync!"] = function(session, opts)
  local _let_26_ = (opts or {})
  local maybe_sync_from_main_21 = _let_26_["maybe-sync-from-main!"]
  local scroll_sync_debounce_ms = _let_26_["scroll-sync-debounce-ms"]
  if (session and not session["scroll-sync-pending"] and not session["scroll-animating?"] and not session["scroll-command-view"]) then
    session["scroll-sync-pending"] = true
    local function _27_()
      session["scroll-sync-pending"] = false
      if (not session["scroll-animating?"] and not session["scroll-command-view"]) then
        return maybe_sync_from_main_21(session, true)
      else
        return nil
      end
    end
    return vim.defer_fn(_27_, scroll_sync_debounce_ms)
  else
    return nil
  end
end
return M
