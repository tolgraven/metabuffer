-- [nfnl] fnl/metabuffer/prompt/hooks_window.fnl
local window_util = require("metabuffer.window.util")
local M = {}
local function transient_overlay_buffer_3f(buf)
  if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
    local bo = vim.bo[buf]
    local ft = (bo.filetype or "")
    local bt = (bo.buftype or "")
    return ((ft == "help") or (ft == "man") or (bt == "help"))
  else
    return nil
  end
end
M.new = function(session_prompt_valid_3f)
  local window_rect = window_util["window-rect"]
  local rect_overlap_3f = window_util["rect-overlap?"]
  local first_window_for_buffer = window_util["first-window-for-buffer"]
  local tab_window_count = window_util["tab-window-count"]
  local function meta_owned_window_3f(session, win)
    local meta_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return ((win == meta_win) or (win == prompt_win) or (win == info_win) or (win == preview_win) or (win == history_win))
  end
  local function covered_by_new_window_3f(session, win)
    local target = window_rect(win)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return (target and not meta_owned_window_3f(session, win) and (rect_overlap_3f(target, window_rect(info_win)) or rect_overlap_3f(target, window_rect(preview_win)) or rect_overlap_3f(target, window_rect(history_win)) or (session["prompt-floating?"] and rect_overlap_3f(target, window_rect(prompt_win)))))
  end
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
      local function _4_()
        if (session and (token == session["preview-global-resize-token"])) then
          session["preview-global-resize-token"] = nil
          return nil
        else
          return nil
        end
      end
      return vim.defer_fn(_4_, 120)
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
      local function _15_()
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
      return vim.defer_fn(_15_, 80)
    else
      return nil
    end
  end
  local function hidden_session_reachable_3f(session)
    local results_buf = (session and session.meta and session.meta.buf and session.meta.buf.buffer)
    if not (results_buf and vim.api.nvim_buf_is_valid(results_buf)) then
      return false
    else
      if (vim.api.nvim_get_current_buf() == results_buf) then
        return true
      else
        local raw = vim.fn.getjumplist()
        local jumps
        if ((type(raw) == "table") and (type(raw[1]) == "table")) then
          jumps = raw[1]
        else
          jumps = {}
        end
        local hit0 = false
        local hit = hit0
        for _, item in ipairs((jumps or {})) do
          if ((item.bufnr or item.bufnr) == results_buf) then
            hit = true
          else
          end
        end
        return hit
      end
    end
  end
  return {["covered-by-new-window?"] = covered_by_new_window_3f, ["transient-overlay-buffer?"] = transient_overlay_buffer_3f, ["first-window-for-buffer"] = first_window_for_buffer, ["capture-expected-layout!"] = capture_expected_layout_21, ["note-editor-size!"] = note_editor_size_21, ["note-global-editor-resize!"] = note_global_editor_resize_21, ["manual-prompt-resize?"] = manual_prompt_resize_3f, ["schedule-restore-expected-layout!"] = schedule_restore_expected_layout_21, ["hidden-session-reachable?"] = hidden_session_reachable_3f}
end
return M
