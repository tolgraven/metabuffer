-- [nfnl] fnl/metabuffer/prompt/hooks_window_layout.fnl
local window_util = require("metabuffer.window.util")
local M = {}
M.new = function(session_prompt_valid_3f)
  local tab_window_count = window_util["tab-window-count"]
  local function layout_snapshot(session)
    local main_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local preview_win = session["preview-win"]
    if (main_win and prompt_win and preview_win and vim.api.nvim_win_is_valid(main_win) and vim.api.nvim_win_is_valid(prompt_win) and vim.api.nvim_win_is_valid(preview_win)) then
      return {["main-height"] = vim.api.nvim_win_get_height(main_win), ["prompt-height"] = vim.api.nvim_win_get_height(prompt_win), ["preview-height"] = vim.api.nvim_win_get_height(preview_win), ["tab-window-count"] = tab_window_count(main_win)}
    else
      return nil
    end
  end
  local function note_editor_size_21(session)
    if session then
      session["last-editor-columns"] = vim.o.columns
      session["last-editor-lines"] = vim.o.lines
      return nil
    else
      return nil
    end
  end
  local function note_global_editor_resize_21(session)
    if session then
      session["preview-user-resized?"] = false
      session["preview-global-resize-token"] = (1 + (session["preview-global-resize-token"] or 0))
      local token = session["preview-global-resize-token"]
      local function _3_()
        if (session and (token == session["preview-global-resize-token"])) then
          session["preview-global-resize-token"] = nil
          return nil
        else
          return nil
        end
      end
      return vim.defer_fn(_3_, 120)
    else
      return nil
    end
  end
  local function capture_expected_layout_21(session)
    if (session and not session.closing and not session["ui-hidden"] and not session["prompt-floating?"] and not session["prompt-animating?"]) then
      local val_110_auto = layout_snapshot(session)
      if val_110_auto then
        local snap = val_110_auto
        session["expected-layout"] = snap
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function expected_layout_mismatch_3f(session)
    local val_111_auto = session["expected-layout"]
    if val_111_auto then
      local expected = val_111_auto
      local val_111_auto0 = layout_snapshot(session)
      if val_111_auto0 then
        local current = val_111_auto0
        return ((current["main-height"] ~= expected["main-height"]) or (current["prompt-height"] ~= expected["prompt-height"]) or (current["preview-height"] ~= expected["preview-height"]))
      else
        return false
      end
    else
      return false
    end
  end
  local function manual_prompt_resize_3f(session, resized_wins)
    local val_111_auto = session["expected-layout"]
    if val_111_auto then
      local expected = val_111_auto
      local prompt_win = session["prompt-win"]
      local prompt_valid_3f = (prompt_win and vim.api.nvim_win_is_valid(prompt_win))
      local tab_count = (session.meta and session.meta.win and session.meta.win.window and tab_window_count(session.meta.win.window))
      local prompt_height = (prompt_valid_3f and vim.api.nvim_win_get_height(prompt_win))
      local prompt_hit_3f = false
      local hit = prompt_hit_3f
      for _, wid in ipairs((resized_wins or {})) do
        if (wid == prompt_win) then
          hit = true
        else
        end
      end
      return (prompt_valid_3f and hit and (tab_count == expected["tab-window-count"]) and (prompt_height ~= expected["prompt-height"]))
    else
      return false
    end
  end
  local function restore_expected_layout_21(session)
    local val_110_auto = session["expected-layout"]
    if val_110_auto then
      local expected = val_110_auto
      local main_win = (session.meta and session.meta.win and session.meta.win.window)
      local prompt_win = session["prompt-win"]
      local preview_win = session["preview-win"]
      if (main_win and prompt_win and preview_win and vim.api.nvim_win_is_valid(main_win) and vim.api.nvim_win_is_valid(prompt_win) and vim.api.nvim_win_is_valid(preview_win)) then
        session["handling-layout-change?"] = true
        pcall(vim.api.nvim_win_set_height, main_win, math.max(1, (expected["main-height"] or 1)))
        pcall(vim.api.nvim_win_set_height, prompt_win, math.max(1, (expected["prompt-height"] or 1)))
        pcall(vim.api.nvim_win_set_height, preview_win, math.max(1, (expected["preview-height"] or 1)))
        session["handling-layout-change?"] = false
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function schedule_restore_expected_layout_21(session)
    if session["expected-layout"] then
      session["layout-restore-token"] = (1 + (session["layout-restore-token"] or 0))
      local token = session["layout-restore-token"]
      local function _14_()
        if (session_prompt_valid_3f(session) and (token == session["layout-restore-token"]) and session["expected-layout"]) then
          local main_win = (session.meta and session.meta.win and session.meta.win.window)
          local current_count = (main_win and tab_window_count(main_win))
          local expected_count = session["expected-layout"]["tab-window-count"]
          if ((current_count == expected_count) and expected_layout_mismatch_3f(session)) then
            return restore_expected_layout_21(session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_14_, 80)
    else
      return nil
    end
  end
  return {["capture-expected-layout!"] = capture_expected_layout_21, ["manual-prompt-resize?"] = manual_prompt_resize_3f, ["note-editor-size!"] = note_editor_size_21, ["note-global-editor-resize!"] = note_global_editor_resize_21, ["schedule-restore-expected-layout!"] = schedule_restore_expected_layout_21}
end
return M
