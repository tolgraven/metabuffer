-- [nfnl] fnl/metabuffer/window/util.fnl
local M = {}
M["window-rect"] = function(win)
  if (win and (type(win) == "number") and vim.api.nvim_win_is_valid(win)) then
    local pos = vim.api.nvim_win_get_position(win)
    local row = (pos[1] or 0)
    local col = (pos[2] or 0)
    local height = vim.api.nvim_win_get_height(win)
    local width = vim.api.nvim_win_get_width(win)
    return {top = row, left = col, bottom = (row + height + -1), right = (col + width + -1)}
  else
    return nil
  end
end
M["rect-overlap?"] = function(a, b)
  return (a and b and (a.top <= b.bottom) and (b.top <= a.bottom) and (a.left <= b.right) and (b.left <= a.right))
end
M["first-window-for-buffer"] = function(buf)
  if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
    local wins = vim.fn.win_findbuf(buf)
    local found = nil
    for _, win in ipairs((wins or {})) do
      if (not found and vim.api.nvim_win_is_valid(win)) then
        found = win
      else
      end
    end
    return found
  else
    return nil
  end
end
M["tab-window-count"] = function(win)
  if (win and (type(win) == "number") and vim.api.nvim_win_is_valid(win)) then
    local ok,tab = pcall(vim.api.nvim_win_get_tabpage, win)
    if (ok and tab) then
      local ok2,wins = pcall(vim.api.nvim_tabpage_list_wins, tab)
      if (ok2 and (type(wins) == "table")) then
        return #wins
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
return M
