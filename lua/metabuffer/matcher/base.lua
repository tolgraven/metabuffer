-- [nfnl] fnl/metabuffer/matcher/base.fnl
local util = require("metabuffer.util")
local M = {}
M["default-hi-prefix"] = "MetaSearchHit"
M["default-hi-char"] = "MetaSearchHitFuzzyBetween"
M["default-match-priority"] = (vim.g.meta_search_match_priority or 220)
local function line_highlight_group(matcher_name, idx, default_group)
  local suffix = tostring(((math.max(0, ((idx or 1) - 1)) % 6) + 1))
  local candidate = (M["default-hi-prefix"] .. string.upper(string.sub(matcher_name, 1, 1)) .. string.sub(matcher_name, 2) .. suffix)
  if (vim.fn.hlexists(candidate) > 0) then
    return candidate
  else
    return default_group
  end
end
local function per_line_item_group(idx, fallback_group, item_group)
  local generic_all = "MetaSearchHitAll"
  local generic_fuzzy = "MetaSearchHitFuzzy"
  local generic_regex = "MetaSearchHitRegex"
  local target = (item_group or fallback_group)
  if (target == generic_all) then
    return line_highlight_group("all", idx, generic_all)
  elseif (target == generic_fuzzy) then
    return line_highlight_group("fuzzy", idx, generic_fuzzy)
  elseif (target == generic_regex) then
    return line_highlight_group("regex", idx, generic_regex)
  else
    return target
  end
end
M.new = function(name, opts)
  local self
  local or_3_ = (opts and opts["get-highlight-pattern"])
  if not or_3_ then
    local function _4_(_, _0)
      return ""
    end
    or_3_ = _4_
  end
  local or_5_ = (opts and opts.filter)
  if not or_5_ then
    local function _6_(_, _0, _1, _2)
      return {}
    end
    or_5_ = _6_
  end
  self = {name = name, ["also-highlight-per-char"] = (opts and opts["also-highlight-per-char"]), ["match-ids"] = {}, ["char-match-id"] = nil, ["match-win"] = nil, ["get-highlight-pattern"] = or_3_, filter = or_5_}
  local function delete_match(id, win)
    if (win and vim.api.nvim_win_is_valid(win)) then
      local or_7_ = pcall(vim.fn.matchdelete, id, win)
      if not or_7_ then
        local function _8_()
          return vim.fn.matchdelete(id)
        end
        or_7_ = pcall(vim.api.nvim_win_call, win, _8_)
      end
      return or_7_
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
    if (win and vim.api.nvim_win_is_valid(win)) then
      local ok,win_id = pcall(vim.fn.matchadd, group, pattern, M["default-match-priority"], -1, {window = win})
      if ok then
        return win_id
      else
        local function _11_()
          return vim.fn.matchadd(group, pattern, M["default-match-priority"])
        end
        return vim.api.nvim_win_call(win, _11_)
      end
    else
      return vim.fn.matchadd(group, pattern, M["default-match-priority"])
    end
  end
  self.highlight = function(_, query, ignorecase, target_win)
    self["remove-highlight"]()
    if (query and (query ~= "")) then
      local group = (M["default-hi-prefix"] .. string.upper(string.sub(self.name, 1, 1)) .. string.sub(self.name, 2))
      local case_prefix
      if ignorecase then
        case_prefix = "\\c"
      else
        case_prefix = "\\C"
      end
      local win = (target_win or vim.api.nvim_get_current_win())
      self["match-win"] = win
      if (type(query) == "table") then
        for idx, item_query in ipairs(query) do
          local item_pat = self["get-highlight-pattern"](self, item_query)
          local item_group = line_highlight_group(self.name, idx, group)
          if (type(item_pat) == "string") then
            if (item_pat ~= "") then
              table.insert(self["match-ids"], matchadd_in_window(item_group, (case_prefix .. item_pat), win))
            else
            end
          else
            if (type(item_pat) == "table") then
              for _0, item in ipairs(item_pat) do
                local resolved_group = per_line_item_group(idx, item_group, item.group)
                local resolved_pat = (item.pattern or "")
                if (resolved_pat ~= "") then
                  table.insert(self["match-ids"], matchadd_in_window(resolved_group, (case_prefix .. resolved_pat), win))
                else
                end
              end
            else
            end
          end
        end
      else
        local pat = self["get-highlight-pattern"](self, query)
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
      end
      if self["also-highlight-per-char"] then
        local _24_
        if (type(query) == "table") then
          _24_ = table.concat(query, " ")
        else
          _24_ = query
        end
        self["char-match-id"] = matchadd_in_window(M["default-hi-char"], table.concat(vim.split(_24_, ""), "\\|"), win)
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
