-- [nfnl] fnl/metabuffer/source/file.fnl
local text = require("metabuffer.source.text")
local author_hl = require("metabuffer.author_highlight")
local M = {}
local function file_first_line(session, read_file_lines_cached, path)
  local cache = (session["info-file-head-cache"] or {})
  local mtime = vim.fn.getftime(path)
  local found = cache[path]
  if ((type(found) == "table") and (found.mtime == mtime) and (type(found.line) == "string")) then
    return found.line
  else
    local line0 = ((read_file_lines_cached(path) or {})[1] or "")
    local line = tostring(line0)
    cache[path] = {mtime = mtime, line = line}
    session["info-file-head-cache"] = cache
    return line
  end
end
local function git_file_status(path)
  local rel = vim.fn.fnamemodify(path, ":.")
  local out = vim.fn.systemlist({"git", "-C", vim.fn.getcwd(), "status", "--porcelain", "--", rel})
  if (vim.v.shell_error ~= 0) then
    return ""
  else
    local line = (out[1] or "")
    if (line == "") then
      return "clean"
    else
      if vim.startswith(line, "??") then
        return "untracked"
      else
        local x = string.sub(line, 1, 1)
        local y = string.sub(line, 2, 2)
        local staged_3f = (x ~= " ")
        local dirty_3f = (y ~= " ")
        if (staged_3f and dirty_3f) then
          return "staged+dirty"
        else
          if staged_3f then
            return "staged"
          else
            if dirty_3f then
              return "dirty"
            else
              return "changed"
            end
          end
        end
      end
    end
  end
end
local function git_last_commit_info(path)
  local rel = vim.fn.fnamemodify(path, ":.")
  local out = vim.fn.systemlist({"git", "-C", vim.fn.getcwd(), "log", "-1", "--format=%cr%x09%an", "--", rel})
  if (vim.v.shell_error == 0) then
    local line = (out[1] or "")
    local age = (string.match(line, "^([^\t]+)\t") or "")
    local author = (string.match(line, "^[^\t]+\t(.+)$") or "")
    return {age = age, author = author}
  else
    return {age = "", author = ""}
  end
end
local function compact_relative_age(age)
  local txt = string.lower(vim.trim((age or "")))
  local n = tonumber((string.match(txt, "^(%d+)") or ""))
  if (txt == "") then
    return ""
  else
    local _9_
    if string.find(txt, "minute") then
      _9_ = (tostring((n or 1)) .. "m")
    else
      _9_ = nil
    end
    local or_11_ = _9_
    if not or_11_ then
      if string.find(txt, "hour") then
        or_11_ = (tostring((n or 1)) .. "h")
      else
        or_11_ = nil
      end
    end
    if not or_11_ then
      if (string.find(txt, "day") or (txt == "yesterday")) then
        or_11_ = (tostring((n or 1)) .. "d")
      else
        or_11_ = nil
      end
    end
    if not or_11_ then
      if string.find(txt, "week") then
        or_11_ = (tostring((n or 1)) .. "w")
      else
        or_11_ = nil
      end
    end
    if not or_11_ then
      if string.find(txt, "month") then
        or_11_ = (tostring((n or 1)) .. "mo")
      else
        or_11_ = nil
      end
    end
    if not or_11_ then
      if string.find(txt, "year") then
        or_11_ = (tostring((n or 1)) .. "y")
      else
        or_11_ = nil
      end
    end
    if not or_11_ then
      if ((txt == "just now") or (txt == "now")) then
        or_11_ = "0m"
      else
        or_11_ = nil
      end
    end
    return (or_11_ or "")
  end
end
local function file_meta_line(meta)
  local mtime_text = (meta["mtime-text"] or "000000")
  local git_age = (meta.age or "")
  local age_fragment
  if (git_age ~= "") then
    age_fragment = (" \240\159\149\147" .. git_age)
  else
    age_fragment = " "
  end
  local git_author
  do
    local a = vim.trim((meta.author or ""))
    if (a == "") then
      git_author = "?"
    else
      git_author = a
    end
  end
  return (mtime_text .. age_fragment .. "\t" .. git_author)
end
local function file_meta_data(session, path)
  local cache = (session["info-file-meta-cache"] or {})
  local mtime = vim.fn.getftime(path)
  local found = cache[path]
  if ((type(found) == "table") and (found.mtime == mtime) and (type(found.text) == "string") and (type(found.status) == "string")) then
    return found
  else
    local mtime_text
    if (mtime > 0) then
      mtime_text = vim.fn.strftime("%y%m%d", mtime)
    else
      mtime_text = "000000"
    end
    local git_status = git_file_status(path)
    local commit = git_last_commit_info(path)
    local git_age = compact_relative_age((commit.age or ""))
    local git_author
    do
      local a = vim.trim((commit.author or ""))
      if (a == "") then
        git_author = "?"
      else
        git_author = a
      end
    end
    local meta = {mtime = mtime, ["mtime-text"] = mtime_text, status = git_status, age = git_age, author = git_author}
    local text0 = file_meta_line(meta)
    cache[path] = vim.tbl_extend("force", meta, {text = text0})
    session["info-file-meta-cache"] = cache
    return cache[path]
  end
end
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
      return file_meta_data(session, path).text
    else
      return file_first_line(session, read_file_lines_cached, path)
    end
  end
end
M["info-meta"] = function(session, ref)
  local path = (ref and ref.path)
  if (path and (1 == vim.fn.filereadable(path)) and (((ref and ref.kind) or "") == "file-entry")) then
    return file_meta_data(session, path)
  else
    return nil
  end
end
local function age_hl_group(age_token)
  local unit = (string.match((age_token or ""), "^%d+([a-z]+)$") or "")
  if (unit == "m") then
    return "MetaFileAgeMinute"
  elseif (unit == "h") then
    return "MetaFileAgeHour"
  elseif (unit == "d") then
    return "MetaFileAgeDay"
  elseif (unit == "w") then
    return "MetaFileAgeWeek"
  elseif (unit == "mo") then
    return "MetaFileAgeMonth"
  elseif (unit == "y") then
    return "MetaFileAgeYear"
  else
    return "MetaFileAge"
  end
end
local function file_status_sign(status)
  if (status == "untracked") then
    return {text = "\226\156\151 ", hl = "MetaFileSignUntracked"}
  elseif (status == "clean") then
    return {text = "  ", hl = "MetaFileSignClean"}
  else
    return {text = "\226\156\185", hl = "MetaFileSignDirty"}
  end
end
local function aligned_meta_suffix(suffix, path_width)
  local txt = (suffix or "")
  local left = (string.match(txt, "^([^\t]*)\t") or txt)
  local right = (string.match(txt, "^[^\t]*\t(.*)$") or "")
  local left_w = vim.fn.strdisplaywidth(left)
  local right_w = vim.fn.strdisplaywidth(right)
  local pad
  if (right == "") then
    pad = 0
  else
    pad = math.max(0, (math.max(1, path_width) - (left_w + right_w) - 1))
  end
  local text0
  if (right == "") then
    text0 = left
  else
    text0 = (left .. string.rep(" ", pad) .. right)
  end
  local author_start
  if (right == "") then
    author_start = -1
  else
    author_start = (#left + pad)
  end
  local author_end
  if (right == "") then
    author_end = -1
  else
    author_end = (author_start + #right)
  end
  local clock_start1 = string.find(left, "\240\159\149\147", 1, true)
  local age_token
  if clock_start1 then
    age_token = (string.match(left, "\240\159\149\147([%d]+[a-z]+)$") or "")
  else
    age_token = ""
  end
  local age_start
  if (clock_start1 and (age_token ~= "")) then
    age_start = ((clock_start1 - 1) + #"\240\159\149\147")
  else
    age_start = -1
  end
  local age_end
  if (age_start >= 0) then
    age_end = (age_start + #age_token)
  else
    age_end = -1
  end
  local suffix_highlights = {}
  if (age_start >= 0) then
    table.insert(suffix_highlights, {hl = age_hl_group(age_token), start = age_start, ["end"] = age_end})
  else
  end
  if (author_start >= 0) then
    table.insert(suffix_highlights, {hl = author_hl["group-for-author"](right), start = author_start, ["end"] = author_end})
  else
  end
  return {text = text0, ["suffix-highlights"] = suffix_highlights}
end
M["info-view"] = function(session, ref, ctx)
  local mode = ((ctx and ctx.mode) or "meta")
  local path_width = ((ctx and ctx["path-width"]) or 1)
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local meta = M["info-meta"](session, ref)
  local sign = file_status_sign(((meta and meta.status) or ""))
  local suffix0 = M["info-suffix"](session, ref, mode, read_file_lines_cached)
  if (mode == "meta") then
    local laid = aligned_meta_suffix(suffix0, path_width)
    return {path = "", ["icon-path"] = ((ref and ref.path) or ""), sign = sign, suffix = (laid.text or ""), ["suffix-prefix"] = "", ["suffix-highlights"] = (laid["suffix-highlights"] or {}), ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
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
M["preview-lines"] = function(session, ref, height, read_file_lines_cached)
  local r = vim.deepcopy((ref or {}))
  r.buf = nil
  if not r["preview-lnum"] then
    r["preview-lnum"] = 1
  else
  end
  return text["preview-lines"](session, r, height, read_file_lines_cached)
end
return M
