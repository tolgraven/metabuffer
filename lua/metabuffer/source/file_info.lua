-- [nfnl] fnl/metabuffer/source/file_info.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local author_hl = require("metabuffer.author_highlight")
local transform_mod = require("metabuffer.transform")
local M = {}
local line_meta_key = nil
local line_meta_cache_hit_3f = nil
local normalized_line_numbers = nil
local missing_line_numbers = nil
local clear_pending_line_meta = nil
local parse_range_blame_stdout = nil
M["file-first-line"] = function(session, read_file_lines_cached, read_file_view_cached, path)
  local cache = (session["info-file-head-cache"] or {})
  local mtime = vim.fn.getftime(path)
  local include_binary = clj.boolean((session and session["effective-include-binary"]))
  local transform_sig = transform_mod.signature(((session and session["effective-transforms"]) or {}))
  local found = cache[path]
  if ((type(found) == "table") and (found.mtime == mtime) and (found["include-binary"] == include_binary) and (found["transform-sig"] == transform_sig) and (type(found.line) == "string")) then
    return found.line
  else
    local view = ((read_file_view_cached and read_file_view_cached(path, {["include-binary"] = include_binary, transforms = ((session and session["effective-transforms"]) or (session and session["transform-flags"]) or {})})) or {lines = (read_file_lines_cached(path, {["include-binary"] = include_binary, ["hex-view"] = (session and session["effective-include-hex"])}) or {})})
    local line0 = ((view.lines or {})[1] or "")
    local line = tostring(line0)
    cache[path] = {mtime = mtime, ["include-binary"] = include_binary, ["transform-sig"] = transform_sig, line = line}
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
local function git_line_blame_info(path, lnum)
  local rel = vim.fn.fnamemodify(path, ":.")
  local out = vim.fn.systemlist({"git", "-C", vim.fn.getcwd(), "blame", "--line-porcelain", "-L", (tostring(lnum) .. "," .. tostring(lnum)), "--", rel})
  if (vim.v.shell_error == 0) then
    return {author = (string.match(table.concat((out or {}), "\n"), "\nauthor ([^\n]+)") or ""), ["author-time"] = (tonumber((string.match(table.concat((out or {}), "\n"), "\nauthor%-time (%d+)") or "")) or 0)}
  else
    return {author = "", ["author-time"] = 0}
  end
end
local function compact_relative_age(age)
  local txt = string.lower(vim.trim((age or "")))
  local n = tonumber((string.match(txt, "^(%d+)") or ""))
  if (txt == "") then
    return ""
  else
    local _10_
    if string.find(txt, "minute") then
      _10_ = (tostring((n or 1)) .. "m")
    else
      _10_ = nil
    end
    local or_12_ = _10_
    if not or_12_ then
      if string.find(txt, "hour") then
        or_12_ = (tostring((n or 1)) .. "h")
      else
        or_12_ = nil
      end
    end
    if not or_12_ then
      if (string.find(txt, "day") or (txt == "yesterday")) then
        or_12_ = (tostring((n or 1)) .. "d")
      else
        or_12_ = nil
      end
    end
    if not or_12_ then
      if string.find(txt, "week") then
        or_12_ = (tostring((n or 1)) .. "w")
      else
        or_12_ = nil
      end
    end
    if not or_12_ then
      if string.find(txt, "month") then
        or_12_ = (tostring((n or 1)) .. "mo")
      else
        or_12_ = nil
      end
    end
    if not or_12_ then
      if string.find(txt, "year") then
        or_12_ = (tostring((n or 1)) .. "y")
      else
        or_12_ = nil
      end
    end
    return (or_12_ or "")
  end
end
local function compact_relative_age_from_epoch(epoch)
  if (epoch and (epoch > 0)) then
    local delta = math.max(0, (os.time() - epoch))
    if (delta < 60) then
      return ""
    elseif (delta < 3600) then
      return (tostring(math.floor((delta / 60))) .. "m")
    elseif (delta < 86400) then
      return (tostring(math.floor((delta / 3600))) .. "h")
    elseif (delta < (86400 * 7)) then
      return (tostring(math.floor((delta / 86400))) .. "d")
    elseif (delta < (86400 * 30)) then
      return (tostring(math.floor((delta / (86400 * 7)))) .. "w")
    elseif (delta < (86400 * 365)) then
      return (tostring(math.floor((delta / (86400 * 30)))) .. "mo")
    else
      return (tostring(math.floor((delta / (86400 * 365)))) .. "y")
    end
  else
    return ""
  end
end
local function file_meta_line(meta)
  local mtime_text = (meta["mtime-text"] or "000000")
  local git_age = (meta.age or "")
  local age_width = 3
  local age_fragment
  if (git_age ~= "") then
    age_fragment = (string.rep(" ", math.max(0, (age_width - #git_age))) .. git_age)
  else
    age_fragment = string.rep(" ", age_width)
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
  return (mtime_text .. " " .. age_fragment .. "\t " .. git_author)
end
M["file-meta-data"] = function(session, path)
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
    local text = file_meta_line(meta)
    cache[path] = vim.tbl_extend("force", meta, {text = text})
    session["info-file-meta-cache"] = cache
    return cache[path]
  end
end
local function cached_file_status(session, path)
  local cache = ((session and session["info-file-status-cache"]) or {})
  local mtime = vim.fn.getftime(path)
  local found = cache[path]
  if ((type(found) == "table") and (found.mtime == mtime) and (type(found.status) == "string")) then
    return found.status
  else
    return nil
  end
end
local function file_status_cache_hit(session, path, mtime)
  local cache = (session["info-file-status-cache"] or {})
  local found = cache[path]
  return ((type(found) == "table") and (found.mtime == mtime) and (type(found.status) == "string") and found.status)
end
local function pending_file_status_key(path, mtime)
  return (path .. ":" .. tostring(mtime))
end
local function mark_file_status_pending_21(session, key)
  local pending = (session["info-file-status-pending"] or {})
  if not pending[key] then
    pending[key] = true
    session["info-file-status-pending"] = pending
    return true
  else
    return nil
  end
end
local function clear_file_status_pending_21(session, key)
  local pending = (session["info-file-status-pending"] or {})
  pending[key] = nil
  session["info-file-status-pending"] = pending
  return nil
end
local function cache_file_status_21(session, path, mtime, status)
  local cache = (session["info-file-status-cache"] or {})
  cache[path] = {mtime = mtime, status = status}
  session["info-file-status-cache"] = cache
  return status
end
local function git_status_line__3estatus(line)
  if ((line or "") == "") then
  else
    if vim.startswith(line, "??") then
    else
      local x = string.sub(line, 1, 1)
      local y = string.sub(line, 2, 2)
      local staged_3f = (x ~= " ")
      local dirty_3f = (y ~= " ")
      if (staged_3f and dirty_3f) then
      else
        if staged_3f then
        else
          if dirty_3f then
          else
          end
        end
      end
    end
  end
  local function schedule_file_status_fetch_21(session, path, mtime, key, on_ready)
    local function _33_(obj)
      local function _34_()
        clear_file_status_pending_21(session, key)
        local line0
        if (obj.code == 0) then
          line0 = (vim.split((obj.stdout or ""), "\n", {plain = true})[1] or "")
        else
          line0 = ""
        end
        local status = git_status_line__3estatus(line0)
        cache_file_status_21(session, path, mtime, status)
        if on_ready then
          return on_ready()
        else
          return nil
        end
      end
      return vim.schedule(_34_)
    end
    return vim.system({"git", "-C", vim.fn.getcwd(), "status", "--porcelain", "--", vim.fn.fnamemodify(path, ":.")}, {}, _33_)
  end
  M["ensure-file-status-async!"] = function(session, path, on_ready)
    if (session and path and (1 == vim.fn.filereadable(path))) then
      local mtime = vim.fn.getftime(path)
      local key = pending_file_status_key(path, mtime)
      local cached = file_status_cache_hit(session, path, mtime)
      if cached then
        return cached
      else
        if mark_file_status_pending_21(session, key) then
          return schedule_file_status_fetch_21(session, path, mtime, key, on_ready)
        else
          return nil
        end
      end
    else
      return nil
    end
  end
  M["line-meta-data"] = function(session, path, lnum)
    local cache = (session["info-line-meta-cache"] or {})
    local key = (path .. ":" .. tostring(lnum))
    local mtime = vim.fn.getftime(path)
    local found = cache[key]
    if ((type(found) == "table") and (found.mtime == mtime) and (found.lnum == lnum) and (type(found.text) == "string") and (type(found.status) == "string")) then
      return found
    else
      local blame = git_line_blame_info(path, lnum)
      local author_time = (blame["author-time"] or 0)
      local author
      do
        local a = vim.trim((blame.author or ""))
        if (a == "") then
          author = "?"
        else
          author = a
        end
      end
      local meta
      local _41_
      if (author_time > 0) then
        _41_ = vim.fn.strftime("%y%m%d", author_time)
      else
        _41_ = "000000"
      end
      meta = {mtime = mtime, lnum = lnum, ["mtime-text"] = _41_, status = git_file_status(path), age = compact_relative_age_from_epoch(author_time), author = author}
      local text = file_meta_line(meta)
      cache[key] = vim.tbl_extend("force", meta, {text = text})
      session["info-line-meta-cache"] = cache
      return cache[key]
    end
  end
  local function line_meta_from_blame(session, path, lnum, mtime, blame)
    local author_time = (blame["author-time"] or 0)
    local author
    do
      local a = vim.trim((blame.author or ""))
      if (a == "") then
        author = "?"
      else
        author = a
      end
    end
    local meta
    local _45_
    if (author_time > 0) then
      _45_ = vim.fn.strftime("%y%m%d", author_time)
    else
      _45_ = "000000"
    end
    meta = {mtime = mtime, lnum = lnum, ["mtime-text"] = _45_, status = (cached_file_status(session, path) or "clean"), age = compact_relative_age_from_epoch(author_time), author = author}
    local text = file_meta_line(meta)
    return vim.tbl_extend("force", meta, {text = text})
  end
  local function _47_(path, lnum)
    return (path .. ":" .. tostring(lnum))
  end
  line_meta_key = _47_
  local function _48_(cache, path, lnum, mtime)
    local found = cache[line_meta_key(path, lnum)]
    return ((type(found) == "table") and (found.mtime == mtime) and (found.lnum == lnum))
  end
  line_meta_cache_hit_3f = _48_
  local function _49_(lnums)
    local vals = {}
    for _, lnum in ipairs((lnums or {})) do
      if ((type(lnum) == "number") and (lnum > 0)) then
        table.insert(vals, lnum)
      else
      end
    end
    return vals
  end
  normalized_line_numbers = _49_
  local function _51_(cache, path, lnums, mtime)
    local missing = {}
    for _, lnum in ipairs(lnums) do
      if not line_meta_cache_hit_3f(cache, path, lnum, mtime) then
        table.insert(missing, lnum)
      else
      end
    end
    return missing
  end
  missing_line_numbers = _51_
  local function _53_(session, key)
    local pending = (session["info-line-meta-pending"] or {})
    pending[key] = nil
    session["info-line-meta-pending"] = pending
    return nil
  end
  clear_pending_line_meta = _53_
  local function _54_(stdout)
    local rows = {}
    local state = {author = "", ["author-time"] = 0}
    for _, line0 in ipairs(vim.split((stdout or ""), "\n", {plain = true})) do
      if vim.startswith(line0, "author ") then
        state["author"] = string.sub(line0, 8)
      else
      end
      if vim.startswith(line0, "author-time ") then
        state["author-time"] = (tonumber(string.sub(line0, 13)) or 0)
      else
      end
      if vim.startswith(line0, "\t") then
        table.insert(rows, {author = state.author, ["author-time"] = state["author-time"]})
        state["author"] = ""
        state["author-time"] = 0
      else
      end
    end
    return rows
  end
  parse_range_blame_stdout = _54_
  M["ensure-line-meta-range-async!"] = function(session, path, lnums, on_ready)
    local vals = normalized_line_numbers(lnums)
    if (session and (1 == vim.fn.filereadable(path)) and (#vals > 0)) then
      local cache = (session["info-line-meta-cache"] or {})
      local mtime = vim.fn.getftime(path)
      local rel = vim.fn.fnamemodify(path, ":.")
      local missing = missing_line_numbers(cache, path, vals, mtime)
      if (#missing > 0) then
        local start_lnum = missing[1]
        local stop_lnum = missing[#missing]
        local key = (path .. ":" .. tostring(start_lnum) .. ":" .. tostring(stop_lnum) .. ":" .. tostring(mtime))
        local pending = (session["info-line-meta-pending"] or {})
        if not pending[key] then
          pending[key] = true
          session["info-line-meta-pending"] = pending
          local function _58_(obj)
            local function _59_()
              clear_pending_line_meta(session, key)
              if ((obj.code == 0) and (1 == vim.fn.filereadable(path))) then
                local rows = parse_range_blame_stdout(obj.stdout)
                local cache1 = (session["info-line-meta-cache"] or {})
                for i = 1, math.min(#missing, #rows) do
                  local lnum = missing[i]
                  local blame = rows[i]
                  local meta = line_meta_from_blame(session, path, lnum, mtime, blame)
                  cache1[line_meta_key(path, lnum)] = meta
                end
                session["info-line-meta-cache"] = cache1
              else
              end
              if on_ready then
                return on_ready()
              else
                return nil
              end
            end
            return vim.schedule(_59_)
          end
          return vim.system({"git", "-C", vim.fn.getcwd(), "blame", "--line-porcelain", "-L", (tostring(start_lnum) .. "," .. tostring(stop_lnum)), "--", rel}, {}, _58_)
        else
          return nil
        end
      else
        return nil
      end
    else
      return nil
    end
  end
  return M["ensure-line-meta-range-async!"]
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
M["file-status-sign"] = function(status)
  if (status == "untracked") then
    return {text = "\226\156\151 ", hl = "MetaFileSignUntracked"}
  elseif (status == "clean") then
    return {text = "  ", hl = "MetaFileSignClean"}
  else
    return {text = "\226\156\185", hl = "MetaFileSignDirty"}
  end
end
M["aligned-meta-suffix"] = function(suffix, path_width)
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
  local text
  if (right == "") then
    text = left
  else
    text = (left .. string.rep(" ", pad) .. right)
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
  local age_token = (string.match(left, "(%d+[a-z]+)$") or "")
  local age_start
  if (age_token ~= "") then
    local age_pos = string.find(left, (" " .. age_token), 1, true)
    if age_pos then
      age_start = age_pos
    else
      age_start = -1
    end
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
  return {text = text, ["suffix-highlights"] = suffix_highlights}
end
M["meta-info-view"] = function(session, path, path_width)
  local meta = M["file-meta-data"](session, path)
  local sign = M["file-status-sign"](((meta and meta.status) or ""))
  local laid = M["aligned-meta-suffix"](meta.text, path_width)
  return {path = "", ["icon-path"] = path, sign = sign, suffix = (laid.text or ""), ["suffix-prefix"] = "", ["suffix-highlights"] = (laid["suffix-highlights"] or {}), ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
end
M["line-meta-info-view"] = function(session, path, lnum, path_width)
  local cache = ((session and session["info-line-meta-cache"]) or {})
  local key = (path .. ":" .. tostring(lnum))
  local mtime = vim.fn.getftime(path)
  local found = cache[key]
  local meta = (((type(found) == "table") and (found.mtime == mtime) and (found.lnum == lnum) and (type(found.text) == "string") and (type(found.status) == "string") and found) or {status = "clean", text = ""})
  local laid = M["aligned-meta-suffix"](meta.text, path_width)
  return {path = "", ["icon-path"] = path, sign = {text = "  ", hl = "LineNr"}, suffix = (laid.text or ""), ["suffix-prefix"] = "", ["suffix-highlights"] = (laid["suffix-highlights"] or {}), ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
end
return M
