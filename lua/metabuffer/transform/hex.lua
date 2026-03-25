-- [nfnl] fnl/metabuffer/transform/hex.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M["transform-key"] = "hex"
M["query-directive-specs"] = {{kind = "toggle", long = "hex", ["token-key"] = "include-hex", doc = "Render binary files through hex view.", ["compat-key"] = "hex"}}
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
local function hex_byte(b)
  return string.format("%02X", b)
end
local function ascii_byte(b)
  if ((b >= 32) and (b <= 126)) then
    return string.char(b)
  else
    return "."
  end
end
local function hex_view_lines(blob, size)
  local lines = {header_line(size)}
  local n = #(blob or "")
  for offset = 0, (n - 1), 16 do
    local hex_left = {}
    local hex_right = {}
    local ascii = {}
    local line_end = math.min(n, (offset + 16))
    for i = offset, (line_end - 1) do
      local b = string.byte(blob, (i + 1))
      local _7_
      if ((i - offset) < 8) then
        _7_ = hex_left
      else
        _7_ = hex_right
      end
      table.insert(_7_, hex_byte(b))
      table.insert(ascii, ascii_byte(b))
    end
    local left_str = table.concat(hex_left, " ")
    local right_str = table.concat(hex_right, " ")
    local left_pad = string.rep(" ", math.max(0, (23 - #left_str)))
    local right_pad = string.rep(" ", math.max(0, (23 - #right_str)))
    local ascii_str = table.concat(ascii, "")
    table.insert(lines, string.format("%08X: %s%s  %s%s  %s", offset, left_str, left_pad, right_str, right_pad, ascii_str))
  end
  return lines
end
M["should-apply-file?"] = function(_path, _raw_lines, ctx)
  return clj.boolean((ctx and ctx.binary))
end
M["apply-file"] = function(path, _raw_lines, ctx)
  local blob = read_bytes(path)
  if blob then
    return hex_view_lines(blob, (ctx and ctx.size))
  else
    return nil
  end
end
local function parse_hex_line(line)
  local trimmed = vim.trim((line or ""))
  if ((trimmed ~= "") and not vim.startswith(trimmed, "binary ")) then
    local payload = string.match(trimmed, "^[0-9A-Fa-f]+:%s*(.+)$")
    if (payload and (payload ~= "")) then
      local out = {}
      do
        local hex_zone
        if (#payload >= 48) then
          hex_zone = string.sub(payload, 1, 48)
        else
          hex_zone = payload
        end
        for _, tok in ipairs(vim.split(hex_zone, "%s+", {trimempty = true, plain = false})) do
          if string.match(tok, "^[0-9A-Fa-f][0-9A-Fa-f]$") then
            table.insert(out, tonumber(tok, 16))
          else
          end
        end
      end
      return out
    else
      return nil
    end
  else
    return nil
  end
end
M["reverse-file"] = function(lines, _ctx)
  local bytes = {}
  for _, line in ipairs((lines or {})) do
    for _0, b in ipairs((parse_hex_line(line) or {})) do
      table.insert(bytes, b)
    end
  end
  local chars = {}
  for _, b in ipairs(bytes) do
    table.insert(chars, string.char(b))
  end
  return table.concat(chars)
end
return M
