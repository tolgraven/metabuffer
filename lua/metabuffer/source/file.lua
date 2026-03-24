-- [nfnl] fnl/metabuffer/source/file.fnl
local text = require("metabuffer.source.text")
local file_info = require("metabuffer.source.file_info")
local M = {}
M["provider-key"] = "file-entry"
M["hit-prefix"] = function(ref)
  return text["path-prefix"](ref)
end
M["info-path"] = function(ref, full_path_3f)
  return text["info-path"](ref, full_path_3f)
end
M["info-suffix"] = function(session, ref, mode, read_file_lines_cached)
  local path = (ref and ref.path)
  if not (path and (1 == vim.fn.filereadable(path))) then
    return ""
  else
    if ((mode or "meta") == "meta") then
      return file_info["file-meta-data"](session, path).text
    else
      return file_info["file-first-line"](session, read_file_lines_cached, path)
    end
  end
end
M["info-meta"] = function(session, ref)
  local path = (ref and ref.path)
  if (path and (1 == vim.fn.filereadable(path)) and (((ref and ref.kind) or "") == "file-entry")) then
    return file_info["file-meta-data"](session, path)
  else
    return nil
  end
end
M["info-view"] = function(session, ref, ctx)
  local mode = ((ctx and ctx.mode) or "meta")
  local path_width = ((ctx and ctx["path-width"]) or 1)
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local suffix0 = M["info-suffix"](session, ref, mode, read_file_lines_cached)
  if (mode == "meta") then
    return file_info["meta-info-view"](session, ((ref and ref.path) or ""), path_width)
  else
    return {path = "", ["icon-path"] = ((ref and ref.path) or ""), sign = file_info["file-status-sign"](((M["info-meta"](session, ref) and M["info-meta"](session, ref).status) or "")), suffix = suffix0, ["suffix-prefix"] = "", ["suffix-highlights"] = {}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
  end
end
M["preview-filetype"] = function(ref)
  local path = (ref and ref.path)
  if ((type(path) == "string") and (path ~= "")) then
    local ok,ft = pcall(vim.filetype.match, {filename = path})
    if (ok and (type(ft) == "string") and (ft ~= "")) then
      return ft
    else
      return "text"
    end
  else
    return "text"
  end
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached)
  local r = vim.deepcopy((ref or {}))
  r.buf = nil
  if not r["preview-lnum"] then
    r["preview-lnum"] = 1
  else
  end
  return text["preview-lines"](session, r, height, read_file_lines_cached)
end
local function normalize_target_path(old_path, text0)
  local trimmed = vim.trim((text0 or ""))
  if ((trimmed == "") or (trimmed == old_path)) then
    return old_path
  else
    local cwd = vim.fn.getcwd()
    local candidate = vim.fn.fnamemodify(trimmed, ":p")
    if vim.startswith(candidate, cwd) then
      return candidate
    else
      return vim.fn.fnamemodify((cwd .. "/" .. trimmed), ":p")
    end
  end
end
M["apply-write-ops!"] = function(ops)
  local renames = {}
  local touched_paths = {}
  local total = 0
  local any_write = false
  for path, per_file in pairs((ops or {})) do
    if ((#(per_file or {}) == 1) and (((per_file[1] and per_file[1].kind) or "") == "replace")) then
      local op = per_file[1]
      local target = normalize_target_path(path, op.text)
      if (target ~= path) then
        if (vim.fn.mkdir(vim.fn.fnamemodify(target, ":h"), "p") == 1) then
        else
        end
        local ok = pcall(vim.loop.fs_rename, path, target)
        if ok then
          any_write = true
          total = (total + 1)
          touched_paths[path] = true
          renames[path] = target
        else
        end
      else
      end
    else
    end
  end
  return {wrote = any_write, changed = total, ["post-lines"] = {}, paths = touched_paths, renames = renames}
end
return M
