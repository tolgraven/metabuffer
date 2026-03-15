-- [nfnl] fnl/metabuffer/buffer/metabuffer.fnl
local base = require("metabuffer.buffer.base")
local ui = require("metabuffer.buffer.ui")
local query_mod = require("metabuffer.query")
local source_mod = require("metabuffer.source")
local util = require("metabuffer.util")
local M = {}
M["default-opts"] = {bufhidden = "hide", buftype = "nofile", buflisted = false}
local function icon_field(icon)
  if ((type(icon) == "string") and (icon ~= "")) then
    local text = (icon .. " ")
    return {text = text, width = vim.fn.strdisplaywidth(text)}
  else
    return {text = "", width = 0}
  end
end
local function split_source_path(path)
  local p = (path or "")
  local rel
  if (p ~= "") then
    rel = vim.fn.fnamemodify(p, ":~:.")
  else
    rel = "[Current Buffer]"
  end
  local dir = vim.fn.fnamemodify(rel, ":h")
  local file = vim.fn.fnamemodify(rel, ":t")
  local dir_part
  if (dir and (dir ~= ".") and (dir ~= "")) then
    dir_part = (dir .. "/")
  else
    dir_part = ""
  end
  return {dir = dir_part, file = file}
end
local function source_prefix(ref)
  return source_mod["hit-prefix"](ref)
end
local function sanitize_syntax_id(s)
  local base0 = (s or "text")
  local cleaned = string.gsub(base0, "[^%w_]", "_")
  if (cleaned == "") then
    return "text"
  else
    return cleaned
  end
end
local function syntax_files_for_ft(ft)
  local files = {}
  local base0 = vim.api.nvim_get_runtime_file(("syntax/" .. ft .. ".vim"), true)
  local after = vim.api.nvim_get_runtime_file(("after/syntax/" .. ft .. ".vim"), true)
  for _, f in ipairs(base0) do
    table.insert(files, f)
  end
  for _, f in ipairs(after) do
    table.insert(files, f)
  end
  return files
end
local function apply_ft_buffer_vars_21(buf, ft)
  if (buf and vim.api.nvim_buf_is_valid(buf) and (ft == "fennel")) then
    pcall(vim.api.nvim_buf_set_var, buf, "fennel_lua_version", "5.1")
    local function _5_()
      if jit then
        return 1
      else
        return 0
      end
    end
    return pcall(vim.api.nvim_buf_set_var, buf, "fennel_use_luajit", _5_())
  else
    return nil
  end
end
local function normalize_render_line(line)
  local txt = tostring((line or ""))
  local s1 = string.gsub(txt, "\r\n", " ")
  local s2 = string.gsub(s1, "\n", " ")
  local s3 = string.gsub(s2, "\r", " ")
  return s3
end
local function set_bvar_21(buf, name, value)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    return pcall(vim.api.nvim_buf_set_var, buf, name, value)
  else
    return nil
  end
end
local function bvar(buf, name, default)
  local ok,v = pcall(vim.api.nvim_buf_get_var, buf, name)
  if ok then
    return v
  else
    return default
  end
end
local function session_has_pending_work(self)
  local session = self.model.session
  return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["lazy-refresh-pending"] or session["lazy-refresh-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["project-bootstrapped"])))
end
local function session_has_active_query(self)
  local session = self.model.session
  local parsed = (session and session["last-parsed-query"])
  return (parsed and query_mod["query-lines-has-active?"]((parsed.lines or {})))
end
local function should_defer_empty_frame(self, frame)
  return ((#(frame.lines or {}) == 0) and (#(self["last-rendered-lines"] or {}) > 0) and not session_has_active_query(self) and session_has_pending_work(self))
end
local function save_window_views(self)
  local views = {}
  for _, win in ipairs(vim.fn.win_findbuf(self.buffer)) do
    if vim.api.nvim_win_is_valid(win) then
      local function _9_()
        return vim.fn.winsaveview()
      end
      views[win] = vim.api.nvim_win_call(win, _9_)
    else
    end
  end
  return views
end
local function restore_window_views(views)
  for win, view in pairs(views) do
    if vim.api.nvim_win_is_valid(win) then
      local function _11_()
        return pcall(vim.fn.winrestview, view)
      end
      vim.api.nvim_win_call(win, _11_)
    else
    end
  end
  return nil
end
local function rendered_line(self, idx)
  local line = self.content[idx]
  if (self["show-source-prefix"] and self["source-refs"] and self["source-refs"][idx]) then
    local ref = self["source-refs"][idx]
    local pfx = source_prefix(ref)
    local _13_
    if ((pfx.text or "") == "") then
      _13_ = normalize_render_line(line)
    else
      if ((line or "") == "") then
        _13_ = normalize_render_line(pfx.text)
      else
        _13_ = normalize_render_line((pfx.text .. "  " .. line))
      end
    end
    return {text = _13_, range = {["lnum-end"] = pfx["lnum-end"], ["icon-start"] = pfx["icon-start"], ["icon-end"] = pfx["icon-end"], ["icon-hl"] = pfx["icon-hl"], ["dir-ranges"] = (pfx["dir-ranges"] or {}), ["file-start"] = pfx["file-start"], ["file-end"] = pfx["file-end"], ["file-hl"] = pfx["file-hl"], ["ext-start"] = pfx["ext-start"], ["ext-end"] = pfx["ext-end"], ["ext-hl"] = pfx["ext-hl"]}}
  else
    return {text = normalize_render_line(line)}
  end
end
local function normalize_frame_lines(lines)
  local out = vim.deepcopy((lines or {}))
  for i = 1, #out do
    local line0 = out[i]
    local line1 = tostring((line0 or ""))
    local line2 = string.gsub(line1, "[\r\n\v\f]", "")
    out[i] = line2
  end
  return out
end
local function build_render_frame(self)
  local lines = {}
  local ranges = {}
  for _, idx in ipairs(self.indices) do
    local entry = rendered_line(self, idx)
    local row = (#lines + 1)
    table.insert(lines, entry.text)
    if entry.range then
      table.insert(ranges, vim.tbl_extend("force", entry.range, {row = row}))
    else
    end
  end
  return {lines = normalize_frame_lines(lines), ranges = ranges}
end
local function set_render_buffer_lines(self, lines)
  do
    local bo = vim.bo[self.buffer]
    bo["modifiable"] = true
  end
  set_bvar_21(self.buffer, "meta_internal_render", true)
  local manual_edit_active_3f = bvar(self.buffer, "meta_manual_edit_active", false)
  local undo_levels
  if manual_edit_active_3f then
    undo_levels = nil
  else
    undo_levels = vim.api.nvim_get_option_value("undolevels", {buf = self.buffer})
  end
  if undo_levels then
    pcall(vim.api.nvim_set_option_value, "undolevels", -1, {buf = self.buffer})
  else
  end
  vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, (lines or {}))
  if not manual_edit_active_3f then
    pcall(vim.api.nvim_set_option_value, "modified", false, {buf = self.buffer})
  else
  end
  if undo_levels then
    return pcall(vim.api.nvim_set_option_value, "undolevels", undo_levels, {buf = self.buffer})
  else
    return nil
  end
end
local function clear_render_namespaces(self)
  vim.api.nvim_buf_clear_namespace(self.buffer, self["source-hl-ns"], 0, -1)
  vim.api.nvim_buf_clear_namespace(self.buffer, self["source-sep-ns"], 0, -1)
  return vim.api.nvim_buf_clear_namespace(self.buffer, self["source-alt-ns"], 0, -1)
end
local function apply_frame_highlights(self, ranges)
  if self["show-source-prefix"] then
    for _, r in ipairs((ranges or {})) do
      local row0 = (r.row - 1)
      if ((r["lnum-end"] or 0) > 0) then
        vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], "MetaSourceLineNr", row0, 0, r["lnum-end"])
      else
      end
      if ((r["icon-end"] - r["icon-start"]) > 0) then
        vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], (r["icon-hl"] or "MetaSourceFile"), row0, r["icon-start"], r["icon-end"])
      else
      end
      for _0, dr in ipairs((r["dir-ranges"] or {})) do
        vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], dr.hl, row0, dr.start, dr["end"])
      end
      if ((r["file-end"] - r["file-start"]) > 0) then
        vim.api.nvim_buf_set_extmark(self.buffer, self["source-hl-ns"], row0, r["file-start"], {end_row = row0, end_col = r["file-end"], hl_group = (r["file-hl"] or "Normal"), hl_mode = "combine", priority = 220})
      else
      end
      if (((r["ext-end"] or 0) - (r["ext-start"] or 0)) > 0) then
        vim.api.nvim_buf_set_extmark(self.buffer, self["source-hl-ns"], row0, r["ext-start"], {end_row = row0, end_col = r["ext-end"], hl_group = (r["ext-hl"] or r["file-hl"] or "Normal"), hl_mode = "combine", priority = 230})
      else
      end
    end
    return nil
  else
    return nil
  end
end
local function apply_frame_separators(self)
  if (self["show-source-separators"] and self["source-refs"]) then
    local n = #self.indices
    local alt = false
    local prev_path = nil
    for i = 1, n do
      local idx = self.indices[i]
      local ref = (idx and self["source-refs"][idx])
      local path = ((ref and ref.path) or "")
      if (prev_path == nil) then
        prev_path = path
      else
      end
      if (path ~= prev_path) then
        alt = not alt
        prev_path = path
      else
      end
      if alt then
        vim.api.nvim_buf_set_extmark(self.buffer, self["source-alt-ns"], (i - 1), 0, {end_row = i, end_col = 0, hl_group = "MetaSourceAltBg", hl_eol = true, hl_mode = "combine", priority = 1})
      else
      end
    end
    for i = 1, (n - 1) do
      local cur_idx = self.indices[i]
      local next_idx = self.indices[(i + 1)]
      local cur_ref = (cur_idx and self["source-refs"][cur_idx])
      local next_ref = (next_idx and self["source-refs"][next_idx])
      local cur_path = (cur_ref and cur_ref.path)
      local next_path = (next_ref and next_ref.path)
      if (((cur_path or "") ~= (next_path or "")) and ((cur_ref and cur_ref.kind) ~= "file-entry") and ((next_ref and next_ref.kind) ~= "file-entry")) then
        vim.api.nvim_buf_set_extmark(self.buffer, self["source-sep-ns"], (i - 1), 0, {end_row = i, end_col = 0, hl_group = "MetaSourceBoundary", hl_eol = true, hl_mode = "combine", priority = 120})
      else
      end
    end
    return nil
  else
    return nil
  end
end
local function finalize_render(self, views)
  self["apply-source-syntax-regions"]()
  do
    local bo = vim.bo[self.buffer]
    if self["keep-modifiable"] then
      bo["modifiable"] = true
    else
      bo["modifiable"] = false
    end
  end
  set_bvar_21(self.buffer, "meta_internal_render", false)
  restore_window_views(views)
  return self.indexbuf.update()
end
local function stage_render_frame(self, frame)
  self["pending-render-frame"] = vim.deepcopy(frame)
  return false
end
local function commit_render_frame(self, frame)
  set_render_buffer_lines(self, frame.lines)
  self["last-rendered-lines"] = vim.deepcopy(frame.lines)
  self["pending-render-frame"] = nil
  clear_render_namespaces(self)
  apply_frame_highlights(self, frame.ranges)
  return true
end
M.new = function(nvim, model)
  local self = base.new(nvim, {model = model, name = "meta", ["default-opts"] = M["default-opts"]})
  self["syntax-type"] = "buffer"
  self.indexbuf = ui.new(nvim, self, "indexes")
  self["show-source-prefix"] = false
  self["show-source-separators"] = false
  self["visible-source-syntax-only"] = false
  self["source-hl-ns"] = vim.api.nvim_create_namespace("metabuffer_source")
  self["source-sep-ns"] = vim.api.nvim_create_namespace("metabuffer_source_separator")
  self["source-alt-ns"] = vim.api.nvim_create_namespace("metabuffer_source_alt")
  self["source-syntax-groups"] = {}
  self["source-syntax-included"] = {}
  self["source-syntax-base-reset?"] = false
  self["source-syntax-next-group-id"] = 0
  self["source-syntax-fill-token"] = 0
  self["source-syntax-fill-pending"] = false
  self["keep-modifiable"] = false
  self["last-rendered-lines"] = {}
  self["pending-render-frame"] = nil
  self["model-valid?"] = function()
    return (self.model and vim.api.nvim_buf_is_valid(self.model))
  end
  self["ref-filetype"] = function(ref)
    local kind = (ref and ref.kind)
    local path = (ref and ref.path)
    local ft
    if ((type(path) == "string") and (path ~= "")) then
      ft = (vim.filetype.match({filename = vim.fn.fnamemodify(path, ":t")}) or vim.filetype.match({filename = path}))
    else
      ft = nil
    end
    if (kind == "file-entry") then
      return "text"
    else
      if ((type(ft) == "string") and (ft ~= "")) then
        return ft
      else
        return "text"
      end
    end
  end
  self["clear-source-syntax"] = function()
    self["source-syntax-fill-token"] = (1 + (self["source-syntax-fill-token"] or 0))
    self["source-syntax-fill-pending"] = false
    if (self["source-syntax-groups"] and (#self["source-syntax-groups"] > 0)) then
      local function _36_()
        for _, g in ipairs(self["source-syntax-groups"]) do
          vim.cmd(("silent! syntax clear " .. g))
        end
        return nil
      end
      vim.api.nvim_buf_call(self.buffer, _36_)
    else
    end
    self["source-syntax-groups"] = {}
    self["source-syntax-included"] = {}
    self["source-syntax-base-reset?"] = false
    self["source-syntax-next-group-id"] = 0
    return nil
  end
  self["add-source-syntax-range"] = function(syntax_start, syntax_stop)
    if (self["source-refs"] and (#self.indices > 0) and (syntax_start <= syntax_stop)) then
      local included = self["source-syntax-included"]
      local groups = self["source-syntax-groups"]
      local function _38_()
        local function add_block(start, stop, ft)
          if (ft and (ft ~= "") and (start <= stop)) then
            local synfiles = syntax_files_for_ft(ft)
            local has_syntax = (#synfiles > 0)
            if has_syntax then
              if not self["source-syntax-base-reset?"] then
                vim.cmd("silent! syntax clear")
                pcall(vim.api.nvim_buf_del_var, self.buffer, "current_syntax")
                self["source-syntax-base-reset?"] = true
              else
              end
              local cluster = ("MetaSrcFt_" .. sanitize_syntax_id(ft))
              if not included[cluster] then
                apply_ft_buffer_vars_21(self.buffer, ft)
                for _, synfile in ipairs(synfiles) do
                  pcall(vim.api.nvim_buf_del_var, self.buffer, "current_syntax")
                  vim.cmd(("silent! syntax include @" .. cluster .. " " .. vim.fn.fnameescape(synfile)))
                end
                included[cluster] = true
              else
              end
              self["source-syntax-next-group-id"] = (self["source-syntax-next-group-id"] + 1)
              local group = string.format("MetaSrcBlock_%d", self["source-syntax-next-group-id"])
              vim.cmd(string.format("silent! syntax match %s /\\%%>%dl\\%%<%dl.*/ contains=@%s transparent", group, (start - 1), (stop + 1), cluster))
              return table.insert(groups, group)
            else
              return nil
            end
          else
            return nil
          end
        end
        local start = syntax_start
        local prev_ft = nil
        local prev_src_idx = nil
        for i = syntax_start, syntax_stop do
          local idx = self.indices[i]
          local ref = (idx and self["source-refs"][idx])
          local ft = self["ref-filetype"](ref)
          if not prev_ft then
            prev_ft = ft
          else
          end
          if ((ft ~= prev_ft) or (prev_src_idx and (idx ~= (prev_src_idx + 1)))) then
            add_block(start, (i - 1), prev_ft)
            start = i
            prev_ft = ft
          else
          end
          prev_src_idx = idx
        end
        if prev_ft then
          return add_block(start, syntax_stop, prev_ft)
        else
          return nil
        end
      end
      return vim.api.nvim_buf_call(self.buffer, _38_)
    else
      return nil
    end
  end
  self["run-source-syntax-fill-step"] = function(total_lines)
    local session = self.model.session
    local chunk = math.max(1, ((session and session["project-source-syntax-chunk-lines"]) or 240))
    local token = self["source-syntax-fill-token"]
    if (self["source-syntax-fill-pending"] and vim.api.nvim_buf_is_valid(self.buffer) and (token == self["source-syntax-fill-token"])) then
      local budget = chunk
      if ((self["source-syntax-next-after"] <= total_lines) and (budget > 0)) then
        local stop = math.min(total_lines, (self["source-syntax-next-after"] + budget + -1))
        self["add-source-syntax-range"](self["source-syntax-next-after"], stop)
        budget = (budget - ((stop - self["source-syntax-next-after"]) + 1))
        self["source-syntax-next-after"] = (stop + 1)
      else
      end
      if ((self["source-syntax-next-before"] >= 1) and (budget > 0)) then
        local start = math.max(1, (self["source-syntax-next-before"] + ( - budget) + 1))
        self["add-source-syntax-range"](start, self["source-syntax-next-before"])
        self["source-syntax-next-before"] = (start - 1)
      else
      end
      if ((self["source-syntax-next-after"] <= total_lines) or (self["source-syntax-next-before"] >= 1)) then
        local function _49_()
          return self["run-source-syntax-fill-step"](total_lines)
        end
        return vim.defer_fn(_49_, 17)
      else
        self["source-syntax-fill-pending"] = false
        local function _50_()
          return vim.cmd("silent! syntax sync fromstart")
        end
        return vim.api.nvim_buf_call(self.buffer, _50_)
      end
    else
      return nil
    end
  end
  self["schedule-source-syntax-fill"] = function(syntax_start, syntax_stop, total_lines)
    self["source-syntax-fill-token"] = (1 + (self["source-syntax-fill-token"] or 0))
    self["source-syntax-fill-pending"] = true
    self["source-syntax-next-after"] = (syntax_stop + 1)
    self["source-syntax-next-before"] = (syntax_start - 1)
    local function _53_()
      return self["run-source-syntax-fill-step"](total_lines)
    end
    return vim.defer_fn(_53_, 17)
  end
  self["apply-source-syntax-regions"] = function()
    if not (self["show-source-separators"] and (self["syntax-type"] == "buffer") and self["source-refs"] and (#self.indices > 0)) then
      return self["clear-source-syntax"]()
    else
      local n = #self.indices
      local session = self.model.session
      local chunk = math.max(1, ((session and session["project-source-syntax-chunk-lines"]) or 240))
      local visible_start = 1
      local visible_stop = n
      do
        local wins = vim.fn.win_findbuf(self.buffer)
        local win = nil
        for _, candidate in ipairs(wins) do
          if (not win and vim.api.nvim_win_is_valid(candidate)) then
            win = candidate
          else
          end
        end
        if win then
          local view
          local function _55_()
            return vim.fn.winsaveview()
          end
          view = vim.api.nvim_win_call(win, _55_)
          local height = math.max(1, vim.api.nvim_win_get_height(win))
          visible_start = math.max(1, math.min((view.topline or 1), n))
          visible_stop = math.max(visible_start, math.min((visible_start + height + -1), n))
        else
        end
      end
      local incremental_fill_3f = (session and session["project-mode"] and not self["visible-source-syntax-only"] and (n > chunk))
      local syntax_start
      if (self["visible-source-syntax-only"] or incremental_fill_3f) then
        syntax_start = visible_start
      else
        syntax_start = 1
      end
      local syntax_stop
      if (self["visible-source-syntax-only"] or incremental_fill_3f) then
        syntax_stop = visible_stop
      else
        syntax_stop = n
      end
      self["clear-source-syntax"]()
      self["add-source-syntax-range"](syntax_start, syntax_stop)
      if not (self["visible-source-syntax-only"] or incremental_fill_3f) then
        local function _59_()
          return vim.cmd("silent! syntax sync fromstart")
        end
        vim.api.nvim_buf_call(self.buffer, _59_)
      else
      end
      if incremental_fill_3f then
        return self["schedule-source-syntax-fill"](syntax_start, syntax_stop, n)
      else
        return nil
      end
    end
  end
  self.syntax = function()
    if ((self["syntax-type"] == "buffer") and self["model-valid?"]()) then
      return vim.bo[self.model].syntax
    else
      return "metabuffer"
    end
  end
  self["apply-syntax"] = function(syntax_type)
    if syntax_type then
      self["syntax-type"] = syntax_type
    else
    end
    local bo = vim.bo[self.buffer]
    if (self["syntax-type"] == "buffer") then
      if self["model-valid?"]() then
        local ft = vim.bo[self.model].filetype
        local syn = vim.bo[self.model].syntax
        if (ft and (ft ~= "")) then
          apply_ft_buffer_vars_21(self.buffer, ft)
          bo["filetype"] = ft
        else
        end
        if (syn and (syn ~= "")) then
          bo["syntax"] = syn
          return nil
        else
          bo["syntax"] = ""
          return nil
        end
      else
        bo["filetype"] = "metabuffer"
        bo["syntax"] = "metabuffer"
        return nil
      end
    else
      bo["filetype"] = "metabuffer"
      bo["syntax"] = "metabuffer"
      return nil
    end
  end
  self.update = function()
    return self.render()
  end
  self.render = function()
    local views = save_window_views(self)
    local frame = build_render_frame(self)
    local committed_3f
    if should_defer_empty_frame(self, frame) then
      committed_3f = stage_render_frame(self, frame)
    else
      committed_3f = commit_render_frame(self, frame)
    end
    if committed_3f then
      apply_frame_separators(self)
      return finalize_render(self, views)
    else
      return nil
    end
  end
  self["push-visible-lines"] = function(visible)
    if self["model-valid?"]() then
      local n = math.min(#visible, #self.indices)
      for i = 1, n do
        local src = self.indices[i]
        local old = vim.api.nvim_buf_get_lines(self.model, (src - 1), src, false)
        local old_line = old[1]
        local new_line = visible[i]
        if (old_line ~= new_line) then
          vim.api.nvim_buf_set_lines(self.model, (src - 1), src, false, {new_line})
          self.content[src] = new_line
        else
        end
      end
      return nil
    else
      return nil
    end
  end
  return self
end
return M
