-- [nfnl] fnl/metabuffer/transform/strings.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M["transform-key"] = "strings"
M["query-directive-specs"] = {{kind = "toggle", long = "strings", ["token-key"] = "include-strings", doc = "Extract printable strings from binary files.", ["compat-key"] = "strings"}}
local function header_line(size)
  local kb = math.max(1, math.floor((math.max(0, (size or 0)) / 1024)))
  return ("binary " .. tostring(kb) .. " KB")
end
local function read_bytes(path)
  local uv = (vim.uv or vim.loop)
  if (uv and uv.fs_open and uv.fs_read and uv.fs_close and path) then
    local ok_open,fd = pcall(uv.fs_open, path, "r", 438)
    if (ok_open and fd) then
      local size
      local and_1_ = uv.fs_fstat
      if and_1_ then
        local ok_stat,stat = pcall(uv.fs_fstat, fd)
        and_1_ = (ok_stat and stat and stat.size)
      end
      size = (and_1_ or 0)
      local ok_read,chunk = pcall(uv.fs_read, fd, size, 0)
      pcall(uv.fs_close, fd)
      if ok_read then
        return (chunk or "")
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
local function printable_byte_3f(b)
  return ((b == 9) or (b >= 32))
end
local function extract_strings(blob)
  local out = {}
  local acc = {}
  local start = nil
  local idx = 1
  local flush_21
  local function _6_()
    if (#acc >= 4) then
      table.insert(out, {text = table.concat(acc), start = start, finish = (idx - 1)})
    else
    end
    acc = {}
    return nil
  end
  flush_21 = _6_
  for _, b in ipairs({string.byte((blob or ""), 1, -1)}) do
    if (b and (b < 127) and printable_byte_3f(b)) then
      if (#acc == 0) then
        start = idx
      else
      end
      table.insert(acc, string.char(b))
    else
      flush_21()
      start = nil
    end
    idx = (idx + 1)
  end
  flush_21()
  return out
end
local function strings_lines(path, size)
  local blob = read_bytes(path)
  local out = (blob and extract_strings(blob))
  if out then
    local with_head = {header_line(size)}
    for _, item in ipairs(out) do
      table.insert(with_head, (item.text or ""))
    end
    return with_head
  else
    return nil
  end
end
local function rebuild_blob(blob, extracted, edited)
  local parts = {}
  local cursor0 = 1
  local cursor = cursor0
  for idx, item in ipairs((extracted or {})) do
    local start = (item.start or cursor)
    local finish = (item.finish or (start - 1))
    local replacement = ((edited or {})[idx] or item.text or "")
    table.insert(parts, string.sub(blob, cursor, (start - 1)))
    table.insert(parts, replacement)
    cursor = (finish + 1)
  end
  table.insert(parts, string.sub(blob, cursor))
  return table.concat(parts)
end
M["should-apply-file?"] = function(_path, _raw_lines, ctx)
  return clj.boolean((ctx and ctx.binary))
end
M["apply-file"] = function(path, _raw_lines, ctx)
  return strings_lines(path, (ctx and ctx.size))
end
M["reverse-file"] = function(lines, ctx)
  local path = (ctx and ctx.path)
  local blob = (path and read_bytes(path))
  local extracted = (blob and extract_strings(blob))
  local body_lines = vim.deepcopy((lines or {}))
  if ((#body_lines > 0) and vim.startswith((body_lines[1] or ""), "binary ")) then
    table.remove(body_lines, 1)
  else
  end
  if (not blob or not extracted or (#body_lines ~= #extracted)) then
    return nil
  else
    return rebuild_blob(blob, extracted, body_lines)
  end
end
return M
