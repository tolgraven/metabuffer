local base = require("metabuffer.matcher.base")
local util = require("metabuffer.util")
local M = {}
M.new = function()
  local function _1_(_, query)
    return util["convert2regex-pattern"](query)
  end
  local function _2_(_, query, indices, candidates, ignorecase)
    local patterns = util["split-input"](query)
    local active = util.deepcopy(indices)
    for _0, pattern in ipairs(patterns) do
      local next = {}
      for _1, idx in ipairs(active) do
        local line = candidates[idx]
        local probe
        if ignorecase then
          probe = string.lower(line)
        else
          probe = line
        end
        local p
        if ignorecase then
          p = string.lower(pattern)
        else
          p = pattern
        end
        local ok = pcall(string.find, probe, p)
        if (ok and string.find(probe, p)) then
          table.insert(next, idx)
        else
        end
      end
      active = next
    end
    return active
  end
  return base.new("regex", {["get-highlight-pattern"] = _1_, filter = _2_})
end
return M
