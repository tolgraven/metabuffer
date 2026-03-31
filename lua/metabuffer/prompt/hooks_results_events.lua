-- [nfnl] fnl/metabuffer/prompt/hooks_results_events.fnl
local events = require("metabuffer.events")
local M = {}
M.new = function(opts)
  local active_by_prompt = opts["active-by-prompt"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local begin_direct_results_edit_21 = opts["begin-direct-results-edit!"]
  local sign_mod = opts["sign-mod"]
  local function session_active_3f(session)
    return (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session))
  end
  local function emit_query_refresh_21(session, _3fopts)
    local extra = (_3fopts or {})
    local _1_
    if (extra["refresh-lines"] == nil) then
      _1_ = true
    else
      _1_ = extra["refresh-lines"]
    end
    return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = _1_, ["refresh-signs?"] = not not extra["refresh-signs?"]})
  end
  local function handle_results_cursor_21(session)
    return maybe_sync_from_main_21(session)
  end
  local function handle_results_edit_enter_21(session)
    return begin_direct_results_edit_21(session)
  end
  local function handle_results_text_changed_21(router, session)
    if (sign_mod and session.meta and session.meta.buf) then
      local buf = session.meta.buf.buffer
      local internal_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
        internal_3f = (ok and v)
      end
      if not internal_3f then
        begin_direct_results_edit_21(session)
      else
      end
      local function _4_()
        if session_active_3f(session) then
          pcall(router["sync-live-edits"], session["prompt-buf"])
          pcall(maybe_sync_from_main_21, session, true)
          return emit_query_refresh_21(session, {["refresh-signs?"] = true})
        else
          return nil
        end
      end
      return vim.schedule(_4_)
    else
      return nil
    end
  end
  local function handle_selection_focus_21(session)
    return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
  end
  local function handle_scroll_sync_21(session)
    return schedule_scroll_sync_21(session)
  end
  return {["emit-query-refresh!"] = emit_query_refresh_21, ["handle-results-cursor!"] = handle_results_cursor_21, ["handle-results-edit-enter!"] = handle_results_edit_enter_21, ["handle-results-text-changed!"] = handle_results_text_changed_21, ["handle-scroll-sync!"] = handle_scroll_sync_21, ["handle-selection-focus!"] = handle_selection_focus_21, ["session-active?"] = session_active_3f}
end
return M
