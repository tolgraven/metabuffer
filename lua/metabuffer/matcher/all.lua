-- [nfnl] fnl/metabuffer/matcher/all.fnl
local base = require("metabuffer.matcher.base")
local util = require("metabuffer.util")
local M = {}
local function unclosed_pattern_delims_3f(token)
  local n = #(token or "")
  local i = 1
  local paren = 0
  local bracket = 0
  while (i <= n) do
    local ch = string.sub(token, i, i)
    if (ch == "%") then
      i = (i + 2)
    else
      if (ch == "(") then
        paren = (paren + 1)
      elseif (ch == ")") then
        paren = math.max(0, (paren - 1))
      else
      end
      if (ch == "[") then
        bracket = (bracket + 1)
      elseif (ch == "]") then
        bracket = math.max(0, (bracket - 1))
      else
      end
      i = (i + 1)
    end
  end
  return ((paren > 0) or (bracket > 0))
end
local function regex_token_3f(token)
  local and_4_ = (type(token) == "string") and (token ~= "") and not string.match(token, "^[%?%*%+%|%.]$") and not unclosed_pattern_delims_3f(token) and not not string.find(token, "[\\%[%]%(%)%+%*%?%|%.]")
  if and_4_ then
    local ok = pcall(vim.regex, ("\\C" .. token))
    and_4_ = ok
  end
  return and_4_
end
local function unescape_token_specials(token)
  local s = (token or "")
  local n = #(token or "")
  local i = 1
  local out = ""
  while (i <= n) do
    local ch = string.sub(s, i, i)
    if ((ch == "\\") and (i < n)) then
      local next = string.sub(s, (i + 1), (i + 1))
      if ((next == "!") or (next == "^") or (next == "$")) then
        out = (out .. next)
        i = (i + 2)
      else
        out = (out .. ch)
        i = (i + 1)
      end
    else
      out = (out .. ch)
      i = (i + 1)
    end
  end
  return out
end
local function escaped_leading_3f(s, ch)
  return vim.startswith((s or ""), ("\\" .. ch))
end
local function escaped_trailing_dollar_3f(s)
  local txt = (s or "")
  local n = #txt
  return ((n > 1) and (string.sub(txt, (n - 1), (n - 1)) == "\\") and (string.sub(txt, n, n) == "$"))
end
local function parse_term(raw)
  local token = (raw or "")
  local bang_only_3f = (token == "!")
  local escaped_bang_3f = escaped_leading_3f(token, "!")
  local negated = (not bang_only_3f and not escaped_bang_3f and (string.sub(token, 1, 1) == "!"))
  local body0
  if bang_only_3f then
    body0 = "!"
  elseif escaped_bang_3f then
    body0 = string.sub(token, 2)
  elseif negated then
    body0 = string.sub(token, 2)
  else
    body0 = token
  end
  local escaped_caret_3f = escaped_leading_3f(body0, "^")
  local anchor_start = (not escaped_caret_3f and (#body0 > 0) and (string.sub(body0, 1, 1) == "^"))
  local body1
  if escaped_caret_3f then
    body1 = string.sub(body0, 2)
  elseif anchor_start then
    body1 = string.sub(body0, 2)
  else
    body1 = body0
  end
  local escaped_dollar_3f = escaped_trailing_dollar_3f(body1)
  local anchor_end = (not escaped_dollar_3f and (#body1 > 0) and (string.sub(body1, #body1) == "$"))
  local body2
  if escaped_dollar_3f then
    body2 = (string.sub(body1, 1, (#body1 - 2)) .. "$")
  elseif anchor_end then
    body2 = string.sub(body1, 1, (#body1 - 1))
  else
    body2 = body1
  end
  local needle = unescape_token_specials(body2)
  local has_needle = (#needle > 0)
  local effective_negated = (negated and has_needle)
  return {negated = effective_negated, ["anchor-start"] = anchor_start, ["anchor-end"] = anchor_end, needle = needle, regex = regex_token_3f(needle)}
end
local function term_match_3f(term, line, literal_probe, ignorecase)
  local needle = (term.needle or "")
  if (needle == "") then
    return true
  else
    if term.regex then
      local rx_key
      if ignorecase then
        rx_key = "rx-ic"
      else
        rx_key = "rx-cs"
      end
      local existing = term[rx_key]
      local rx
      if existing then
        rx = existing
      else
        local _12_
        if ignorecase then
          _12_ = "\\c"
        else
          _12_ = "\\C"
        end
        local ok,rex = pcall(vim.regex, (_12_ .. needle))
        if ok then
          term[rx_key] = rex
          rx = rex
        else
          rx = nil
        end
      end
      if rx then
        local s,_e = rx:match_str(line)
        return s
      else
        return false
      end
    else
      if term["anchor-start"] then
        if term["anchor-end"] then
          return (literal_probe == needle)
        else
          return vim.startswith(literal_probe, needle)
        end
      else
        if term["anchor-end"] then
          return vim.endswith(literal_probe, needle)
        else
          return not not string.find(literal_probe, needle, 1, true)
        end
      end
    end
  end
end
local function term_highlight_pattern(term)
  local needle = (term.needle or "")
  if (needle == "") then
    return ""
  else
    if term.regex then
      return needle
    else
      return base["escape-vim-patterns"](needle)
    end
  end
end
M.new = function()
  local function _24_(_, query)
    local items = {}
    for _0, raw in ipairs(util["split-input"](query)) do
      local term = parse_term(raw)
      local pat = term_highlight_pattern(term)
      if ((pat ~= "") and not term.negated) then
        local _25_
        if term.regex then
          _25_ = "MetaSearchHitRegex"
        else
          _25_ = "MetaSearchHitAll"
        end
        table.insert(items, {group = _25_, pattern = ("\\%(" .. pat .. "\\)")})
      else
      end
    end
    return items
  end
  local function _28_(_, query, indices, candidates, ignorecase)
    local terms = vim.tbl_map(parse_term, util["split-input"](query))
    local out = {}
    if ignorecase then
      for _0, t in ipairs(terms) do
        if not t.regex then
          t["needle"] = string.lower((t.needle or ""))
        else
        end
      end
    else
    end
    for _0, idx in ipairs(indices) do
      local line = (candidates[idx] or "")
      local probe
      if ignorecase then
        probe = string.lower(line)
      else
        probe = line
      end
      local ok = true
      for _1, term in ipairs(terms) do
        local hit_3f = term_match_3f(term, line, probe, ignorecase)
        local pass_3f
        if term.negated then
          pass_3f = not hit_3f
        else
          pass_3f = hit_3f
        end
        if (ok and not pass_3f) then
          ok = false
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
  return base.new("all", {["get-highlight-pattern"] = _24_, filter = _28_})
end
return M
