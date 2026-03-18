-- [nfnl] fnl/metabuffer/window/base.fnl
local handle = require("metabuffer.handle")
local M = {}
local function disable_airline_statusline_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_set_var, win, "airline_disable_statusline", 1)
  else
    return nil
  end
end
local function metabuffer_winhighlight()
  return "CursorLine:MetaWindowCursorLine,WinSeparator:MetaWindowSeparator,VertSplit:MetaWindowSeparator"
end
local function apply_metabuffer_window_highlights_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_set_option_value, "winhighlight", metabuffer_winhighlight(), {win = win})
  else
    return nil
  end
end
M.new = function(nvim, win, opts_to_stash, opts)
  local self = handle.new(nvim, win, win, opts_to_stash, opts)
  self.window = win
  self["set-statusline"] = function(text)
    if vim.api.nvim_win_is_valid(self.window) then
      return self["push-opt"]("statusline", text)
    else
      return nil
    end
  end
  self["set-cursor"] = function(row, col)
    return vim.api.nvim_win_set_cursor(self.window, {row, (col or 0)})
  end
  self["set-row"] = function(row, addjump)
    if addjump then
      return vim.cmd((":" .. tostring(row)))
    else
      return self["set-cursor"](row)
    end
  end
  self["set-col"] = function(col)
    local cur = vim.api.nvim_win_get_cursor(self.window)
    return self["set-cursor"](cur[1], col)
  end
  self["set-buf"] = function(buf)
    return vim.api.nvim_win_set_buf(self.window, buf)
  end
  return self
end
M["disable-airline-statusline!"] = disable_airline_statusline_21
M["metabuffer-winhighlight"] = metabuffer_winhighlight
M["apply-metabuffer-window-highlights!"] = apply_metabuffer_window_highlights_21
return M
