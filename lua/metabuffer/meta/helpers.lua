-- [nfnl] fnl/metabuffer/meta/helpers.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local directive_mod = require("metabuffer.query.directive")
local statusline_mod = require("metabuffer.window.statusline")
local util = require("metabuffer.util")
local M = {}
local function session_busy_3f(session)
  return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["lazy-stream-done"]) or (session["project-mode"] and not session["project-bootstrapped"])))
end
M["loading-visible?"] = function(session)
  return (session and session["loading-indicator?"] and (session_busy_3f(session) or (session["loading-anim-phase"] ~= nil) or session["loading-idle-pending"]))
end
M["results-middle-group"] = function(session)
  return ((session and session["results-statusline-pulse-active?"] and "MetaStatuslineMiddlePulse") or "MetaStatuslineMiddle")
end
local function ping_pong_center(phase, width)
  local w = math.max(1, (width or 1))
  if (w <= 1) then
    return 1
  else
    local period = math.max(1, ((2 * w) - 2))
    local step = ((phase or 0) % period)
    if (step < w) then
      return (step + 1)
    else
      return (period - step - -1)
    end
  end
end
local function status_fragment(group, text)
  if ((type(text) == "nil") or (text == "")) then
    return ""
  else
    return ("%#" .. group .. "#" .. string.gsub(text, "%%", "%%%%"))
  end
end
local function results_group(session, group)
  return ((session and session["results-statusline-pulse-active?"] and (group .. "Pulse")) or group)
end
local function project_flag_fragment(session, name, on_3f)
  local function _4_()
    if on_3f then
      return "+"
    else
      return "-"
    end
  end
  local function _5_()
    if on_3f then
      return "MetaStatuslineFlagOn"
    else
      return "MetaStatuslineFlagOff"
    end
  end
  return (status_fragment(results_group(session, "MetaStatuslineKey"), _4_()) .. status_fragment(results_group(session, _5_()), name))
end
local function loading_fragment(session)
  if M["loading-visible?"](session) then
    local word = "Working"
    local phase = (session["loading-anim-phase"] or 0)
    local center = ping_pong_center(phase, #word)
    local out = {}
    for i = 1, #word do
      local dist = math.abs((i - center))
      local hl
      if (dist == 0) then
        hl = "MetaLoading6"
      elseif (dist == 1) then
        hl = "MetaLoading5"
      elseif (dist == 2) then
        hl = "MetaLoading4"
      elseif (dist == 3) then
        hl = "MetaLoading3"
      elseif (dist == 4) then
        hl = "MetaLoading2"
      else
        hl = "MetaLoading1"
      end
      table.insert(out, status_fragment(hl, string.sub(word, i, i)))
    end
    return table.concat(out, "")
  else
    return ""
  end
end
local function status_flags_fragment(session)
  local parts = {}
  for _, item in ipairs(directive_mod["statusline-items"](session)) do
    local frag = project_flag_fragment(session, (item.label or ""), clj.boolean(item.active))
    if (#frag > 0) then
      table.insert(parts, frag)
    else
    end
  end
  if (#parts > 0) then
    return table.concat(parts, status_fragment(M["results-middle-group"](session), "  "))
  else
    return ""
  end
end
M["results-statusline-left"] = function(self)
  local session = self.session
  local buf = self.buf.buffer
  local modified_3f = (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified)
  local modified_fragment
  if modified_3f then
    modified_fragment = status_fragment(results_group(session, "MetaStatuslineIndicator"), "[+]")
  else
    modified_fragment = ""
  end
  local loading = loading_fragment(session)
  local debug = (self.debug_out or "")
  local parts = {}
  if (#modified_fragment > 0) then
    table.insert(parts, modified_fragment)
  else
  end
  if (#loading > 0) then
    table.insert(parts, loading)
  else
  end
  if (#debug > 0) then
    table.insert(parts, status_fragment(results_group(session, "MetaStatuslineIndicator"), debug))
  else
  end
  if (#parts == 0) then
    return ""
  else
    return (" " .. table.concat(parts, status_fragment(M["results-middle-group"](session), "  ")))
  end
end
M["results-statusline-right"] = function(self)
  local flags = status_flags_fragment(self.session)
  if (#flags > 0) then
    return (" " .. flags)
  else
    return ""
  end
end
local function nerd_font_enabled_3f()
  return ((vim.g["meta#nerd_font"] == true) or (vim.g["meta#nerd_font"] == 1) or (vim.g.have_nerd_font == true) or (vim.g.have_nerd_font == 1) or (vim.g.nerd_font == true) or (vim.g.nerd_font == 1))
end
local function statusline_mode_state()
  local m = (vim.api.nvim_get_mode().mode or "")
  if vim.startswith(m, "R") then
    local _16_
    if nerd_font_enabled_3f() then
      _16_ = "R"
    else
      _16_ = "Replace"
    end
    return {group = "Replace", label = _16_}
  elseif vim.startswith(m, "i") then
    local _18_
    if nerd_font_enabled_3f() then
      _18_ = "\240\157\144\136"
    else
      _18_ = "Insert"
    end
    return {group = "Insert", label = _18_}
  else
    local _20_
    if nerd_font_enabled_3f() then
      _20_ = "\240\157\151\161"
    else
      _20_ = "Normal"
    end
    return {group = "Normal", label = _20_}
  end
end
M["prompt-statusline-text"] = function(self)
  local mode_state = statusline_mode_state()
  local matcher = self.matcher().name
  local matcher_suffix = statusline_mod["title-case"](matcher)
  local case_mode = self.case()
  local case_suffix = statusline_mod["title-case"](case_mode)
  local hl_prefix
  if (self.buf["syntax-type"] == "meta") then
    hl_prefix = "Meta"
  else
    hl_prefix = "Buffer"
  end
  return string.format("%%#MetaStatuslineMode%s# %s %%#MetaStatuslineIndicator# %d/%d %%#MetaStatuslineMiddle#%%=%%#MetaStatuslineMatcher%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineCase%s# %s %%#MetaStatuslineKey#%s%%#MetaStatuslineSyntax%s# %s %%#MetaStatuslineKey#%s ", mode_state.group, mode_state.label, #self.buf.indices, self.buf["line-count"](), matcher_suffix, matcher, "C^", case_suffix, case_mode, "C-o", hl_prefix, self.syntax(), "Cs")
end
M["highlight-pattern->vim-query"] = function(pat)
  if (type(pat) == "string") then
    return pat
  elseif (type(pat) == "table") then
    local parts = {}
    for _, item in ipairs(pat) do
      local item_pat = (item.pattern or "")
      if (item_pat ~= "") then
        table.insert(parts, item_pat)
      else
      end
    end
    if (#parts > 0) then
      return table.concat(parts, "\\|")
    else
      return ""
    end
  else
    return ""
  end
end
local function ends_with_space_3f(s)
  local txt = (s or "")
  local n = #txt
  return ((n > 0) and (nil ~= string.find(string.sub(txt, n, n), "%s")))
end
local function last_token(s)
  local txt = (s or "")
  local n = #txt
  if ((n == 0) or ends_with_space_3f(txt)) then
    return nil
  else
    local start = (string.match(txt, ".*()%s%S+$") or 1)
    return string.sub(txt, start)
  end
end
M["bang-token-completed?"] = function(prev, next)
  local prev0 = (prev or "")
  local next0 = (next or "")
  local prev_n = #prev0
  local next_n = #next0
  local and_28_ = (prev_n > 0) and (next_n > prev_n) and vim.startswith(next0, prev0) and (string.sub(prev0, prev_n, prev_n) == "!")
  if and_28_ then
    local before
    if (prev_n > 1) then
      before = string.sub(prev0, (prev_n - 1), (prev_n - 1))
    else
      before = ""
    end
    and_28_ = ((before ~= "\\") and ((prev_n == 1) or (nil ~= string.find(before, "%s"))))
  end
  if and_28_ then
    local added = string.sub(next0, (prev_n + 1), (prev_n + 1))
    and_28_ = (nil ~= string.find(added, "%S"))
  end
  return and_28_
end
local function negation_growth_broadens_3f(prev, next)
  local prev0 = (prev or "")
  local next0 = (next or "")
  if ((prev0 == "") or not vim.startswith(next0, prev0) or (#next0 <= #prev0) or ends_with_space_3f(prev0)) then
    return false
  else
    local prev_tok = (last_token(prev0) or "")
    local next_tok = (last_token(next0) or "")
    local same_token_3f = ((prev_tok ~= "") and vim.startswith(next_tok, prev_tok))
    local unescaped_bang_3f = ((#prev_tok > 0) and (string.sub(prev_tok, 1, 1) == "!") and not vim.startswith(prev_tok, "\\!"))
    return (same_token_3f and unescaped_bang_3f)
  end
end
M["negation-growth-broadens?"] = negation_growth_broadens_3f
local function unescaped_negated_token_3f(tok)
  local t = (tok or "")
  return ((#t > 1) and (string.sub(t, 1, 1) == "!") and not vim.startswith(t, "\\!"))
end
M["deletion-broadens?"] = function(prev, next)
  local prev0 = (prev or "")
  local next0 = (next or "")
  if ((next0 == "") or not vim.startswith(prev0, next0) or (#next0 >= #prev0)) then
    return true
  else
    local prev_tok = (last_token(prev0) or "")
    local next_tok = (last_token(next0) or "")
    local same_token_3f = ((prev_tok ~= "") and (next_tok ~= "") and vim.startswith(prev_tok, next_tok))
    local negation_shrink_3f = (same_token_3f and unescaped_negated_token_3f(prev_tok) and unescaped_negated_token_3f(next_tok))
    return not negation_shrink_3f
  end
end
M["statusline-mode-state"] = statusline_mode_state
M["apply-lgrep-highlights!"] = function(self, delete_win_match, lgrep_match_ids)
  for _, id in ipairs((self[lgrep_match_ids] or {})) do
    delete_win_match(self.win.window, id)
  end
  self[lgrep_match_ids] = {}
  if (self.win and self.win.window and vim.api.nvim_win_is_valid(self.win.window)) then
    local out = {}
    for _, spec in ipairs(((self.session and self.session["last-parsed-query"] and self.session["last-parsed-query"]["lgrep-lines"]) or {})) do
      if (spec and (type(spec) == "table") and (vim.trim((spec.query or "")) ~= "")) then
        table.insert(out, vim.trim((spec.query or "")))
      else
      end
    end
    for _, q in ipairs(out) do
      local pat = ("\\V" .. util["escape-vim-pattern"](q))
      local ok,id = pcall(vim.fn.matchadd, "MetaSearchHitLgrep", pat, 215, -1, {window = self.win.window})
      if ok then
        table.insert(self[lgrep_match_ids], id)
      else
      end
    end
    return nil
  else
    return nil
  end
end
M["clear-all-highlights!"] = function(self, delete_win_match, lgrep_match_ids)
  do
    local matcher_mode = self.mode.matcher
    if matcher_mode then
      for _, m in ipairs(matcher_mode.candidates) do
        if m then
          pcall(m["remove-highlight"], m)
        else
        end
      end
    else
    end
  end
  for _, id in ipairs((self[lgrep_match_ids] or {})) do
    delete_win_match(self.win.window, id)
  end
  self[lgrep_match_ids] = {}
  return nil
end
return M
