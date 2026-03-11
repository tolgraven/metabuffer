-- [nfnl] fnl/metabuffer/window/floating.fnl
local window_base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, buf, opts)
  local _let_1_ = (opts or {})
  local width = _let_1_.width
  local height = _let_1_.height
  local col = _let_1_.col
  local row = _let_1_.row
  local relative = _let_1_.relative
  local anchor = _let_1_.anchor
  local win = _let_1_.win
  local lines = (vim.o.lines - 2)
  local winblend = (vim.g.meta_float_winblend or 13)
  local cfg = {relative = (relative or "editor"), width = (width or 20), height = (height or lines), col = (col or 100), row = (row or 1), anchor = (anchor or "NE"), style = "minimal"}
  local _
  if win then
    cfg["win"] = win
    _ = nil
  else
    _ = nil
  end
  local win0 = vim.api.nvim_open_win(buf, false, cfg)
  do
    local wo = vim.wo[win0]
    wo["winblend"] = winblend
  end
  return window_base.new(nvim, win0, {}, {})
end
return M
