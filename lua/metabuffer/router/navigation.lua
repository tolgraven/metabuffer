-- [nfnl] fnl/metabuffer/router/navigation.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local events = require("metabuffer.events")
local M = {}
local function can_refresh_source_syntax_3f(session)
  local buf = (session and session.meta and session.meta.buf)
  return (session and session["project-mode"] and buf and buf["show-source-separators"] and buf["visible-source-syntax-only"] and (buf["syntax-type"] == "buffer"))
end
local function hide_scroll_cursor_21(session)
  if (session and not session["scroll-cursor-hidden?"]) then
    local ok,current = pcall(vim.api.nvim_get_option_value, "guicursor", {scope = "global"})
    if ok then
      session["scroll-saved-guicursor"] = current
    else
      session["scroll-saved-guicursor"] = vim.o.guicursor
    end
    session["scroll-cursor-hidden?"] = true
    return pcall(vim.api.nvim_set_option_value, "guicursor", "a:ver0", {scope = "global"})
  else
    return nil
  end
end
local function restore_scroll_cursor_21(session)
  if (session and session["scroll-cursor-hidden?"]) then
    local value = (session["scroll-saved-guicursor"] or vim.o.guicursor)
    session["scroll-cursor-hidden?"] = false
    session["scroll-saved-guicursor"] = nil
    return pcall(vim.api.nvim_set_option_value, "guicursor", value, {scope = "global"})
  else
    return nil
  end
end
local function apply_source_syntax_refresh_21(session)
  if can_refresh_source_syntax_3f(session) then
    return pcall(session.meta.buf["apply-source-syntax-regions"])
  else
    return nil
  end
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
      local function _5_()
        session["syntax-refresh-pending"] = false
        if (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          if session["syntax-refresh-dirty"] then
            session["syntax-refresh-dirty"] = false
            apply_source_syntax_refresh_21(session)
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
      return vim.defer_fn(_5_, (source_syntax_refresh_debounce_ms or 80))
    else
      return nil
    end
  else
    return nil
  end
end
M["refresh-source-syntax!"] = function(deps, session, immediate_3f)
  if immediate_3f then
    return apply_source_syntax_refresh_21(session)
  else
    return schedule_source_syntax_refresh_21(deps, session)
  end
end
local function refresh_windows_21(deps, session, force_refresh)
  local router = deps.router
  local timing = (deps.timing or {})
  local active_by_prompt = router["active-by-prompt"]
  local selection_refresh_debounce_ms = (timing["selection-refresh-debounce-ms"] or 12)
  if session then
    session["selection-refresh-force?"] = (force_refresh or session["selection-refresh-force?"])
    session["selection-refresh-token"] = (1 + (session["selection-refresh-token"] or 0))
    if not session["selection-refresh-pending"] then
      session["selection-refresh-pending"] = true
      local function _12_()
        session["selection-refresh-pending"] = false
        if (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local token = session["selection-refresh-token"]
          local force_refresh_3f = clj.boolean(session["selection-refresh-force?"])
          session["selection-refresh-force?"] = false
          if (token == session["selection-refresh-token"]) then
            events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["force-refresh?"] = force_refresh_3f, ["refresh-lines"] = true})
          else
          end
          restore_scroll_cursor_21(session)
          if (token ~= session["selection-refresh-token"]) then
            return refresh_windows_21(deps, session, false)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_12_, selection_refresh_debounce_ms)
    else
      return nil
    end
  else
    return nil
  end
end
local function set_selected_index_21(session, row)
  local meta = session.meta
  local max = #meta.buf.indices
  if (max <= 0) then
    meta.selected_index = 0
    return nil
  else
    local target_row = math.max(1, math.min(row, max))
    local next_index = (target_row - 1)
    meta.selected_index = next_index
    return nil
  end
end
local function sync_selection_state_21(deps, session, row)
  set_selected_index_21(session, row)
  return refresh_windows_21(deps, session, false)
end
local function sync_selection_to_row_21(deps, session, row)
  local meta = session.meta
  local max = #meta.buf.indices
  sync_selection_state_21(deps, session, row)
  if (max > 0) then
    local target_row = math.max(1, math.min(row, max))
    if vim.api.nvim_win_is_valid(meta.win.window) then
      local cursor = vim.api.nvim_win_get_cursor(meta.win.window)
      local col = (cursor[2] or 0)
      if ((cursor[1] ~= target_row) or (col ~= 0)) then
        return pcall(vim.api.nvim_win_set_cursor, meta.win.window, {target_row, 0})
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
local function effective_scroll_target(win, restore_view, target)
  local function _22_()
    local original = vim.deepcopy(restore_view)
    pcall(vim.fn.winrestview, target)
    local effective = vim.fn.winsaveview()
    pcall(vim.fn.winrestview, original)
    return effective
  end
  return vim.api.nvim_win_call(win, _22_)
end
local function scroll_command_text(action)
  if (action == "line-down") then
    return "\5"
  else
    if (action == "line-up") then
      return "\25"
    else
      if (action == "half-down") then
        return "\4"
      else
        if (action == "half-up") then
          return "\21"
        else
          if (action == "page-down") then
            return "\6"
          else
            return "\2"
          end
        end
      end
    end
  end
end
M["move-selection!"] = function(deps, prompt_buf, delta)
  local active_by_prompt = deps.router["active-by-prompt"]
  local session = active_by_prompt[prompt_buf]
  if session then
    local runner
    local function _28_()
      hide_scroll_cursor_21(session)
      local meta = session.meta
      local max = #meta.buf.indices
      if (max > 0) then
        meta.selected_index = math.max(0, math.min((meta.selected_index + delta), (max - 1)))
        local row = (meta.selected_index + 1)
        if vim.api.nvim_win_is_valid(meta.win.window) then
          pcall(vim.api.nvim_win_set_cursor, meta.win.window, {row, 0})
        else
        end
      else
      end
      return refresh_windows_21(deps, session, false)
    end
    runner = _28_
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
  local active_by_prompt = deps.router["active-by-prompt"]
  local animation_mod = deps.mods.animation
  local session = active_by_prompt[prompt_buf]
  if (session and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    local runner
    local function _33_()
      hide_scroll_cursor_21(session)
      local return_win = vim.api.nvim_get_current_win()
      local return_mode = vim.api.nvim_get_mode().mode
      local result
      local function _34_()
        local line_count = vim.api.nvim_buf_line_count(session.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(session.meta.win.window))
        local half_step = math.max(1, math.floor((win_height / 2)))
        local page_step = math.max(1, (win_height - 2))
        local step
        if ((action == "line-down") or (action == "line-up")) then
          step = 1
        else
          if ((action == "half-down") or (action == "half-up")) then
            step = half_step
          else
            step = page_step
          end
        end
        local dir
        if ((action == "line-down") or (action == "half-down") or (action == "page-down")) then
          dir = 1
        else
          dir = -1
        end
        local max_top = math.max(1, ((line_count - win_height) + 1))
        local view = vim.fn.winsaveview()
        local logical_view = (session["scroll-command-view"] or view)
        local old_top = logical_view.topline
        local old_lnum = logical_view.lnum
        local old_col = (logical_view.col or 0)
        local new_top0 = math.max(1, math.min((old_top + (dir * step)), max_top))
        local new_lnum0 = math.max(1, math.min((old_lnum + (dir * step)), line_count))
        local new_lnum
        if ((dir == -1) and ((old_lnum - 1) < (old_lnum - new_lnum0))) then
          new_lnum = 1
        elseif ((dir == 1) and ((line_count - old_lnum) < (new_lnum0 - old_lnum))) then
          new_lnum = line_count
        else
          new_lnum = new_lnum0
        end
        local new_top
        if (new_lnum == 1) then
          new_top = 1
        elseif (new_lnum == line_count) then
          new_top = max_top
        else
          new_top = new_top0
        end
        local target0 = {topline = new_top, lnum = new_lnum, col = old_col, leftcol = (logical_view.leftcol or 0)}
        local target = effective_scroll_target(session.meta.win.window, view, target0)
        local animate_3f = (animation_mod and animation_mod["enabled?"](session, "scroll") and (animation_mod["duration-ms"](session, "scroll", 140) > 0) and not (step == 1))
        local mini_scroll_3f = (animate_3f and (animation_mod["animation-backend"](session, "scroll") == "mini") and animation_mod["supports-backend?"]("mini"))
        local finish_21
        local function _40_()
          if (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            session["scroll-animating?"] = false
            session["scroll-command-view"] = nil
            M["maybe-sync-from-main!"](deps, session, true)
            return restore_scroll_cursor_21(session)
          else
            return nil
          end
        end
        finish_21 = _40_
        session["scroll-command-view"] = target
        if mini_scroll_3f then
          session["scroll-animating?"] = true
          local function _42_()
            return vim.cmd(("normal! " .. scroll_command_text(action)))
          end
          animation_mod["animate-scroll-action-mini!"](session, session.meta.win.window, animation_mod["duration-ms"](session, "scroll", 140), _42_, {["return-win"] = return_win, ["return-mode"] = return_mode, ["done!"] = finish_21})
          return {row = (target.lnum or new_lnum), animated = true}
        else
          if animate_3f then
            session["scroll-animating?"] = true
            animation_mod["animate-scroll-view!"](session, "smooth-scroll", session.meta.win.window, view, target, animation_mod["duration-ms"](session, "scroll", 140), {["return-win"] = return_win, ["return-mode"] = return_mode, ["done!"] = finish_21})
            return {row = (target.lnum or new_lnum), animated = true}
          else
            vim.fn.winrestview(target)
            session["scroll-animating?"] = false
            session["scroll-command-view"] = nil
            return {row = (target.lnum or new_lnum), animated = false}
          end
        end
      end
      result = vim.api.nvim_win_call(session.meta.win.window, _34_)
      local target_row = result.row
      local animated_3f = result.animated
      if animated_3f then
        set_selected_index_21(session, target_row)
        return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
      else
        return sync_selection_to_row_21(deps, session, target_row)
      end
    end
    runner = _33_
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
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local session_view = mods["session-view"]
  local function _48_(s)
    return schedule_source_syntax_refresh_21(deps, s)
  end
  return session_view["maybe-sync-from-main!"](session, force_refresh, {["active-by-prompt"] = active_by_prompt, ["schedule-source-syntax-refresh!"] = _48_})
end
M["schedule-scroll-sync!"] = function(deps, session)
  local timing = deps.timing
  local mods = deps.mods
  local scroll_sync_debounce_ms = timing["scroll-sync-debounce-ms"]
  local session_view = mods["session-view"]
  local function _49_(s, force_refresh)
    return M["maybe-sync-from-main!"](deps, s, force_refresh)
  end
  return session_view["schedule-scroll-sync!"](session, {["scroll-sync-debounce-ms"] = scroll_sync_debounce_ms, ["maybe-sync-from-main!"] = _49_})
end
return M
