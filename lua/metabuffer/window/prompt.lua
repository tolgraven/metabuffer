local base = require("metabuffer.window.base")
local M = {}
M.new = function(nvim)
  vim.cmd("botright new")
  return base.new(nvim, vim.api.nvim_get_current_win(), {}, {})
end
return M
