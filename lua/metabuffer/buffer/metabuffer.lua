-- [nfnl] fnl/metabuffer/buffer/metabuffer.fnl
local base = require("metabuffer.buffer.base")
local ui = require("metabuffer.buffer.ui")
local M = {}
M["default-opts"] = {bufhidden = "hide", buftype = "nofile", buflisted = false}
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
  local lnum = (ref.lnum or 0)
  local parts = split_source_path(ref.path)
  local lnum_str = string.format("%6d", lnum)
  local dir = (parts.dir or "")
  local file = (parts.file or "")
  return {text = (lnum_str .. "  " .. dir .. file .. "  "), ["lnum-end"] = #lnum_str, ["dir-start"] = (#lnum_str + 2), ["dir-end"] = ((#lnum_str + 2) + #dir), ["file-start"] = ((#lnum_str + 2) + #dir), ["file-end"] = (((#lnum_str + 2) + #dir) + #file)}
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
M.new = function(nvim, model)
  local self = base.new(nvim, {model = model, name = "meta", ["default-opts"] = M["default-opts"]})
  self["syntax-type"] = "buffer"
  self.indexbuf = ui.new(nvim, self, "indexes")
  self["show-source-prefix"] = false
  self["show-source-separators"] = false
  self["source-hl-ns"] = vim.api.nvim_create_namespace("metabuffer_source")
  self["source-sep-ns"] = vim.api.nvim_create_namespace("metabuffer_source_separator")
  self["source-alt-ns"] = vim.api.nvim_create_namespace("metabuffer_source_alt")
  self["source-syntax-groups"] = {}
  self["model-valid?"] = function()
    return (self.model and vim.api.nvim_buf_is_valid(self.model))
  end
  self["ref-filetype"] = function(ref)
    local path = (ref and ref.path)
    local ft
    if ((type(path) == "string") and (path ~= "")) then
      ft = (vim.filetype.match({filename = vim.fn.fnamemodify(path, ":t")}) or vim.filetype.match({filename = path}))
    else
      ft = nil
    end
    if ((type(ft) == "string") and (ft ~= "")) then
      return ft
    else
      return "text"
    end
  end
  self["clear-source-syntax"] = function()
    if (self["source-syntax-groups"] and (#self["source-syntax-groups"] > 0)) then
      local function _6_()
        for _, g in ipairs(self["source-syntax-groups"]) do
          vim.cmd(("silent! syntax clear " .. g))
        end
        return nil
      end
      vim.api.nvim_buf_call(self.buffer, _6_)
    else
    end
    self["source-syntax-groups"] = {}
    return nil
  end
  self["apply-source-syntax-regions"] = function()
    if not (self["show-source-separators"] and (self["syntax-type"] == "buffer") and self["source-refs"] and (#self.indices > 0)) then
      return self["clear-source-syntax"]()
    else
      local n = #self.indices
      local included = {}
      local groups = {}
      self["clear-source-syntax"]()
      local function _8_()
        vim.cmd("silent! syntax clear")
        pcall(vim.api.nvim_buf_del_var, self.buffer, "current_syntax")
        local function add_block(start, stop, ft)
          if (ft and (ft ~= "") and (start <= stop)) then
            local cluster = ("MetaSrcFt_" .. sanitize_syntax_id(ft))
            local group = string.format("MetaSrcBlock_%d_%d", start, stop)
            local synfiles = syntax_files_for_ft(ft)
            local has_syntax = (#synfiles > 0)
            if has_syntax then
              if not included[cluster] then
                for _, synfile in ipairs(synfiles) do
                  pcall(vim.api.nvim_buf_del_var, self.buffer, "current_syntax")
                  vim.cmd(("silent! syntax include @" .. cluster .. " " .. vim.fn.fnameescape(synfile)))
                end
                included[cluster] = true
              else
              end
              vim.cmd(string.format("silent! syntax match %s /\\%%>%dl\\%%<%dl.*/ contains=@%s transparent", group, (start - 1), (stop + 1), cluster))
              return table.insert(groups, group)
            else
              return nil
            end
          else
            return nil
          end
        end
        local start = 1
        local prev_ft = nil
        for i = 1, n do
          local idx = self.indices[i]
          local ref = (idx and self["source-refs"][idx])
          local ft = self["ref-filetype"](ref)
          if not prev_ft then
            prev_ft = ft
          else
          end
          if (ft ~= prev_ft) then
            add_block(start, (i - 1), prev_ft)
            start = i
            prev_ft = ft
          else
          end
        end
        if prev_ft then
          add_block(start, n, prev_ft)
        else
        end
        return vim.cmd("silent! syntax sync fromstart")
      end
      vim.api.nvim_buf_call(self.buffer, _8_)
      self["source-syntax-groups"] = groups
      return nil
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
    local win_views = {}
    local out = {}
    local ranges = {}
    for _, win in ipairs(vim.fn.win_findbuf(self.buffer)) do
      if vim.api.nvim_win_is_valid(win) then
        local function _22_()
          return vim.fn.winsaveview()
        end
        win_views[win] = vim.api.nvim_win_call(win, _22_)
      else
      end
    end
    do
      local bo = vim.bo[self.buffer]
      bo["modifiable"] = true
    end
    for _, idx in ipairs(self.indices) do
      local line = self.content[idx]
      if (self["show-source-prefix"] and self["source-refs"] and self["source-refs"][idx]) then
        local ref = self["source-refs"][idx]
        local pfx = source_prefix(ref)
        local row = (#out + 1)
        table.insert(out, (pfx.text .. line))
        table.insert(ranges, {row = row, ["lnum-end"] = pfx["lnum-end"], ["dir-start"] = pfx["dir-start"], ["dir-end"] = pfx["dir-end"], ["file-start"] = pfx["file-start"], ["file-end"] = pfx["file-end"]})
      else
        table.insert(out, line)
      end
    end
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    vim.api.nvim_buf_clear_namespace(self.buffer, self["source-hl-ns"], 0, -1)
    vim.api.nvim_buf_clear_namespace(self.buffer, self["source-sep-ns"], 0, -1)
    vim.api.nvim_buf_clear_namespace(self.buffer, self["source-alt-ns"], 0, -1)
    if self["show-source-prefix"] then
      for _, r in ipairs(ranges) do
        local row0 = (r.row - 1)
        vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], "MetaSourceLineNr", row0, 0, r["lnum-end"])
        if ((r["dir-end"] - r["dir-start"]) > 0) then
          vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], "MetaSourceDir", row0, r["dir-start"], r["dir-end"])
        else
        end
        if ((r["file-end"] - r["file-start"]) > 0) then
          vim.api.nvim_buf_add_highlight(self.buffer, self["source-hl-ns"], "MetaSourceFile", row0, r["file-start"], r["file-end"])
        else
        end
      end
    else
    end
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
          vim.api.nvim_buf_set_extmark(self.buffer, self["source-alt-ns"], (i - 1), 0, {end_row = i, end_col = 0, hl_group = "MetaSourceAltBg", hl_eol = true, priority = 1})
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
        if ((cur_path or "") ~= (next_path or "")) then
          vim.api.nvim_buf_set_extmark(self.buffer, self["source-sep-ns"], (i - 1), 0, {end_row = i, end_col = 0, hl_group = "MetaSourceBoundary", hl_eol = true, priority = 120})
        else
        end
      end
    else
    end
    self["apply-source-syntax-regions"]()
    do
      local bo = vim.bo[self.buffer]
      bo["modifiable"] = false
    end
    for win, view in pairs(win_views) do
      if vim.api.nvim_win_is_valid(win) then
        local function _33_()
          return pcall(vim.fn.winrestview, view)
        end
        vim.api.nvim_win_call(win, _33_)
      else
      end
    end
    return self.indexbuf.update()
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
