-- [nfnl] fnl/metabuffer/router/navigation.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local events = require("metabuffer.events")
local util = require("metabuffer.util")
local M = {}
local function session_active_for_prompt_3f(active_by_prompt, session)
  return (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session))
end
local function results_window_valid_3f(session)
  return (session and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window))
end
local function current_mode_insert_3f()
  local mode = vim.api.nvim_get_mode().mode
  return ((type(mode) == "string") and vim.startswith(mode, "i"))
end
local function run_mode_safe_21(runner)
  if current_mode_insert_3f() then
    return vim.schedule(runner)
  else
    return runner()
  end
end
local function can_refresh_source_syntax_3f(session, include_full_3f)
  local buf = (session and session.meta and session.meta.buf)
  return (session and session["project-mode"] and buf and buf["show-source-separators"] and (include_full_3f or buf["visible-source-syntax-only"]) and (buf["syntax-type"] == "buffer"))
end
local function hide_scroll_cursor_21(session)
  return util["hide-global-cursor!"](session, "scroll-cursor-hidden?", "scroll-saved-guicursor")
end
local function restore_scroll_cursor_21(session)
  return util["restore-global-cursor!"](session, "scroll-cursor-hidden?", "scroll-saved-guicursor")
end
local function apply_source_syntax_refresh_21(session, include_full_3f)
  if can_refresh_source_syntax_3f(session, include_full_3f) then
    return pcall(session.meta.buf["apply-source-syntax-regions"])
  else
    return nil
  end
end
local function mark_source_syntax_dirty_21(session)
  session["syntax-refresh-dirty"] = true
  return nil
end
local function apply_dirty_source_syntax_refresh_21(session)
  if session["syntax-refresh-dirty"] then
    session["syntax-refresh-dirty"] = false
    return apply_source_syntax_refresh_21(session, false)
  else
    return nil
  end
end
local function rerun_source_syntax_refresh_3f(session)
  return session["syntax-refresh-dirty"]
end
local function source_syntax_refresh_delay_ms(deps)
  return (deps.timing["source-syntax-refresh-debounce-ms"] or 80)
end
local function schedule_source_syntax_refresh_21(deps, session)
  local active_by_prompt = deps.router["active-by-prompt"]
  if can_refresh_source_syntax_3f(session, false) then
    mark_source_syntax_dirty_21(session)
    if not session["syntax-refresh-pending"] then
      session["syntax-refresh-pending"] = true
      local function _4_()
        session["syntax-refresh-pending"] = false
        if session_active_for_prompt_3f(active_by_prompt, session) then
          apply_dirty_source_syntax_refresh_21(session)
          if rerun_source_syntax_refresh_3f(session) then
            return schedule_source_syntax_refresh_21(deps, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_4_, source_syntax_refresh_delay_ms(deps))
    else
      return nil
    end
  else
    return nil
  end
end
M["refresh-source-syntax!"] = function(deps, session, immediate_3f)
  if immediate_3f then
    return apply_source_syntax_refresh_21(session, true)
  else
    return schedule_source_syntax_refresh_21(deps, session)
  end
end
local function mark_selection_refresh_pending_21(session, force_refresh)
  session["selection-refresh-force?"] = (force_refresh or session["selection-refresh-force?"])
  session["selection-refresh-token"] = (1 + (session["selection-refresh-token"] or 0))
  return nil
end
local function selection_refresh_delay_ms(deps)
  return ((deps.timing or {})["selection-refresh-debounce-ms"] or 12)
end
local function emit_selection_change_21(session, force_refresh_3f)
  return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["force-refresh?"] = force_refresh_3f, ["refresh-lines"] = true})
end
local function refresh_windows_21(deps, session, force_refresh)
  local active_by_prompt = deps.router["active-by-prompt"]
  if session then
    mark_selection_refresh_pending_21(session, force_refresh)
    if not session["selection-refresh-pending"] then
      session["selection-refresh-pending"] = true
      local function _10_()
        session["selection-refresh-pending"] = false
        if session_active_for_prompt_3f(active_by_prompt, session) then
          local token = session["selection-refresh-token"]
          local force_refresh_3f = clj.boolean(session["selection-refresh-force?"])
          session["selection-refresh-force?"] = false
          if (token == session["selection-refresh-token"]) then
            emit_selection_change_21(session, force_refresh_3f)
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
      return vim.defer_fn(_10_, selection_refresh_delay_ms(deps))
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
local function sync_results_cursor_21(session, row)
  local meta = session.meta
  local max = #meta.buf.indices
  if (max > 0) then
    local target_row = math.max(1, math.min(row, max))
    if results_window_valid_3f(session) then
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
local function sync_selection_state_21(deps, session, row)
  set_selected_index_21(session, row)
  return refresh_windows_21(deps, session, false)
end
local function sync_selection_to_row_21(deps, session, row)
  sync_selection_state_21(deps, session, row)
  return sync_results_cursor_21(session, row)
end
local function effective_scroll_target(win, restore_view, target)
  local function _20_()
    local original = vim.deepcopy(restore_view)
    pcall(vim.fn.winrestview, target)
    local effective = vim.fn.winsaveview()
    pcall(vim.fn.winrestview, original)
    return effective
  end
  return vim.api.nvim_win_call(win, _20_)
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
local function target_step(action, win_height)
  local half_step = math.max(1, math.floor((win_height / 2)))
  local page_step = math.max(1, (win_height - 2))
  if ((action == "line-down") or (action == "line-up")) then
    return 1
  else
    if ((action == "half-down") or (action == "half-up")) then
      return half_step
    else
      return page_step
    end
  end
end
local function target_direction(action)
  if ((action == "line-down") or (action == "half-down") or (action == "page-down")) then
    return 1
  else
    return -1
  end
end
local function clamp_scroll_lnum(dir, line_count, old_lnum, new_lnum0)
  if ((dir == -1) and ((old_lnum - 1) < (old_lnum - new_lnum0))) then
    return 1
  elseif ((dir == 1) and ((line_count - old_lnum) < (new_lnum0 - old_lnum))) then
    return line_count
  else
    return new_lnum0
  end
end
local function scroll_target_view(session, action)
  local line_count = vim.api.nvim_buf_line_count(session.meta.buf.buffer)
  local win_height = math.max(1, vim.api.nvim_win_get_height(session.meta.win.window))
  local step = target_step(action, win_height)
  local dir = target_direction(action)
  local max_top = math.max(1, ((line_count - win_height) + 1))
  local view = vim.fn.winsaveview()
  local logical_view = (session["scroll-command-view"] or view)
  local old_top = logical_view.topline
  local old_lnum = logical_view.lnum
  local old_col = (logical_view.col or 0)
  local new_top0 = math.max(1, math.min((old_top + (dir * step)), max_top))
  local new_lnum0 = math.max(1, math.min((old_lnum + (dir * step)), line_count))
  local new_lnum = clamp_scroll_lnum(dir, line_count, old_lnum, new_lnum0)
  local new_top
  if (new_lnum == 1) then
    new_top = 1
  elseif (new_lnum == line_count) then
    new_top = max_top
  else
    new_top = new_top0
  end
  local target0 = {topline = new_top, lnum = new_lnum, col = old_col, leftcol = (logical_view.leftcol or 0)}
  return {["line-count"] = line_count, step = step, view = view, target = effective_scroll_target(session.meta.win.window, view, target0), row = new_lnum}
end
local function finish_scroll_21(deps, active_by_prompt, session)
  if session_active_for_prompt_3f(active_by_prompt, session) then
    session["scroll-animating?"] = false
    session["scroll-command-view"] = nil
    M["maybe-sync-from-main!"](deps, session, true)
    return restore_scroll_cursor_21(session)
  else
    return nil
  end
end
local function scroll_animation_mode(animation_mod, session, step)
  local animate_3f = (animation_mod and animation_mod["enabled?"](session, "scroll") and (animation_mod["duration-ms"](session, "scroll", 140) > 0) and not (step == 1))
  local mini_scroll_3f = (animate_3f and (animation_mod["animation-backend"](session, "scroll") == "mini") and animation_mod["supports-backend?"]("mini"))
  return {["animate?"] = animate_3f, ["mini-scroll?"] = mini_scroll_3f}
end
local function execute_scroll_21(deps, animation_mod, active_by_prompt, session, action)
  local return_win = vim.api.nvim_get_current_win()
  local return_mode = vim.api.nvim_get_mode().mode
  local function _32_()
    local _let_33_ = scroll_target_view(session, action)
    local step = _let_33_.step
    local view = _let_33_.view
    local target = _let_33_.target
    local row = _let_33_.row
    local _let_34_ = scroll_animation_mode(animation_mod, session, step)
    local animate_3f = _let_34_["animate?"]
    local mini_scroll_3f = _let_34_["mini-scroll?"]
    local done_21
    local function _35_()
      return finish_scroll_21(deps, active_by_prompt, session)
    end
    done_21 = _35_
    session["scroll-command-view"] = target
    if mini_scroll_3f then
      session["scroll-animating?"] = true
      local function _36_()
        return vim.cmd(("normal! " .. scroll_command_text(action)))
      end
      animation_mod["animate-scroll-action-mini!"](session, session.meta.win.window, animation_mod["duration-ms"](session, "scroll", 140), _36_, {["return-win"] = return_win, ["return-mode"] = return_mode, ["done!"] = done_21})
      return {row = (target.lnum or row), animated = true}
    else
      if animate_3f then
        session["scroll-animating?"] = true
        animation_mod["animate-scroll-view!"](session, "smooth-scroll", session.meta.win.window, view, target, animation_mod["duration-ms"](session, "scroll", 140), {["return-win"] = return_win, ["return-mode"] = return_mode, ["done!"] = done_21})
        return {row = (target.lnum or row), animated = true}
      else
        vim.fn.winrestview(target)
        session["scroll-animating?"] = false
        session["scroll-command-view"] = nil
        return {row = (target.lnum or row), animated = false}
      end
    end
  end
  return vim.api.nvim_win_call(session.meta.win.window, _32_)
end
local function apply_scroll_selection_21(deps, session, result)
  local target_row = result.row
  local animated_3f = result.animated
  if animated_3f then
    set_selected_index_21(session, target_row)
    return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
  else
    return sync_selection_to_row_21(deps, session, target_row)
  end
end
local function move_selection_runner(deps, session, delta)
  local function _40_()
    hide_scroll_cursor_21(session)
    local meta = session.meta
    local max = #meta.buf.indices
    if (max > 0) then
      meta.selected_index = math.max(0, math.min((meta.selected_index + delta), (max - 1)))
      local row = (meta.selected_index + 1)
      if results_window_valid_3f(session) then
        pcall(vim.api.nvim_win_set_cursor, meta.win.window, {row, 0})
      else
      end
    else
    end
    return refresh_windows_21(deps, session, false)
  end
  return _40_
end
local function scroll_main_runner(deps, active_by_prompt, animation_mod, session, action)
  local function _43_()
    hide_scroll_cursor_21(session)
    return apply_scroll_selection_21(deps, session, execute_scroll_21(deps, animation_mod, active_by_prompt, session, action))
  end
  return _43_
end
M["move-selection!"] = function(deps, prompt_buf, delta)
  local active_by_prompt = deps.router["active-by-prompt"]
  local session = active_by_prompt[prompt_buf]
  if session then
    return run_mode_safe_21(move_selection_runner(deps, session, delta))
  else
    return nil
  end
end
M["scroll-main!"] = function(deps, prompt_buf, action)
  local active_by_prompt = deps.router["active-by-prompt"]
  local animation_mod = deps.mods.animation
  local session = active_by_prompt[prompt_buf]
  if results_window_valid_3f(session) then
    return run_mode_safe_21(scroll_main_runner(deps, active_by_prompt, animation_mod, session, action))
  else
    return nil
  end
end
M["maybe-sync-from-main!"] = function(deps, session, force_refresh)
  local router = deps.router
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local session_view = mods["session-view"]
  local function _46_(s)
    return schedule_source_syntax_refresh_21(deps, s)
  end
  return session_view["maybe-sync-from-main!"](session, force_refresh, {["active-by-prompt"] = active_by_prompt, ["schedule-source-syntax-refresh!"] = _46_})
end
M["schedule-scroll-sync!"] = function(deps, session)
  local timing = deps.timing
  local mods = deps.mods
  local scroll_sync_debounce_ms = timing["scroll-sync-debounce-ms"]
  local session_view = mods["session-view"]
  local function _47_(s, force_refresh)
    return M["maybe-sync-from-main!"](deps, s, force_refresh)
  end
  return session_view["schedule-scroll-sync!"](session, {["scroll-sync-debounce-ms"] = scroll_sync_debounce_ms, ["maybe-sync-from-main!"] = _47_})
end
return M
