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
local expand_mod = require("metabuffer.context.expand")
local helper_mod = require("metabuffer.meta.helpers")
local M = {}
local STATUS_PROGRESS = prompt_mod.STATUS_PROGRESS
local state_cases = state.cases
local state_syntax_types = state["syntax-types"]
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
    local function _14_(path)
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
    matches_all_queries_3f = _14_
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
local function attach_query_methods_21(self)
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
      local pat = helper_mod["highlight-pattern->vim-query"](pat0)
      if (pat == "") then
        return ""
      else
        return (caseprefix .. pat)
      end
    end
  end
  return self.vim_query
end
local function attach_statusline_method_21(self)
  self.refresh_statusline = function()
    if not (nvim_exiting_3f() or (self.session and (self.session["ui-hidden"] or self.session.closing))) then
      local mode_state = helper_mod["statusline-mode-state"]()
      local hl_prefix
      if (self.buf["syntax-type"] == "meta") then
        hl_prefix = "Meta"
      else
        hl_prefix = "Buffer"
      end
      self["status-win"]["set-statusline-state"](mode_state.group, mode_state.label, self.buf.name, #self.buf.indices, self.buf["line-count"](), self.selected_line(), helper_mod["results-statusline-left"](self), helper_mod["results-statusline-right"](self), self.matcher().name, self.case(), hl_prefix, self.syntax(), helper_mod["results-middle-group"](self.session))
      if (self.session and self.session["prompt-win"] and vim.api.nvim_win_is_valid(self.session["prompt-win"])) then
        local prompt_text = helper_mod["prompt-statusline-text"](self)
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
  return self.refresh_statusline
end
local function attach_lifecycle_methods_21(self, cond, clear_all_highlights, prompt_on_term)
  self["on-init"] = function()
    local function _37_()
      if self["project-mode"] then
        return project_display_name()
      else
        return metabuffer_display_name(self.buf.model)
      end
    end
    self.buf["set-name"](_37_())
    do
      local init_syntax = (vim.g["meta#syntax_on_init"] or "buffer")
      local function _38_()
        if (init_syntax == "meta") then
          return "meta"
        else
          return "buffer"
        end
      end
      self.buf["apply-syntax"](_38_())
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
  self["on-term"] = function(status)
    clear_all_highlights()
    return prompt_on_term(status)
  end
  self.store = function()
    return {text = self.text, ["caret-locus"] = self.caret["get-locus"](), ["selected-index"] = self.selected_index, ["matcher-index"] = self.mode.matcher.index, ["case-index"] = self.mode.case.index, ["syntax-index"] = self.mode.syntax.index, restored = true}
  end
  return self.store
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
      local or_42_ = pcall(vim.fn.matchdelete, id, win)
      if not or_42_ then
        local function _43_()
          return vim.fn.matchdelete(id)
        end
        or_42_ = pcall(vim.api.nvim_win_call, win, _43_)
      end
      return or_42_
    else
      return pcall(vim.fn.matchdelete, id)
    end
  end
  local function apply_lgrep_highlights()
    return helper_mod["apply-lgrep-highlights!"](self, delete_win_match, "_lgrep-match-ids")
  end
  local function clear_all_highlights()
    return helper_mod["clear-all-highlights!"](self, delete_win_match, "_lgrep-match-ids")
  end
  local function _45_(idx)
    local function _46_()
      if (idx.current() == "meta") then
        return "meta"
      else
        return "buffer"
      end
    end
    return self.buf["apply-syntax"](_46_())
  end
  self.mode = {matcher = modeindexer.new({all_matcher.new(), fuzzy_matcher.new(), regex_matcher.new()}, (cond["matcher-index"] or 1), {["on-leave"] = "remove-highlight"}), case = modeindexer.new(state_cases, (cond["case-index"] or 1), nil), syntax = modeindexer.new(state_syntax_types, (cond["syntax-index"] or 1), {["on-active"] = _45_})}
  self.text = (cond.text or "")
  if (self.text ~= "") then
    self["query-lines"] = {self.text}
  else
  end
  self.caret["set-locus"]((cond["caret-locus"] or #self.text))
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
      local _49_
      if prev_ignorecase then
        _49_ = "1"
      else
        _49_ = "0"
      end
      prev_cache_key = (prev_matcher_name .. "|" .. _49_ .. "|" .. (prev_text or ""))
      local line_count = #self.buf.content
      local cache_grew_3f = (line_count > self["_filter-cache-line-count"])
      local cache_shrank_3f = (line_count < self["_filter-cache-line-count"])
      local cache_reset_3f = cache_shrank_3f
      local cache_key
      local _51_
      if ignorecase then
        _51_ = "1"
      else
        _51_ = "0"
      end
      cache_key = (matcher_name .. "|" .. _51_ .. "|" .. effective_query)
      local content_version = (self.buf["content-version"] or 0)
      local content_changed_3f = (content_version ~= (self["_content-version-seen"] or 0))
      local reset0_3f = ((prev_text == "") or not vim.startswith(self.text, prev_text) or helper_mod["bang-token-completed?"](prev_text, self.text) or cache_grew_3f or cache_reset_3f or (self["_prev-ignorecase"] ~= ignorecase) or (self["_prev-matcher"] ~= matcher_name))
      local narrow_reuse_threshold = (vim.g.meta_narrow_reuse_threshold or 400)
      local narrow_reuse_3f = (reset0_3f and vim.startswith(self.text, prev_text) and (matcher_name == "all") and not helper_mod["negation-growth-broadens?"](prev_text, self.text) and (#prev_text > 0) and (#self.text > #prev_text) and (#prev_hits <= narrow_reuse_threshold))
      local shortened_3f = (#self.text < #prev_text)
      local broaden_on_delete_3f = (shortened_3f and helper_mod["deletion-broadens?"](prev_text, self.text))
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
      local or_65_ = (self.session and self.session["read-file-lines-cached"])
      if not or_65_ then
        local function _66_(path, _opts)
          return vim.fn.readfile(path)
        end
        or_65_ = _66_
      end
      expanded = expand_mod["expanded-indices"](self.session, file_filtered, refs, {mode = expansion_mode, ["read-file-lines-cached"] = or_65_, ["around-lines"] = (vim.g.meta_context_around_lines or 3), ["max-blocks"] = (vim.g.meta_context_max_blocks or 24), ["visible-source-indices"] = visible_source_indices})
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
  attach_query_methods_21(self)
  attach_statusline_method_21(self)
  attach_lifecycle_methods_21(self, cond, clear_all_highlights, prompt_on_term)
  self.on_init = self["on-init"]
  self.on_redraw = self["on-redraw"]
  self.on_update = self["on-update"]
  return self
end
return M
