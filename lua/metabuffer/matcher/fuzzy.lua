-- [nfnl] fnl/metabuffer/matcher/fuzzy.fnl
local base = require("metabuffer.matcher.base")
local M = {}
local function mkpat(fmt, esc, q)
  local chars = vim.fn.split((q or ""), "\\zs")
  local out = {}
  for _, ch in ipairs(chars) do
    local e = esc(ch)
    table.insert(out, string.format(fmt, e, e))
  end
  return table.concat(out, "")
end
M.new = function()
  local function _1_(_, query)
    return mkpat("%s[^%s]\\{-}", base["escape-vim-patterns"], query)
  end
  local function _2_(_, query, indices, candidates, ignorecase)
    local pat = mkpat("%s[^%s]*", vim.pesc, query)
    local out = {}
    for _0, idx in ipairs(indices) do
      local line = candidates[idx]
      local line1
      if ignorecase then
        line1 = string.lower(line)
      else
        line1 = line
      end
      local pat1
      if ignorecase then
        pat1 = string.lower(pat)
      else
        pat1 = pat
      end
      local ok,s = pcall(string.find, line1, pat1)
      if (ok and s) then
        table.insert(out, idx)
      else
      end
    end
    return out
  end
  return base.new("fuzzy", {["also-highlight-per-char"] = true, ["get-highlight-pattern"] = _1_, filter = _2_})
end
return M
