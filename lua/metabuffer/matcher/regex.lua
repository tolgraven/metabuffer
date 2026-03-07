-- [nfnl] fnl/metabuffer/matcher/regex.fnl
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
      local vim_pattern
      local _3_
      if ignorecase then
        _3_ = "\\c"
      else
        _3_ = "\\C"
      end
      vim_pattern = (_3_ .. pattern)
      local rx = nil
      do
        local ok,rex = pcall(vim.regex, vim_pattern)
        if ok then
          rx = rex
        else
        end
      end
      if rx then
        for _1, idx in ipairs(active) do
          local line = candidates[idx]
          local s,_e = rx:match_str(line)
          if s then
            table.insert(next, idx)
          else
          end
        end
      else
      end
      active = next
    end
    return active
  end
  return base.new("regex", {["get-highlight-pattern"] = _1_, filter = _2_})
end
return M
