-- [nfnl] fnl/metabuffer/window/prompt.fnl
local base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, opts)
  local cfg = (opts or {})
  local height = (cfg.height or 3)
  vim.cmd(("botright " .. tostring(height) .. "new"))
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()
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
  end
  self.buffer = buf
  return self
end
return M
