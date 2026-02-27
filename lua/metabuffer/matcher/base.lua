local util = require("metabuffer.util")
local M = {}
M["default-hi-prefix"] = "MetaSearchHit"
M["default-hi-char"] = "MetaSearchHitFuzzyBetween"
M.new = function(name, opts)
  local self
  local or_1_ = (opts and opts["get-highlight-pattern"])
  if not or_1_ then
    local function _2_(_, _0)
      return ""
    end
    or_1_ = _2_
  end
  local or_3_ = (opts and opts.filter)
  if not or_3_ then
    local function _4_(_, _0, _1, _2)
      return {}
    end
    or_3_ = _4_
  end
  self = {name = name, ["also-highlight-per-char"] = (opts and opts["also-highlight-per-char"]), ["match-id"] = nil, ["char-match-id"] = nil, ["get-highlight-pattern"] = or_1_, filter = or_3_}
  self["remove-highlight"] = function()
    if self["match-id"] then
      pcall(vim.fn.matchdelete, self["match-id"])
      self["match-id"] = nil
    else
    end
    if self["char-match-id"] then
      pcall(vim.fn.matchdelete, self["char-match-id"])
      self["char-match-id"] = nil
      return nil
    else
      return nil
    end
  end
  self.highlight = function(query, ignorecase)
    self["remove-highlight"]()
    if (query and (query ~= "")) then
      local pat = self["get-highlight-pattern"](self, query)
      local group = (M["default-hi-prefix"] .. string.upper(string.sub(self.name, 1, 1)) .. string.sub(self.name, 2))
      local case_prefix
      if ignorecase then
        case_prefix = "\\c"
      else
        case_prefix = "\\C"
      end
      self["match-id"] = vim.fn.matchadd(group, (case_prefix .. pat), 0)
      if self["also-highlight-per-char"] then
        self["char-match-id"] = vim.fn.matchadd(M["default-hi-char"], table.concat(vim.split(query, ""), "\\|"), 0)
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  return self
end
M["escape-vim-patterns"] = function(text)
  return util["escape-vim-pattern"](text)
end
return M
