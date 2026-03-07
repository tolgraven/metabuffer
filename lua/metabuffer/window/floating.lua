-- [nfnl] fnl/metabuffer/window/floating.fnl
local window_base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, buf, opts)
  local _let_1_ = (opts or {})
  local width = _let_1_.width
  local height = _let_1_.height
  local col = _let_1_.col
  local row = _let_1_.row
  local lines = (vim.o.lines - 2)
  local winblend = (vim.g.meta_float_winblend or 13)
  local cfg = {relative = "editor", width = (width or 20), height = (height or lines), col = (col or 100), row = (row or 1), anchor = "NE", style = "minimal"}
  local win = vim.api.nvim_open_win(buf, false, cfg)
  do
    local wo = vim.wo[win]
    wo["winblend"] = winblend
  end
  return window_base.new(nvim, win, {}, {})
end
return M
