-- [nfnl] fnl/metabuffer/prompt/hooks_results.fnl
local M = {}
local events = require("metabuffer.events")
M.new = function(opts)
  local active_by_prompt = opts["active-by-prompt"]
  local sign_mod = opts["sign-mod"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local covered_by_new_window_3f = opts["covered-by-new-window?"]
  local transient_overlay_buffer_3f = opts["transient-overlay-buffer?"]
  local first_window_for_buffer = opts["first-window-for-buffer"]
  local hidden_session_reachable_3f = opts["hidden-session-reachable?"]
  local begin_direct_results_edit_21 = opts["begin-direct-results-edit!"]
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
  local function handle_results_focus_21(session)
    if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      session.meta.buf["prepare-visible-edit!"]()
    else
    end
    if maybe_restore_hidden_ui_21 then
      local function _8_()
        if (not session.closing and session_active_3f(session)) then
          return pcall(maybe_restore_hidden_ui_21, session)
        else
          return nil
        end
      end
      return vim.schedule(_8_)
    else
      return nil
    end
  end
  local function handle_overlay_winnew_21(session)
    local function _11_()
      if (hide_visible_ui_21 and not session["ui-hidden"] and session_active_3f(session)) then
        local win = vim.api.nvim_get_current_win()
        if covered_by_new_window_3f(session, win) then
          return pcall(hide_visible_ui_21, session)
        else
          return nil
        end
      else
        return nil
      end
    end
    return vim.defer_fn(_11_, 20)
  end
  local function handle_overlay_bufwinenter_21(session, ev)
    local function _14_()
      if (hide_visible_ui_21 and not session["ui-hidden"] and session_active_3f(session)) then
        local buf = (ev.buf or vim.api.nvim_get_current_buf())
        local win = (first_window_for_buffer(buf) or vim.api.nvim_get_current_win())
        if (transient_overlay_buffer_3f(buf) or covered_by_new_window_3f(session, win)) then
          return pcall(hide_visible_ui_21, session)
        else
          return nil
        end
      else
        return nil
      end
    end
    return vim.defer_fn(_14_, 20)
  end
  local function handle_selection_focus_21(session)
    return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
  end
  local function handle_hidden_session_gc_21(router, session)
    local function _17_()
      if (session["ui-hidden"] and session_active_3f(session) and not hidden_session_reachable_3f(session)) then
        return pcall(router["remove-session"], session)
      else
        return nil
      end
    end
    return vim.schedule(_17_)
  end
  local function handle_results_leave_21(router, session)
    local function _19_()
      if (not session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session)) then
        local win = session.meta.win.window
        if not vim.api.nvim_win_is_valid(win) then
          return router.cancel(session["prompt-buf"])
        else
          local buf = vim.api.nvim_win_get_buf(win)
          if (buf ~= session.meta.buf.buffer) then
            if (session["project-mode"] and hide_visible_ui_21) then
              return hide_visible_ui_21(session["prompt-buf"])
            else
              return router.cancel(session["prompt-buf"])
            end
          else
            return nil
          end
        end
      else
        return nil
      end
    end
    return vim.schedule(_19_)
  end
  local function invalidate_path_caches_21(router, session, path)
    if session["preview-file-cache"] then
      session["preview-file-cache"][path] = nil
    else
    end
    if session["info-file-head-cache"] then
      session["info-file-head-cache"][path] = nil
    else
    end
    if session["info-file-meta-cache"] then
      session["info-file-meta-cache"][path] = nil
    else
    end
    if router["project-file-cache"] then
      router["project-file-cache"][path] = nil
      return nil
    else
      return nil
    end
  end
  local function handle_external_write_21(router, session, ev)
    local function _28_()
      if (session_active_3f(session) and not session.closing) then
        local buf = (ev.buf or vim.api.nvim_get_current_buf())
        if (vim.api.nvim_buf_is_valid(buf) and (buf ~= session.meta.buf.buffer)) then
          local raw = vim.api.nvim_buf_get_name(buf)
          local path
          if (raw and (raw ~= "")) then
            path = vim.fn.fnamemodify(raw, ":p")
          else
            path = nil
          end
          if path then
            invalidate_path_caches_21(router, session, path)
            if rebuild_source_set_21 then
              pcall(rebuild_source_set_21, session)
            else
            end
            return emit_query_refresh_21(session)
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
    return vim.schedule(_28_)
  end
  local function handle_scroll_sync_21(session)
    return schedule_scroll_sync_21(session)
  end
  local function handle_results_writecmd_21(router, session)
    return router["write-results"](session["prompt-buf"])
  end
  local function handle_results_wipeout_21(router, session)
    local function _34_()
      return router["results-buffer-wiped"](session.meta.buf.buffer)
    end
    return vim.schedule(_34_)
  end
  return {["handle-results-cursor!"] = handle_results_cursor_21, ["handle-results-edit-enter!"] = handle_results_edit_enter_21, ["handle-results-text-changed!"] = handle_results_text_changed_21, ["handle-results-focus!"] = handle_results_focus_21, ["handle-overlay-winnew!"] = handle_overlay_winnew_21, ["handle-overlay-bufwinenter!"] = handle_overlay_bufwinenter_21, ["handle-selection-focus!"] = handle_selection_focus_21, ["handle-hidden-session-gc!"] = handle_hidden_session_gc_21, ["handle-results-leave!"] = handle_results_leave_21, ["handle-external-write!"] = handle_external_write_21, ["handle-scroll-sync!"] = handle_scroll_sync_21, ["handle-results-writecmd!"] = handle_results_writecmd_21, ["handle-results-wipeout!"] = handle_results_wipeout_21}
end
return M
