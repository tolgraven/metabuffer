-- [nfnl] fnl/metabuffer/prompt/hooks_window_overlay.fnl
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
M.new = function()
  local window_rect = window_util["window-rect"]
  local rect_overlap_3f = window_util["rect-overlap?"]
  local first_window_for_buffer = window_util["first-window-for-buffer"]
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
  return {["covered-by-new-window?"] = covered_by_new_window_3f, ["first-window-for-buffer"] = first_window_for_buffer, ["hidden-session-reachable?"] = hidden_session_reachable_3f, ["transient-overlay-buffer?"] = transient_overlay_buffer_3f}
end
return M
