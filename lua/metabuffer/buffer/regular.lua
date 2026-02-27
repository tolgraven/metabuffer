local base = require("metabuffer.buffer.base")
local M = {}
M.new = function(nvim, opts)
  return base.new(nvim, (opts or {name = "buffer"}))
end
return M
