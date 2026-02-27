local window_base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, buf, opts)
  local columns = vim.o.columns
  local lines = (vim.o.lines - 2)
  local cfg = {relative = "editor", width = ((opts and opts.width) or 20), height = ((opts and opts.height) or lines), col = ((opts and opts.col) or 100), row = ((opts and opts.row) or 1), anchor = "NE", style = "minimal"}
  local win = vim.api.nvim_open_win(buf, false, cfg)
  vim.wo[win]["winblend"] = 25
  return window_base.new(nvim, win, {}, {})
end
return M
