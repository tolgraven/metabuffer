local base = require("metabuffer.matcher.base")
local util = require("metabuffer.util")
local M = {}
M.new = function()
  local function _1_(_, query)
    local pats = {}
    for _0, p in ipairs(util["split-input"](query)) do
      table.insert(pats, base["escape-vim-patterns"](p))
    end
    return ("\\%%(" .. table.concat(pats, "\\|") .. "\\)")
  end
  local function _2_(_, query, indices, candidates, ignorecase)
    local words = util["split-input"](query)
    if ignorecase then
      for i, w in ipairs(words) do
        words[i] = string.lower(w)
      end
    else
    end
    local out = {}
    for _0, idx in ipairs(indices) do
      local line = candidates[idx]
      local probe
      if ignorecase then
        probe = string.lower(line)
      else
        probe = line
      end
      local ok = true
      for _1, w in ipairs(words) do
        if not string.find(probe, w, 1, true) then
          ok = false
          __fnl_global__break()
        else
        end
      end
      if ok then
        table.insert(out, idx)
      else
      end
    end
    return out
  end
  return base.new("all", {["get-highlight-pattern"] = _1_, filter = _2_})
end
return M
