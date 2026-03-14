-- [nfnl] fnl/metabuffer/source/text.fnl
local path_hl = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
local file_info = require("metabuffer.source.file_info")
local M = {}
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
  return {dir = dir_part, file = file, path = rel}
end
local function ext_range(file, file_start)
  local n = #(file or "")
  local dot = string.match((file or ""), ".*()%.")
  if (dot and (dot > 1) and (dot < n)) then
    return {start = (file_start + (dot - 1)), ["end"] = (file_start + n)}
  else
    return {start = 0, ["end"] = 0}
  end
end
M["path-prefix"] = function(ref)
  local parts = split_source_path(ref.path)
  local icon_info = util["devicon-info"]((ref.path or ""), "Normal")
  local iconf = icon_field((icon_info.icon or ""))
  local icon_prefix = iconf.text
  local dir = (parts.dir or "")
  local file = (parts.file or "")
  local dir_start = #icon_prefix
  local file_start = (dir_start + #dir)
  local ex = ext_range(file, file_start)
  return {text = (icon_prefix .. dir .. file), ["lnum-end"] = 0, ["icon-start"] = 0, ["icon-end"] = #icon_prefix, ["icon-hl"] = (icon_info["icon-hl"] or "Normal"), ["dir-ranges"] = path_hl["ranges-for-dir"](dir, dir_start), ["file-start"] = file_start, ["file-end"] = (file_start + #file), ["file-hl"] = (icon_info["file-hl"] or "Normal"), ["ext-start"] = ex.start, ["ext-end"] = ex["end"], ["ext-hl"] = (icon_info["ext-hl"] or "Normal"), dir = dir, file = file, path = (parts.path or "")}
end
M["hit-prefix"] = function(_ref)
  return {text = "", ["lnum-end"] = 0, ["icon-start"] = 0, ["icon-end"] = 0, ["icon-hl"] = "MetaSourceFile", ["dir-ranges"] = {}, ["file-start"] = 0, ["file-end"] = 0, ["file-hl"] = "MetaSourceFile", ["ext-start"] = 0, ["ext-end"] = 0, ["ext-hl"] = "MetaSourceFile", dir = "", file = "", path = ""}
end
M["info-path"] = function(ref, full_path_3f)
  local path0 = ((ref and ref.path) or "")
  if (path0 == "") then
    return "[Current Buffer]"
  else
    if full_path_3f then
      return vim.fn.fnamemodify(path0, ":.")
    else
      return vim.fn.fnamemodify(path0, ":~:.")
    end
  end
end
M["info-suffix"] = function(_session, _ref, _mode, _read_file_lines_cached)
  return ""
end
M["info-meta"] = function(_session, _ref)
  return nil
end
M["info-view"] = function(session, ref, ctx)
  local mode = ((ctx and ctx.mode) or "meta")
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local single_source_3f = not not (ctx and ctx["single-source?"])
  if single_source_3f then
    if (session["single-file-info-ready"] and ref and ref.path and ref.lnum and (1 == vim.fn.filereadable(ref.path))) then
      return file_info["line-meta-info-view"](session, ref.path, ref.lnum, 1)
    else
      return {path = "", ["icon-path"] = "", sign = {text = "  ", hl = "LineNr"}, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached), ["suffix-prefix"] = "", ["suffix-highlights"] = {}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
    end
  else
    return {path = M["info-path"](ref, false), ["icon-path"] = M["info-path"](ref, false), ["show-icon"] = true, ["highlight-dir"] = true, ["highlight-file"] = true, sign = {text = "  ", hl = "LineNr"}, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached), ["suffix-prefix"] = "  ", ["suffix-highlights"] = {}}
  end
end
M["preview-filetype"] = function(ref)
  if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
    return vim.bo[ref.buf].filetype
  else
    if (ref and ref.path) then
      local ok,ft = pcall(vim.filetype.match, {filename = ref.path})
      if (ok and (type(ft) == "string")) then
        return ft
      else
        return ""
      end
    else
      return ""
    end
  end
end
local function trim_or_pad_lines(lines, target)
  local out = {}
  for _, line in ipairs((lines or {})) do
    if (#out < target) then
      table.insert(out, (line or ""))
    else
    end
  end
  while (#out < target) do
    table.insert(out, "")
  end
  return out
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached)
  local h = math.max(1, height)
  local lnum = math.max(1, ((ref and ref["preview-lnum"]) or (ref and ref.lnum) or 1))
  local start = math.max(1, (lnum - 1))
  local stop = (start + h + -1)
  if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
    return {["start-lnum"] = start, ["focus-lnum"] = lnum, lines = trim_or_pad_lines(vim.api.nvim_buf_get_lines(ref.buf, (start - 1), stop, false), h)}
  else
    if (ref and ref.path and (1 == vim.fn.filereadable(ref.path))) then
      local cache = (session["preview-file-cache"] or {})
      local _
      session["preview-file-cache"] = cache
      _ = nil
      local all0 = cache[ref.path]
      local all
      if (type(all0) == "table") then
        all = all0
      else
        local lines = read_file_lines_cached(ref.path, {["include-binary"] = (session and session["effective-include-binary"]), ["hex-view"] = (session and session["effective-include-hex"])})
        if (type(lines) == "table") then
          cache[ref.path] = lines
          all = lines
        else
          all = {}
        end
      end
      local slice = {}
      for i = start, stop do
        table.insert(slice, (all[i] or ""))
      end
      return {["start-lnum"] = start, ["focus-lnum"] = lnum, lines = trim_or_pad_lines(slice, h)}
    else
      return {["start-lnum"] = 1, ["focus-lnum"] = 1, lines = trim_or_pad_lines({}, h)}
    end
  end
end
return M
