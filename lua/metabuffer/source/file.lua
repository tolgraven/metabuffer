-- [nfnl] fnl/metabuffer/source/file.fnl
local text = require("metabuffer.source.text")
local file_info = require("metabuffer.source.file_info")
local util = require("metabuffer.util")
local M = {}
M["provider-key"] = "file-entry"
M["query-directive-specs"] = {{kind = "toggle", long = "file", ["token-key"] = "include-files", arg = "[:{filter}]", doc = "Switch to file-entry source filtering. Use #file:term for inline path filters."}}
local function option_prefix()
  local p = vim.g["meta#prefix"]
  if ((type(p) == "string") and (p ~= "")) then
    return p
  else
    return "#"
  end
end
local function inline_file_filter(tok)
  local t = (tok or "")
  local prefix = option_prefix()
  local patterns = {("^" .. vim.pesc(prefix) .. "file:(.*)$"), ("^" .. vim.pesc(prefix) .. "f:(.*)$")}
  local matched = nil
  local out = matched
  for _, pat in ipairs(patterns) do
    if (out == nil) then
      local value = string.match(t, pat)
      if (value ~= nil) then
        out = value
      else
      end
    else
    end
  end
  return out
end
M["parse-bare-token"] = function(state, tok, unquote_token)
  local t = (tok or "")
  local val_111_auto = inline_file_filter(t)
  if val_111_auto then
    local inline = val_111_auto
    local next = vim.deepcopy(state)
    next["include-files"] = true
    if (vim.trim(inline) ~= "") then
      table.insert(next["file-lines"], unquote_token(inline))
    else
    end
    next["file-await-token"] = false
    next["await-directive"] = nil
    return next
  else
    if (t == "./") then
      local next = vim.deepcopy(state)
      next["include-files"] = true
      next["file-await-token"] = true
      next["await-directive"] = {kind = "file"}
      return next
    else
      local val_111_auto0 = string.match(t, "^%./(.+)$")
      if val_111_auto0 then
        local matched = val_111_auto0
        local next = vim.deepcopy(state)
        next["include-files"] = true
        table.insert(next["file-lines"], unquote_token(matched))
        next["file-await-token"] = false
        return next
      else
        return nil
      end
    end
  end
end
M["hit-prefix"] = function(ref)
  return text["path-prefix"](ref)
end
M["info-path"] = function(ref, full_path_3f)
  return text["info-path"](ref, full_path_3f)
end
M["info-suffix"] = function(session, ref, mode, read_file_lines_cached, read_file_view_cached)
  local path = (ref and ref.path)
  if not (path and (1 == vim.fn.filereadable(path))) then
    return ""
  else
    if ((mode or "meta") == "meta") then
      return file_info["file-meta-data"](session, path).text
    else
      return file_info["file-first-line"](session, read_file_lines_cached, read_file_view_cached, path)
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
local function source_sign(_ref)
  return util["icon-sign"]({category = "directory", name = ".", fallback = "\243\176\137\139", hl = "MiniIconsAzure"})
end
M["info-view"] = function(session, ref, ctx)
  local mode = ((ctx and ctx.mode) or "meta")
  local path_width = ((ctx and ctx["path-width"]) or 1)
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local suffix0 = M["info-suffix"](session, ref, mode, read_file_lines_cached, nil)
  local sign = source_sign(ref)
  if (mode == "meta") then
    local view = file_info["meta-info-view"](session, ((ref and ref.path) or ""), path_width)
    view["sign"] = sign
    return view
  else
    return {path = "", ["icon-path"] = ((ref and ref.path) or ""), sign = sign, suffix = suffix0, ["suffix-prefix"] = "", ["suffix-highlights"] = {}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
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
M["preview-lines"] = function(session, ref, height, read_file_lines_cached, read_file_view_cached)
  local r = vim.deepcopy((ref or {}))
  r.buf = nil
  if not r["preview-lnum"] then
    r["preview-lnum"] = 1
  else
  end
  return text["preview-lines"](session, r, height, read_file_lines_cached, read_file_view_cached)
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
