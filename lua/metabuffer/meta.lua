-- [nfnl] fnl/metabuffer/meta.fnl
local prompt_mod = require("metabuffer.prompt.prompt")
local modeindexer = require("metabuffer.modeindexer")
local state = require("metabuffer.core.state")
local all_matcher = require("metabuffer.matcher.all")
local fuzzy_matcher = require("metabuffer.matcher.fuzzy")
local regex_matcher = require("metabuffer.matcher.regex")
local meta_buffer_mod = require("metabuffer.buffer.metabuffer")
local meta_window_mod = require("metabuffer.window.metawindow")
local util = require("metabuffer.util")
local M = {}
local function line_of_index(buf, idx)
  return (buf.indices[(idx + 1)] or 1)
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
    local _2_
    if nerd_font_enabled_3f() then
      _2_ = "R"
    else
      _2_ = "Replace"
    end
    return {group = "Replace", label = _2_}
  elseif vim.startswith(m, "i") then
    local _4_
    if nerd_font_enabled_3f() then
      _4_ = "\240\157\144\136"
    else
      _4_ = "Insert"
    end
    return {group = "Insert", label = _4_}
  else
    local _6_
    if nerd_font_enabled_3f() then
      _6_ = "\240\157\151\161"
    else
      _6_ = "Normal"
    end
    return {group = "Normal", label = _6_}
  end
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
  local and_12_ = (prev_n > 0) and (next_n > prev_n) and vim.startswith(next0, prev0) and (string.sub(prev0, prev_n, prev_n) == "!")
  if and_12_ then
    local before
    if (prev_n > 1) then
      before = string.sub(prev0, (prev_n - 1), (prev_n - 1))
    else
      before = ""
    end
    and_12_ = ((before ~= "\\") and ((prev_n == 1) or not not string.find(before, "%s")))
  end
  if and_12_ then
    local added = string.sub(next0, (prev_n + 1), (prev_n + 1))
    and_12_ = not not string.find(added, "%S")
  end
  return and_12_
end
local function ends_with_space_3f(s)
  local txt = (s or "")
  local n = #txt
  return ((n > 0) and not not string.find(string.sub(txt, n, n), "%s"))
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
  self.win = meta_window_mod.new(nvim, vim.api.nvim_get_current_win())
  self["status-win"] = self.win
  self.buf = meta_buffer_mod.new(nvim, vim.api.nvim_get_current_buf())
  self["_filter-cache"] = {}
  self["_filter-cache-line-count"] = #self.buf.content
  local prompt_on_term = self["on-term"]
  local function clear_all_highlights()
    local matcher_mode = self.mode.matcher
    if matcher_mode then
      for _, m in ipairs(matcher_mode.candidates) do
        if m then
          pcall(m["remove-highlight"], m)
        else
        end
      end
      return nil
    else
      return nil
    end
  end
  local function _21_(idx)
    local function _22_()
      if (idx.current() == "meta") then
        return "meta"
      else
        return "buffer"
      end
    end
    return self.buf["apply-syntax"](_22_())
  end
  self.mode = {matcher = modeindexer.new({all_matcher.new(), fuzzy_matcher.new(), regex_matcher.new()}, (cond["matcher-index"] or 1), {["on-leave"] = "remove-highlight"}), case = modeindexer.new(state.cases, (cond["case-index"] or 1), nil), syntax = modeindexer.new(state["syntax-types"], (cond["syntax-index"] or 1), {["on-active"] = _21_})}
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
    self.text = table.concat(active, " && ")
    return nil
  end
  self.selected_line = function()
    return line_of_index(self.buf, self.selected_index)
  end
  self.switch_mode = function(which)
    local mode_obj = self.mode[which]
    mode_obj.next()
    self._prev_text = ""
    return self["on-update"](prompt_mod.STATUS_PROGRESS)
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
    local mode_state = statusline_mode_state()
    local hl_prefix
    if (self.buf["syntax-type"] == "meta") then
      hl_prefix = "Meta"
    else
      hl_prefix = "Buffer"
    end
    self["status-win"]["set-statusline-state"](mode_state.group, mode_state.label, self.buf.name, #self.buf.indices, self.buf["line-count"](), self.selected_line(), self.debug_out, self.matcher().name, self.case(), hl_prefix, self.syntax())
    return vim.cmd("redrawstatus")
  end
  self["on-init"] = function()
    local function _29_()
      if self["project-mode"] then
        return project_display_name()
      else
        return metabuffer_display_name(self.buf.model)
      end
    end
    self.buf["set-name"](_29_())
    do
      local init_syntax = (vim.g["meta#syntax_on_init"] or "buffer")
      local function _30_()
        if (init_syntax == "meta") then
          return "meta"
        else
          return "buffer"
        end
      end
      self.buf["apply-syntax"](_30_())
    end
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
    return prompt_mod.STATUS_PROGRESS
  end
  self["on-redraw"] = function()
    self.refresh_statusline()
    self["redraw-prompt"]()
    return prompt_mod.STATUS_PROGRESS
  end
  self["on-update"] = function(status)
    do
      local queries = self["active-queries"]()
      local prev_text = self._prev_text
      local prev_hits = self.buf.indices
      local prev_line = line_of_index(self.buf, self.selected_index)
      local effective_query = table.concat(queries, "\n")
      local matcher_name = self.matcher().name
      local ignorecase = self.ignorecase()
      local line_count = #self.buf.content
      local cache_grew_3f = (line_count > self["_filter-cache-line-count"])
      local cache_shrank_3f = (line_count < self["_filter-cache-line-count"])
      local cache_reset_3f = cache_shrank_3f
      local cache_key
      local _34_
      if ignorecase then
        _34_ = "1"
      else
        _34_ = "0"
      end
      cache_key = (matcher_name .. "|" .. _34_ .. "|" .. effective_query)
      local reset0_3f = ((prev_text == "") or not vim.startswith(self.text, prev_text) or bang_token_completed_3f(prev_text, self.text) or cache_grew_3f or cache_reset_3f or (self["_prev-ignorecase"] ~= ignorecase) or (self["_prev-matcher"] ~= matcher_name))
      local narrow_reuse_threshold = (vim.g.meta_narrow_reuse_threshold or 400)
      local narrow_reuse_3f = (reset0_3f and vim.startswith(self.text, prev_text) and (matcher_name == "all") and not negation_growth_broadens_3f(prev_text, self.text) and (#prev_text > 0) and (#self.text > #prev_text) and (#prev_hits <= narrow_reuse_threshold))
      local shortened_3f = (#self.text < #prev_text)
      local broaden_on_delete_3f = (shortened_3f and deletion_broadens_3f(prev_text, self.text))
      local reset_3f = (reset0_3f and not narrow_reuse_3f and (not shortened_3f or broaden_on_delete_3f))
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
          local next0 = vim.deepcopy(cached)
          local next = next0
          if (cached_line_count < line_count) then
            local added0 = {}
            local added = added0
            for i = (cached_line_count + 1), line_count do
              table.insert(added, i)
            end
            for _, q in ipairs(queries) do
              added = matcher.filter(matcher, q, added, self.buf.content, ignorecase)
            end
            for _, idx in ipairs(added) do
              table.insert(next, idx)
            end
            cached_line_count = line_count
          else
          end
          self.buf.indices = vim.deepcopy(next)
          self["_filter-cache"][cache_key] = {indices = vim.deepcopy(next), ["line-count"] = line_count, full = true}
        else
          local first = reset_3f
          for _, q in ipairs(queries) do
            self.buf["run-filter"](matcher, q, ignorecase, first, self.win.window)
            first = false
          end
          if reset_3f then
            self["_filter-cache"][cache_key] = {indices = vim.deepcopy(self.buf.indices), ["line-count"] = line_count, full = true}
          else
          end
        end
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
      local needs_render_3f = (hits_changed or broaden_on_delete_3f)
      if needs_render_3f then
        self.buf.render()
      else
      end
      if needs_render_3f then
        local idx = nil
        for i, src in ipairs(self.buf.indices) do
          if (not idx and (src == prev_line)) then
            idx = i
          else
          end
        end
        if not idx then
          idx = self.buf["closest-index"](prev_line)
        else
        end
        if idx then
          self.selected_index = (idx - 1)
          if vim.api.nvim_win_is_valid(self.win.window) then
            vim.api.nvim_win_set_cursor(self.win.window, {idx, 0})
          else
          end
        else
        end
      else
      end
      local matcher = self.matcher()
      for _, m in ipairs(self.mode.matcher.candidates) do
        if (m and (m ~= matcher)) then
          m["remove-highlight"](m)
        else
        end
      end
      local highlight_max_hits = (vim.g.meta_highlight_max_hits or 20000)
      if ((#queries == 0) or (#self.buf.indices >= highlight_max_hits)) then
        matcher["remove-highlight"](matcher)
      else
        matcher.highlight(matcher, effective_query, ignorecase, self.win.window)
      end
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
