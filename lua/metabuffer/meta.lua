-- [nfnl] fnl/metabuffer/meta.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local prompt_mod = require("metabuffer.prompt.prompt")
local modeindexer = require("metabuffer.modeindexer")
local state = require("metabuffer.core.state")
local all_matcher = require("metabuffer.matcher.all")
local fuzzy_matcher = require("metabuffer.matcher.fuzzy")
local regex_matcher = require("metabuffer.matcher.regex")
local meta_buffer_mod = require("metabuffer.buffer.metabuffer")
local meta_window_mod = require("metabuffer.window.metawindow")
local statusline_mod = require("metabuffer.window.statusline")
local expand_mod = require("metabuffer.context.expand")
local directive_mod = require("metabuffer.query.directive")
local util = require("metabuffer.util")
local M = {}
local STATUS_PROGRESS = prompt_mod.STATUS_PROGRESS
local state_cases = state.cases
local state_syntax_types = state["syntax-types"]
local function session_busy_3f(session)
  return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["lazy-stream-done"]) or (session["project-mode"] and not session["project-bootstrapped"])))
end
local function loading_visible_3f(session)
  return (session and session["loading-indicator?"] and (session_busy_3f(session) or (session["loading-anim-phase"] ~= nil) or session["loading-idle-pending"]))
end
local function results_middle_group(session)
  return ((session and session["results-statusline-pulse-active?"] and "MetaStatuslineMiddlePulse") or "MetaStatuslineMiddle")
end
local function nvim_exiting_3f()
  local v = (vim.v and vim.v.exiting)
  return ((v ~= nil) and (v ~= vim.NIL) and (v ~= 0) and (v ~= ""))
end
local function main_visible_source_indices(self, base_indices, rendered_indices)
  local win = (self and self.win and self.win.window)
  local total = #(base_indices or {})
  if ((total <= 0) or not win or not vim.api.nvim_win_is_valid(win)) then
    return {}
  else
    local view
    local function _1_()
      return vim.fn.winsaveview()
    end
    view = vim.api.nvim_win_call(win, _1_)
    local top = math.max(1, math.min(total, (view.topline or 1)))
    local height = math.max(1, vim.api.nvim_win_get_height(win))
    local stop = math.min(math.max(1, #(rendered_indices or {})), (top + height + -1))
    local base_ranks
    do
      local out0 = {}
      for i, src in ipairs((base_indices or {})) do
        if (src and (out0[src] == nil)) then
          out0[src] = i
        else
        end
      end
      base_ranks = out0
    end
    local out = {}
    if (stop > 0) then
      for i, src in ipairs((rendered_indices or {})) do
        if ((i >= top) and (i <= stop)) then
          local val_110_auto = base_ranks[src]
          if val_110_auto then
            local rank = val_110_auto
            table.insert(out, base_indices[rank])
          else
          end
        else
        end
      end
    else
    end
    if (#out > 0) then
      return out
    else
      local fallback_stop = math.min(total, (top + height + -1))
      local fallback = {}
      for i = top, fallback_stop do
        local src = base_indices[i]
        if src then
          table.insert(fallback, src)
        else
        end
      end
      return fallback
    end
  end
end
local function results_group(session, group)
  return ((session and session["results-statusline-pulse-active?"] and (group .. "Pulse")) or group)
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
local function project_flag_fragment(session, name, on_3f)
  local function _12_()
    if on_3f then
      return "+"
    else
      return "-"
    end
  end
  local function _13_()
    if on_3f then
      return "MetaStatuslineFlagOn"
    else
      return "MetaStatuslineFlagOff"
    end
  end
  return (status_fragment(results_group(session, "MetaStatuslineKey"), _12_()) .. status_fragment(results_group(session, _13_()), name))
end
local function loading_fragment(session)
  if loading_visible_3f(session) then
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
    return table.concat(parts, status_fragment(results_middle_group(session), "  "))
  else
    return ""
  end
end
local function results_statusline_left(self)
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
    return (" " .. table.concat(parts, status_fragment(results_middle_group(session), "  ")))
  end
end
local function results_statusline_right(self)
  local flags = status_flags_fragment(self.session)
  if (#flags > 0) then
    return (" " .. flags)
  else
    return ""
  end
end
local function line_of_index(buf, idx)
  return (buf.indices[(idx + 1)] or 1)
end
local function union_query_indices(matcher, queries, candidates, ignorecase)
  local seen = {}
  local out = {}
  for _, q in ipairs((queries or {})) do
    local hits = matcher.filter(matcher, q, vim.fn.range(1, #candidates), candidates, ignorecase)
    for _0, idx in ipairs(hits) do
      if not seen[idx] then
        seen[idx] = true
        table.insert(out, idx)
      else
      end
    end
  end
  table.sort(out)
  return out
end
local function ref_is_file_entry_3f(ref)
  return (((ref and ref.kind) or "") == "file-entry")
end
local function file_query_matches_3f(path, q, ignorecase)
  local probe0 = (path or "")
  local probe
  if ignorecase then
    probe = string.lower(probe0)
  else
    probe = probe0
  end
  local query0 = vim.trim((q or ""))
  local query
  if ignorecase then
    query = string.lower(query0)
  else
    query = query0
  end
  if (query == "") then
    return true
  else
    return (nil ~= string.find(probe, query, 1, true))
  end
end
local function apply_file_entry_filter(indices, refs, file_query_lines, ignorecase, include_files, regular_query_active_3f)
  if not include_files then
    return indices
  else
    local queries0 = {}
    for _, q in ipairs((file_query_lines or {})) do
      local trimmed = vim.trim((q or ""))
      if (trimmed ~= "") then
        table.insert(queries0, trimmed)
      else
      end
    end
    local queries = queries0
    local matches_all_queries_3f
    local function _29_(path)
      if (#queries == 0) then
        return true
      else
        local path0 = (path or "")
        local rel
        if (path0 ~= "") then
          rel = vim.fn.fnamemodify(path0, ":.")
        else
          rel = ""
        end
        local probe
        if (rel ~= "") then
          probe = (rel .. " " .. path0)
        else
          probe = path0
        end
        local ok0 = true
        local ok = ok0
        for _, q in ipairs(queries) do
          if (ok and not file_query_matches_3f(probe, q, ignorecase)) then
            ok = false
          else
          end
        end
        return ok
      end
    end
    matches_all_queries_3f = _29_
    local regular_set = {}
    local file_set = {}
    local regular_allowed_3f = (regular_query_active_3f or (#queries == 0))
    for _, idx in ipairs((indices or {})) do
      local ref = refs[idx]
      if ref_is_file_entry_3f(ref) then
      else
        if regular_allowed_3f then
          if matches_all_queries_3f((ref and ref.path)) then
            regular_set[idx] = true
          else
          end
        else
          regular_set[idx] = true
        end
      end
    end
    for idx = 1, #refs do
      local ref = refs[idx]
      if ref_is_file_entry_3f(ref) then
        if (#queries == 0) then
          file_set[idx] = true
        else
          local path0 = ((ref and ref.path) or "")
          local rel
          if (path0 ~= "") then
            rel = vim.fn.fnamemodify(path0, ":.")
          else
            rel = ""
          end
          local path = ((ref and ref.line) or rel or path0 or "")
          if matches_all_queries_3f(path) then
            file_set[idx] = true
          else
          end
        end
      else
      end
    end
    local next = {}
    for idx = 1, #refs do
      if (regular_set[idx] or file_set[idx]) then
        table.insert(next, idx)
      else
      end
    end
    return next
  end
end
local function metabuffer_display_name(model_buf)
  local original_name = vim.api.nvim_buf_get_name(model_buf)
  local base_name
  if ((type(original_name) == "string") and (original_name ~= "")) then
    base_name = vim.fn.fnamemodify(original_name, ":t")
  else
    base_name = "[No Name]"
  end
  return (base_name .. " \226\128\162 Metabuffer")
end
local function project_display_name()
  return "Metabuffer"
end
local function nerd_font_enabled_3f()
  return ((vim.g["meta#nerd_font"] == true) or (vim.g["meta#nerd_font"] == 1) or (vim.g.have_nerd_font == true) or (vim.g.have_nerd_font == 1) or (vim.g.nerd_font == true) or (vim.g.nerd_font == 1))
end
local function statusline_mode_state()
  local m = (vim.api.nvim_get_mode().mode or "")
  if vim.startswith(m, "R") then
    local _44_
    if nerd_font_enabled_3f() then
      _44_ = "R"
    else
      _44_ = "Replace"
    end
    return {group = "Replace", label = _44_}
  elseif vim.startswith(m, "i") then
    local _46_
    if nerd_font_enabled_3f() then
      _46_ = "\240\157\144\136"
    else
      _46_ = "Insert"
    end
    return {group = "Insert", label = _46_}
  else
    local _48_
    if nerd_font_enabled_3f() then
      _48_ = "\240\157\151\161"
    else
      _48_ = "Normal"
    end
    return {group = "Normal", label = _48_}
  end
end
local function prompt_statusline_text(self)
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
local function highlight_pattern__3evim_query(pat)
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
local function bang_token_completed_3f(prev, next)
  local prev0 = (prev or "")
  local next0 = (next or "")
  local prev_n = #prev0
  local next_n = #next0
  local and_55_ = (prev_n > 0) and (next_n > prev_n) and vim.startswith(next0, prev0) and (string.sub(prev0, prev_n, prev_n) == "!")
  if and_55_ then
    local before
    if (prev_n > 1) then
      before = string.sub(prev0, (prev_n - 1), (prev_n - 1))
    else
      before = ""
    end
    and_55_ = ((before ~= "\\") and ((prev_n == 1) or (nil ~= string.find(before, "%s"))))
  end
  if and_55_ then
    local added = string.sub(next0, (prev_n + 1), (prev_n + 1))
    and_55_ = (nil ~= string.find(added, "%S"))
  end
  return and_55_
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
local function unescaped_negated_token_3f(tok)
  local t = (tok or "")
  return ((#t > 1) and (string.sub(t, 1, 1) == "!") and not vim.startswith(t, "\\!"))
end
local function deletion_broadens_3f(prev, next)
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
M.new = function(nvim, condition)
  local cond = (condition or state["default-condition"](""))
  local self = prompt_mod.new(nvim)
  self.condition = cond
  self.selected_index = (cond["selected-index"] or 0)
  self._prev_text = ""
  self.updates = 0
  self.debug_out = ""
  self.prefix = "# "
  self["query-lines"] = {}
  self["_prev-ignorecase"] = nil
  self["_prev-matcher"] = nil
  self["_selection-cache"] = {}
  self["_lgrep-match-ids"] = {}
  self.win = meta_window_mod.new(nvim, vim.api.nvim_get_current_win())
  self["status-win"] = self.win
  self.buf = meta_buffer_mod.new(nvim, vim.api.nvim_get_current_buf())
  self["_filter-cache"] = {}
  self["_filter-cache-line-count"] = #self.buf.content
  self["_content-version-seen"] = (self.buf["content-version"] or 0)
  local prompt_on_term = self["on-term"]
  local function delete_win_match(win, id)
    if (win and vim.api.nvim_win_is_valid(win)) then
      local or_62_ = pcall(vim.fn.matchdelete, id, win)
      if not or_62_ then
        local function _63_()
          return vim.fn.matchdelete(id)
        end
        or_62_ = pcall(vim.api.nvim_win_call, win, _63_)
      end
      return or_62_
    else
      return pcall(vim.fn.matchdelete, id)
    end
  end
  local function lgrep_queries()
    local out = {}
    for _, spec in ipairs(((self.session and self.session["last-parsed-query"] and self.session["last-parsed-query"]["lgrep-lines"]) or {})) do
      if (spec and (type(spec) == "table") and (vim.trim((spec.query or "")) ~= "")) then
        table.insert(out, vim.trim((spec.query or "")))
      else
      end
    end
    return out
  end
  local function apply_lgrep_highlights()
    for _, id in ipairs((self["_lgrep-match-ids"] or {})) do
      delete_win_match(self.win.window, id)
    end
    self["_lgrep-match-ids"] = {}
    if (self.win and self.win.window and vim.api.nvim_win_is_valid(self.win.window)) then
      for _, q in ipairs(lgrep_queries()) do
        local pat = ("\\V" .. util["escape-vim-pattern"](q))
        local ok,id = pcall(vim.fn.matchadd, "MetaSearchHitLgrep", pat, 215, -1, {window = self.win.window})
        if ok then
          table.insert(self["_lgrep-match-ids"], id)
        else
        end
      end
      return nil
    else
      return nil
    end
  end
  local function clear_all_highlights()
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
    for _, id in ipairs((self["_lgrep-match-ids"] or {})) do
      delete_win_match(self.win.window, id)
    end
    self["_lgrep-match-ids"] = {}
    return nil
  end
  local function _70_(idx)
    local function _71_()
      if (idx.current() == "meta") then
        return "meta"
      else
        return "buffer"
      end
    end
    return self.buf["apply-syntax"](_71_())
  end
  self.mode = {matcher = modeindexer.new({all_matcher.new(), fuzzy_matcher.new(), regex_matcher.new()}, (cond["matcher-index"] or 1), {["on-leave"] = "remove-highlight"}), case = modeindexer.new(state_cases, (cond["case-index"] or 1), nil), syntax = modeindexer.new(state_syntax_types, (cond["syntax-index"] or 1), {["on-active"] = _70_})}
  self.text = (cond.text or "")
  if (self.text ~= "") then
    self["query-lines"] = {self.text}
  else
  end
  self.caret["set-locus"]((cond["caret-locus"] or #self.text))
  self.matcher = function()
    return self.mode.matcher.current()
  end
  self.case = function()
    return self.mode.case.current()
  end
  self.syntax = function()
    return self.mode.syntax.current()
  end
  self.ignorecase = function()
    return state.ignorecase(self.case(), self.text)
  end
  self["active-queries"] = function()
    local out = {}
    for _, line in ipairs((self["query-lines"] or {})) do
      if ((type(line) == "string") and (vim.trim(line) ~= "")) then
        table.insert(out, vim.trim(line))
      else
      end
    end
    return out
  end
  self["set-query-lines"] = function(lines)
    self["query-lines"] = (lines or {})
    local active = self["active-queries"]()
    self.text = table.concat(active, "\n")
    return nil
  end
  self.selected_line = function()
    return line_of_index(self.buf, self.selected_index)
  end
  self.switch_mode = function(which)
    local mode_obj = self.mode[which]
    mode_obj.next()
    self._prev_text = ""
    return self["on-update"](STATUS_PROGRESS)
  end
  self.vim_query = function()
    local active = self["active-queries"]()
    local q = active[#active]
    if (not q or (q == "")) then
      return ""
    else
      local caseprefix
      if self.ignorecase() then
        caseprefix = "\\c"
      else
        caseprefix = "\\C"
      end
      local matcher_obj = self.matcher()
      local pat0 = matcher_obj["get-highlight-pattern"](matcher_obj, q)
      local pat = highlight_pattern__3evim_query(pat0)
      if (pat == "") then
        return ""
      else
        return (caseprefix .. pat)
      end
    end
  end
  self.refresh_statusline = function()
    if not (nvim_exiting_3f() or (self.session and (self.session["ui-hidden"] or self.session.closing))) then
      local mode_state = statusline_mode_state()
      local hl_prefix
      if (self.buf["syntax-type"] == "meta") then
        hl_prefix = "Meta"
      else
        hl_prefix = "Buffer"
      end
      self["status-win"]["set-statusline-state"](mode_state.group, mode_state.label, self.buf.name, #self.buf.indices, self.buf["line-count"](), self.selected_line(), results_statusline_left(self), results_statusline_right(self), self.matcher().name, self.case(), hl_prefix, self.syntax(), results_middle_group(self.session))
      if (self.session and self.session["prompt-win"] and vim.api.nvim_win_is_valid(self.session["prompt-win"])) then
        local prompt_text = prompt_statusline_text(self)
        if (self.session["_last-prompt-statusline"] ~= prompt_text) then
          self.session["_last-prompt-statusline"] = prompt_text
          pcall(vim.api.nvim_set_option_value, "statusline", prompt_text, {win = self.session["prompt-win"]})
        else
        end
      else
      end
      return vim.cmd("redrawstatus")
    else
      return nil
    end
  end
  self["on-init"] = function()
    local function _81_()
      if self["project-mode"] then
        return project_display_name()
      else
        return metabuffer_display_name(self.buf.model)
      end
    end
    self.buf["set-name"](_81_())
    do
      local init_syntax = (vim.g["meta#syntax_on_init"] or "buffer")
      local function _82_()
        if (init_syntax == "meta") then
          return "meta"
        else
          return "buffer"
        end
      end
      self.buf["apply-syntax"](_82_())
    end
    self.buf["visible-source-syntax-only"] = clj.boolean(cond["project-mode"])
    clear_all_highlights()
    self.buf.render()
    do
      local line_count = vim.api.nvim_buf_line_count(self.buf.buffer)
      local line = math.max(1, math.min((self.selected_index + 1), line_count))
      local source_view = (cond["source-view"] or {})
      local source_lnum = (source_view.lnum or line)
      local source_topline = (source_view.topline or source_lnum)
      local offset = math.max(0, (source_lnum - source_topline))
      local topline = math.max(1, math.min((line - offset), line_count))
      if vim.api.nvim_win_is_valid(self.win.window) then
        local view = vim.fn.winsaveview()
        view["lnum"] = line
        view["topline"] = topline
        if (source_view.leftcol ~= nil) then
          view["leftcol"] = source_view.leftcol
        else
        end
        if (source_view.col ~= nil) then
          view["col"] = source_view.col
        else
        end
        vim.fn.winrestview(view)
      else
      end
    end
    return STATUS_PROGRESS
  end
  self["on-redraw"] = function()
    self.refresh_statusline()
    self["redraw-prompt"]()
    return STATUS_PROGRESS
  end
  self["on-update"] = function(status)
    do
      local queries = self["active-queries"]()
      local prev_text = self._prev_text
      local prev_hits = vim.deepcopy((self.buf.indices or {}))
      local prev_rank = math.max(1, (self.selected_index + 1))
      local prev_line = line_of_index(self.buf, self.selected_index)
      local anchor_line = (((#prev_hits == 0) and self["_no-hits-anchor-line"]) or prev_line)
      local effective_query = table.concat(queries, "\n")
      local matcher_name = self.matcher().name
      local ignorecase = self.ignorecase()
      local prev_ignorecase
      if (self["_prev-ignorecase"] == nil) then
        prev_ignorecase = ignorecase
      else
        prev_ignorecase = self["_prev-ignorecase"]
      end
      local prev_matcher_name = (self["_prev-matcher"] or matcher_name)
      local prev_cache_key
      local _87_
      if prev_ignorecase then
        _87_ = "1"
      else
        _87_ = "0"
      end
      prev_cache_key = (prev_matcher_name .. "|" .. _87_ .. "|" .. (prev_text or ""))
      local line_count = #self.buf.content
      local cache_grew_3f = (line_count > self["_filter-cache-line-count"])
      local cache_shrank_3f = (line_count < self["_filter-cache-line-count"])
      local cache_reset_3f = cache_shrank_3f
      local cache_key
      local _89_
      if ignorecase then
        _89_ = "1"
      else
        _89_ = "0"
      end
      cache_key = (matcher_name .. "|" .. _89_ .. "|" .. effective_query)
      local content_version = (self.buf["content-version"] or 0)
      local content_changed_3f = (content_version ~= (self["_content-version-seen"] or 0))
      local reset0_3f = ((prev_text == "") or not vim.startswith(self.text, prev_text) or bang_token_completed_3f(prev_text, self.text) or cache_grew_3f or cache_reset_3f or (self["_prev-ignorecase"] ~= ignorecase) or (self["_prev-matcher"] ~= matcher_name))
      local narrow_reuse_threshold = (vim.g.meta_narrow_reuse_threshold or 400)
      local narrow_reuse_3f = (reset0_3f and vim.startswith(self.text, prev_text) and (matcher_name == "all") and not negation_growth_broadens_3f(prev_text, self.text) and (#prev_text > 0) and (#self.text > #prev_text) and (#prev_hits <= narrow_reuse_threshold))
      local shortened_3f = (#self.text < #prev_text)
      local broaden_on_delete_3f = (shortened_3f and deletion_broadens_3f(prev_text, self.text))
      local reset_3f = (reset0_3f and not narrow_reuse_3f and (not shortened_3f or broaden_on_delete_3f))
      self["_selection-cache"][prev_cache_key] = anchor_line
      if cache_reset_3f then
        self["_filter-cache"] = {}
        self["_filter-cache-line-count"] = line_count
      else
      end
      if cache_grew_3f then
        self["_filter-cache-line-count"] = line_count
      else
      end
      self._prev_text = self.text
      self["_prev-ignorecase"] = ignorecase
      self["_prev-matcher"] = matcher_name
      self.updates = (self.updates + 1)
      if broaden_on_delete_3f then
        self.buf["reset-filter"]()
      else
      end
      if (#queries == 0) then
        self.buf["reset-filter"]()
        clear_all_highlights()
      else
        local cached0 = self["_filter-cache"][cache_key]
        local cached_obj_3f = ((type(cached0) == "table") and (type(cached0.indices) == "table"))
        local cached_full_3f = (cached_obj_3f and (cached0.full == true))
        local cached
        if (cached_obj_3f and not shortened_3f) then
          if cached_full_3f then
            cached = cached0.indices
          else
            cached = nil
          end
        else
          cached = nil
        end
        local cached_line_count0
        if cached_obj_3f then
          cached_line_count0 = (cached0["line-count"] or line_count)
        else
          cached_line_count0 = self["_filter-cache-line-count"]
        end
        local matcher = self.matcher()
        if cached then
          local cached_line_count = cached_line_count0
          local next = vim.deepcopy(cached)
          local seen = {}
          for _, idx in ipairs(next) do
            seen[idx] = true
          end
          if (cached_line_count < line_count) then
            local added_candidates = {}
            for i = (cached_line_count + 1), line_count do
              table.insert(added_candidates, self.buf.content[i])
            end
            do
              local added_hits = union_query_indices(matcher, queries, added_candidates, ignorecase)
              for _, rel_idx in ipairs(added_hits) do
                local idx = (cached_line_count + rel_idx)
                if not seen[idx] then
                  seen[idx] = true
                  table.insert(next, idx)
                else
                end
              end
            end
            cached_line_count = line_count
          else
          end
          self.buf.indices = vim.deepcopy(next)
          self["_filter-cache"][cache_key] = {indices = vim.deepcopy(next), ["line-count"] = line_count, full = true}
        else
          self.buf.indices = union_query_indices(matcher, queries, self.buf.content, ignorecase)
          if reset_3f then
            self["_filter-cache"][cache_key] = {indices = vim.deepcopy(self.buf.indices), ["line-count"] = line_count, full = true}
          else
          end
        end
      end
      local refs = (self.buf["source-refs"] or {})
      local expansion_mode = ((self.session and self.session["expansion-mode"]) or "none")
      local file_filtered = apply_file_entry_filter(self.buf.indices, refs, self["file-query-lines"], ignorecase, self["include-files"], (#queries > 0))
      local visible_source_indices
      if (expansion_mode == "none") then
        visible_source_indices = {}
      else
        visible_source_indices = main_visible_source_indices(self, file_filtered, prev_hits)
      end
      local expanded
      local or_103_ = (self.session and self.session["read-file-lines-cached"])
      if not or_103_ then
        local function _104_(path, _opts)
          return vim.fn.readfile(path)
        end
        or_103_ = _104_
      end
      expanded = expand_mod["expanded-indices"](self.session, file_filtered, refs, {mode = expansion_mode, ["read-file-lines-cached"] = or_103_, ["around-lines"] = (vim.g.meta_context_around_lines or 3), ["max-blocks"] = (vim.g.meta_context_max_blocks or 24), ["visible-source-indices"] = visible_source_indices})
      local _
      self.buf.indices = expanded
      _ = nil
      local _0
      if (#self.buf.indices == 0) then
        self["_no-hits-anchor-line"] = anchor_line
        _0 = nil
      else
        self["_no-hits-anchor-line"] = nil
        _0 = nil
      end
      local hits_changed
      if (prev_hits == self.buf.indices) then
        hits_changed = false
      else
        if (#prev_hits ~= #self.buf.indices) then
          hits_changed = true
        else
          hits_changed = not vim.deep_equal(prev_hits, self.buf.indices)
        end
      end
      local needs_render_3f = (hits_changed or broaden_on_delete_3f or content_changed_3f)
      if needs_render_3f then
        self.buf.render()
      else
      end
      self["_content-version-seen"] = content_version
      if needs_render_3f then
        local preferred_line = (self["_selection-cache"][cache_key] or anchor_line)
        local preferred_rank = math.max(1, math.min(prev_rank, #self.buf.indices))
        local idx = nil
        if broaden_on_delete_3f then
          idx = preferred_rank
        else
          for i, src in ipairs(self.buf.indices) do
            if (not idx and (src == preferred_line)) then
              idx = i
            else
            end
          end
          if not idx then
            idx = self.buf["closest-index"](preferred_line)
          else
          end
        end
        if idx then
          self.selected_index = (idx - 1)
          self["_selection-cache"][cache_key] = line_of_index(self.buf, self.selected_index)
          if vim.api.nvim_win_is_valid(self.win.window) then
            vim.api.nvim_win_set_cursor(self.win.window, {idx, 0})
          else
          end
        else
        end
      else
      end
      local matcher = self.matcher()
      for _1, m in ipairs(self.mode.matcher.candidates) do
        if (m and (m ~= matcher)) then
          m["remove-highlight"](m)
        else
        end
      end
      do
        local highlight_max_hits = (vim.g.meta_highlight_max_hits or 40000)
        if ((#queries == 0) or (#self.buf.indices >= highlight_max_hits)) then
          matcher["remove-highlight"](matcher)
        else
          matcher.highlight(matcher, queries, ignorecase, self.win.window)
        end
      end
      apply_lgrep_highlights()
    end
    return status
  end
  self["on-term"] = function(status)
    clear_all_highlights()
    return prompt_on_term(status)
  end
  self.on_init = self["on-init"]
  self.on_redraw = self["on-redraw"]
  self.on_update = self["on-update"]
  self.store = function()
    return {text = self.text, ["caret-locus"] = self.caret["get-locus"](), ["selected-index"] = self.selected_index, ["matcher-index"] = self.mode.matcher.index, ["case-index"] = self.mode.case.index, ["syntax-index"] = self.mode.syntax.index, restored = true}
  end
  return self
end
return M
