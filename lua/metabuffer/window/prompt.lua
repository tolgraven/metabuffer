-- [nfnl] fnl/metabuffer/window/prompt.fnl
local base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim, opts)
  local cfg = (opts or {})
  local height = (cfg.height or 3)
  local start_height = math.max(1, (cfg["start-height"] or height))
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
      vim.cmd(("belowright " .. tostring(start_height) .. "new"))
      return vim.api.nvim_get_current_win()
    end
    win = vim.api.nvim_win_call(origin_win, _2_)
  else
    vim.cmd(("botright " .. tostring(start_height) .. "new"))
    win = vim.api.nvim_get_current_win()
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local self = base.new(nvim, win, {}, {})
  pcall(vim.api.nvim_win_set_height, win, start_height)
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
    wo["linebreak"] = true
  end
  self.buffer = buf
  return self
end
return M
