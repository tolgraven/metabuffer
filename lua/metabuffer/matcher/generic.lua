local base = require("metabuffer.matcher.base")
local M = {}
M.new = function()
  local function _1_(_, query)
    return query
  end
  local function _2_(_, _0, indices, _1, _2)
    return indices
  end
  return base.new("generic", {["get-highlight-pattern"] = _1_, filter = _2_})
end
return M
