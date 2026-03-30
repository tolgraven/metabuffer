-- [nfnl] fnl/metabuffer/prompt/hooks_results_windows.fnl
local M = {}
M.new = function(opts)
  local covered_by_new_window_3f = opts["covered-by-new-window?"]
  local transient_overlay_buffer_3f = opts["transient-overlay-buffer?"]
  local first_window_for_buffer = opts["first-window-for-buffer"]
  local hidden_session_reachable_3f = opts["hidden-session-reachable?"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local function handle_results_focus_21(session, session_active_3f)
    if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      session.meta.buf["prepare-visible-edit!"]()
    else
    end
    if maybe_restore_hidden_ui_21 then
      local function _2_()
        if (not session.closing and session_active_3f(session)) then
          return pcall(maybe_restore_hidden_ui_21, session)
        else
          return nil
        end
      end
      return vim.schedule(_2_)
    else
      return nil
    end
  end
  local function handle_overlay_winnew_21(session, session_active_3f)
    local function _5_()
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
    return vim.defer_fn(_5_, 20)
  end
  local function handle_overlay_bufwinenter_21(session, ev, session_active_3f)
    local function _8_()
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
    return vim.defer_fn(_8_, 20)
  end
  local function handle_hidden_session_gc_21(router, session, session_active_3f)
    local function _11_()
      if (session["ui-hidden"] and session_active_3f(session) and not hidden_session_reachable_3f(session)) then
        return pcall(router["remove-session"], session)
      else
        return nil
      end
    end
    return vim.schedule(_11_)
  end
  local function handle_results_leave_21(router, session)
    local function _13_()
      if (not session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
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
    return vim.schedule(_13_)
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
  local function handle_external_write_21(router, session, ev, session_active_3f, emit_query_refresh_21)
    local function _22_()
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
    return vim.schedule(_22_)
  end
  return {["handle-external-write!"] = handle_external_write_21, ["handle-hidden-session-gc!"] = handle_hidden_session_gc_21, ["handle-overlay-bufwinenter!"] = handle_overlay_bufwinenter_21, ["handle-overlay-winnew!"] = handle_overlay_winnew_21, ["handle-results-focus!"] = handle_results_focus_21, ["handle-results-leave!"] = handle_results_leave_21}
end
return M
