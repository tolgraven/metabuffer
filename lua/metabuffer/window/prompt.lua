-- [nfnl] fnl/metabuffer/window/prompt.fnl
local base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, opts)
  local cfg = (opts or {})
  local height = (cfg.height or 3)
  local local_layout_3f
  if (cfg["window-local-layout"] == nil) then
    local_layout_3f = true
  else
    local_layout_3f = cfg["window-local-layout"]
  end
  local origin_win = cfg["origin-win"]
  local win
  if (local_layout_3f and origin_win and vim.api.nvim_win_is_valid(origin_win)) then
    local function _2_()
      vim.cmd(("belowright " .. tostring(height) .. "new"))
      return vim.api.nvim_get_current_win()
    end
    win = vim.api.nvim_win_call(origin_win, _2_)
  else
    vim.cmd(("botright " .. tostring(height) .. "new"))
    win = vim.api.nvim_get_current_win()
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local self = base.new(nvim, win, {}, {})
  pcall(vim.api.nvim_win_set_height, win, height)
  do
    local bo = vim.bo[buf]
    bo["buftype"] = "nofile"
    bo["bufhidden"] = "wipe"
    bo["swapfile"] = false
    bo["modifiable"] = true
    bo["filetype"] = "metabufferprompt"
  end
  do
    local b = vim.b[buf]
    local wo = vim.wo[win]
    b["cmp_enabled"] = false
    wo["winfixheight"] = true
    wo["number"] = false
    wo["relativenumber"] = false
    wo["signcolumn"] = "no"
    wo["foldcolumn"] = "0"
    wo["spell"] = false
    wo["wrap"] = true
    wo["linebreak"] = false
  end
  local function _4_()
    return pcall(vim.fn.winrestview, {leftcol = 0})
  end
  vim.api.nvim_win_call(win, _4_)
  self.buffer = buf
  return self
end
return M
