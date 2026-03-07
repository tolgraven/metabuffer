-- [nfnl] fnl/metabuffer/matcher/base.fnl
local util = require("metabuffer.util")
local M = {}
M["default-hi-prefix"] = "MetaSearchHit"
M["default-hi-char"] = "MetaSearchHitFuzzyBetween"
M["default-match-priority"] = (vim.g.meta_search_match_priority or 220)
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
  self = {name = name, ["also-highlight-per-char"] = (opts and opts["also-highlight-per-char"]), ["match-ids"] = {}, ["char-match-id"] = nil, ["match-win"] = nil, ["get-highlight-pattern"] = or_1_, filter = or_3_}
  local function delete_match(id, win)
    if (win and vim.api.nvim_win_is_valid(win)) then
      local or_5_ = pcall(vim.fn.matchdelete, id, win)
      if not or_5_ then
        local function _6_()
          return vim.fn.matchdelete(id)
        end
        or_5_ = pcall(vim.api.nvim_win_call, win, _6_)
      end
      return or_5_
    else
      return pcall(vim.fn.matchdelete, id)
    end
  end
  self["remove-highlight"] = function()
    for _, id in ipairs((self["match-ids"] or {})) do
      delete_match(id, self["match-win"])
    end
    self["match-ids"] = {}
    if self["char-match-id"] then
      delete_match(self["char-match-id"], self["match-win"])
      self["char-match-id"] = nil
    else
    end
    self["match-win"] = nil
    return nil
  end
  local function matchadd_in_window(group, pattern, win)
    local id = nil
    if (win and vim.api.nvim_win_is_valid(win)) then
      local ok,win_id = pcall(vim.fn.matchadd, group, pattern, M["default-match-priority"], -1, {window = win})
      if ok then
        return win_id
      else
        local function _9_()
          return vim.fn.matchadd(group, pattern, M["default-match-priority"])
        end
        return vim.api.nvim_win_call(win, _9_)
      end
    else
      return vim.fn.matchadd(group, pattern, M["default-match-priority"])
    end
  end
  self.highlight = function(_, query, ignorecase, target_win)
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
      local win = (target_win or vim.api.nvim_get_current_win())
      self["match-win"] = win
      if (type(pat) == "string") then
        if (pat ~= "") then
          table.insert(self["match-ids"], matchadd_in_window(group, (case_prefix .. pat), win))
        else
        end
      else
        if (type(pat) == "table") then
          for _0, item in ipairs(pat) do
            local item_group = (item.group or group)
            local item_pat = (item.pattern or "")
            if (item_pat ~= "") then
              table.insert(self["match-ids"], matchadd_in_window(item_group, (case_prefix .. item_pat), win))
            else
            end
          end
        else
        end
      end
      if self["also-highlight-per-char"] then
        self["char-match-id"] = matchadd_in_window(M["default-hi-char"], table.concat(vim.split(query, ""), "\\|"), win)
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
