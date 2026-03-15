-- [nfnl] fnl/metabuffer/router/navigation.fnl
local M = {}
local function can_refresh_source_syntax_3f(session)
  local buf = (session and session.meta and session.meta.buf)
  return (session and session["project-mode"] and buf and buf["show-source-separators"] and (buf["syntax-type"] == "buffer"))
end
local function schedule_source_syntax_refresh_21(deps, session)
  local router = deps.router
  local timing = deps.timing
  local active_by_prompt = router["active-by-prompt"]
  local source_syntax_refresh_debounce_ms = timing["source-syntax-refresh-debounce-ms"]
  if can_refresh_source_syntax_3f(session) then
    session["syntax-refresh-dirty"] = true
    if not session["syntax-refresh-pending"] then
      session["syntax-refresh-pending"] = true
      local function _1_()
        session["syntax-refresh-pending"] = false
        if (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          if session["syntax-refresh-dirty"] then
            session["syntax-refresh-dirty"] = false
            pcall(session.meta.buf["apply-source-syntax-regions"])
          else
          end
          if session["syntax-refresh-dirty"] then
            return schedule_source_syntax_refresh_21(deps, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_1_, (source_syntax_refresh_debounce_ms or 80))
    else
      return nil
    end
  else
    return nil
  end
end
M["move-selection!"] = function(deps, prompt_buf, delta)
  local router = deps.router
  local refresh = deps.refresh
  local windows = deps.windows
  local active_by_prompt = router["active-by-prompt"]
  local update_preview_window = refresh["preview!"]
  local update_info_window = refresh["info!"]
  local context_window = windows.context
  local session = active_by_prompt[prompt_buf]
  if session then
    local runner
    local function _7_()
      local meta = session.meta
      local max = #meta.buf.indices
      if (max > 0) then
        meta.selected_index = math.max(0, math.min((meta.selected_index + delta), (max - 1)))
        do
          local row = (meta.selected_index + 1)
          if vim.api.nvim_win_is_valid(meta.win.window) then
            pcall(vim.api.nvim_win_set_cursor, meta.win.window, {row, 0})
          else
          end
        end
        pcall(meta.refresh_statusline)
        if update_preview_window then
          pcall(update_preview_window, session)
        else
        end
        pcall(update_info_window, session, false)
        if (context_window and context_window["update!"]) then
          return pcall(context_window["update!"], session)
        else
          return nil
        end
      else
        return nil
      end
    end
    runner = _7_
    local mode = vim.api.nvim_get_mode().mode
    if ((type(mode) == "string") and vim.startswith(mode, "i")) then
      return vim.schedule(runner)
    else
      return runner()
    end
  else
    return nil
  end
end
M["scroll-main!"] = function(deps, prompt_buf, action)
  local router = deps.router
  local refresh = deps.refresh
  local windows = deps.windows
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local update_preview_window = refresh["preview!"]
  local update_info_window = refresh["info!"]
  local context_window = windows.context
  local session_view = mods["session-view"]
  local animation_mod = mods.animation
  local session = active_by_prompt[prompt_buf]
  if (session and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    local runner
    local function _14_()
      local function _15_()
        local line_count = vim.api.nvim_buf_line_count(session.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(session.meta.win.window))
        local half_step = math.max(1, math.floor((win_height / 2)))
        local page_step = math.max(1, (win_height - 2))
        local step
        if ((action == "line-down") or (action == "line-up")) then
          step = 1
        elseif ((action == "half-down") or (action == "half-up")) then
          step = half_step
        else
          step = page_step
        end
        local dir
        if ((action == "line-down") or (action == "half-down") or (action == "page-down")) then
          dir = 1
        else
          dir = -1
        end
        local max_top = math.max(1, ((line_count - win_height) + 1))
        local view = vim.fn.winsaveview()
        local old_top = view.topline
        local old_lnum = view.lnum
        local old_col = (view.col or 0)
        local row_off = math.max(0, (old_lnum - old_top))
        local new_top = math.max(1, math.min((old_top + (dir * step)), max_top))
        local new_lnum = math.max(1, math.min((new_top + row_off), line_count))
        local target = {topline = new_top, lnum = new_lnum, col = old_col, leftcol = (view.leftcol or 0)}
        if (animation_mod and animation_mod["enabled?"](session, "scroll") and (animation_mod["duration-ms"](session, "scroll", 140) > 0) and not (step == 1)) then
          return animation_mod["animate-view!"](session, "smooth-scroll", session.meta.win.window, view, target, animation_mod["duration-ms"](session, "scroll", 140))
        else
          return vim.fn.winrestview(target)
        end
      end
      vim.api.nvim_win_call(session.meta.win.window, _15_)
      session_view["sync-selected-from-main-cursor!"](session)
      pcall(session.meta.refresh_statusline)
      if update_preview_window then
        pcall(update_preview_window, session)
      else
      end
      pcall(update_info_window, session, false)
      if (context_window and context_window["update!"]) then
        return pcall(context_window["update!"], session)
      else
        return nil
      end
    end
    runner = _14_
    local mode = vim.api.nvim_get_mode().mode
    if ((type(mode) == "string") and vim.startswith(mode, "i")) then
      return vim.schedule(runner)
    else
      return runner()
    end
  else
    return nil
  end
end
M["maybe-sync-from-main!"] = function(deps, session, force_refresh)
  local router = deps.router
  local refresh = deps.refresh
  local windows = deps.windows
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local update_preview_window = refresh["preview!"]
  local update_info_window = refresh["info!"]
  local context_window = windows.context
  local session_view = mods["session-view"]
  local function _23_(s)
    return schedule_source_syntax_refresh_21(deps, s)
  end
  local function _24_(s)
    if (context_window and context_window["update!"]) then
      return context_window["update!"](s)
    else
      return nil
    end
  end
  return session_view["maybe-sync-from-main!"](session, force_refresh, {["active-by-prompt"] = active_by_prompt, ["schedule-source-syntax-refresh!"] = _23_, ["update-preview-window!"] = update_preview_window, ["update-info-window"] = update_info_window, ["update-context-window!"] = _24_})
end
M["schedule-scroll-sync!"] = function(deps, session)
  local timing = deps.timing
  local mods = deps.mods
  local scroll_sync_debounce_ms = timing["scroll-sync-debounce-ms"]
  local session_view = mods["session-view"]
  local function _26_(s, force_refresh)
    return M["maybe-sync-from-main!"](deps, s, force_refresh)
  end
  return session_view["schedule-scroll-sync!"](session, {["scroll-sync-debounce-ms"] = scroll_sync_debounce_ms, ["maybe-sync-from-main!"] = _26_})
end
return M
