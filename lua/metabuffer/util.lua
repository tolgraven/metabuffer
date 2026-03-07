-- [nfnl] fnl/metabuffer/util.fnl
local M = {}
M["split-input"] = function(text)
  return vim.split((text or ""), "%s+", {trimempty = true})
end
M["convert2regex-pattern"] = function(text)
  return table.concat(M["split-input"](text), "\\|")
end
M["assign-content"] = function(buf, lines)
  local view = vim.fn.winsaveview()
  do
    local bo = vim.bo[buf]
    bo["modifiable"] = true
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  do
    local bo = vim.bo[buf]
    bo["modifiable"] = false
  end
  return vim.fn.winrestview(view)
end
M["escape-vim-pattern"] = function(text)
  return vim.fn.escape((text or ""), "\\^$~.*[]")
end
M["query-is-lower"] = function(query)
  return (string.lower((query or "")) == (query or ""))
end
M["buf-valid?"] = function(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
M["win-valid?"] = function(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
M.deepcopy = function(x)
  return vim.deepcopy(x)
end
M.clamp = function(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end
M["buf-lines"] = function(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
M.cursor = function()
  return vim.api.nvim_win_get_cursor(0)
end
M["set-cursor"] = function(row, col)
  return vim.api.nvim_win_set_cursor(0, {row, (col or 0)})
end
return M
