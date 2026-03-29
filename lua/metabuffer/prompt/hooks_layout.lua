-- [nfnl] fnl/metabuffer/prompt/hooks_layout.fnl
local M = {}
local events = require("metabuffer.events")
M.new = function(opts)
  local session_prompt_valid_3f = opts["session-prompt-valid?"]
  local capture_expected_layout_21 = opts["capture-expected-layout!"]
  local note_editor_size_21 = opts["note-editor-size!"]
  local note_global_editor_resize_21 = opts["note-global-editor-resize!"]
  local manual_prompt_resize_3f = opts["manual-prompt-resize?"]
  local schedule_restore_expected_layout_21 = opts["schedule-restore-expected-layout!"]
  local refresh_prompt_highlights_21 = opts["refresh-prompt-highlights!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local function emit_query_refresh_21(session)
    return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
  end
  local function handle_global_resize_21(session, ev)
    if not session["handling-layout-change?"] then
      local is_vim_resized_3f = (ev.event == "VimResized")
      local wins
      local _2_
      do
        local t_1_ = vim.v
        if (nil ~= t_1_) then
          t_1_ = t_1_.event
        else
        end
        if (nil ~= t_1_) then
          t_1_ = t_1_.windows
        else
        end
        _2_ = t_1_
      end
      wins = (_2_ or {})
      local manual_prompt_resize = (not is_vim_resized_3f and manual_prompt_resize_3f(session, wins))
      if is_vim_resized_3f then
        session["preview-user-resized?"] = false
      else
      end
      do
        local editor_size_changed_3f = (((session["last-editor-columns"] or vim.o.columns) ~= vim.o.columns) or ((session["last-editor-lines"] or vim.o.lines) ~= vim.o.lines))
        note_editor_size_21(session)
        if (is_vim_resized_3f or editor_size_changed_3f) then
          note_global_editor_resize_21(session)
        else
        end
        if (not is_vim_resized_3f and not editor_size_changed_3f and not session["preview-global-resize-token"] and session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
          for _, wid in ipairs(wins) do
            if (wid == session["preview-win"]) then
              session["preview-user-resized?"] = true
            else
            end
          end
        else
        end
      end
      if manual_prompt_resize then
        session["prompt-target-height"] = vim.api.nvim_win_get_height(session["prompt-win"])
        capture_expected_layout_21(session)
      else
        schedule_restore_expected_layout_21(session)
      end
      session["handling-layout-change?"] = true
      local function _10_()
        if session_prompt_valid_3f(session) then
          do
            local results_wrap_3f = (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
            if (results_wrap_3f and rebuild_source_set_21 and not session["project-mode"]) then
              pcall(rebuild_source_set_21, session)
              pcall(session.meta["on-update"], 0)
            else
            end
          end
          if not session["prompt-animating?"] then
            pcall(refresh_prompt_highlights_21, session)
            emit_query_refresh_21(session)
          else
          end
          if (ev.event == "VimResized") then
            capture_expected_layout_21(session)
          else
          end
        else
        end
        session["handling-layout-change?"] = false
        return nil
      end
      return vim.schedule(_10_)
    else
      return nil
    end
  end
  local function handle_wrap_option_set_21(session)
    if not session["handling-layout-change?"] then
      session["handling-layout-change?"] = true
      local function _16_()
        if session_prompt_valid_3f(session) then
          if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and (vim.api.nvim_get_current_win() == session.meta.win.window)) then
            local wrap_3f = not not vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window})
            pcall(vim.api.nvim_set_option_value, "linebreak", wrap_3f, {win = session.meta.win.window})
            if (rebuild_source_set_21 and not session["project-mode"]) then
              pcall(rebuild_source_set_21, session)
              pcall(session.meta["on-update"], 0)
              emit_query_refresh_21(session)
            else
            end
          else
          end
        else
        end
        session["handling-layout-change?"] = false
        return nil
      end
      return vim.schedule(_16_)
    else
      return nil
    end
  end
  return {["handle-global-resize!"] = handle_global_resize_21, ["handle-wrap-option-set!"] = handle_wrap_option_set_21}
end
return M
