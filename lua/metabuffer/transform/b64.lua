-- [nfnl] fnl/metabuffer/transform/b64.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M["transform-key"] = "b64"
M["query-directive-specs"] = {{kind = "toggle", long = "b64", ["token-key"] = "include-b64", doc = "Decode obvious base64 text before display and filtering.", ["compat-key"] = "b64"}}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function decode_base64(txt)
  if (vim.base64 and (type(vim.base64.decode) == "function")) then
    local ok,decoded = pcall(vim.base64.decode, txt)
    if ok then
      return decoded
    else
      return nil
    end
  else
    local clean = string.gsub((txt or ""), "%s+", "")
    local out = {}
    local chunk0 = 0
    local bits0 = 0
    local valid_3f0 = true
    local chunk = chunk0
    local bits = bits0
    local valid_3f = valid_3f0
    for i = 1, #clean do
      local ch = string.sub(clean, i, i)
      if not (ch == "=") then
        local idx = string.find(alphabet, ch, 1, true)
        if idx then
          chunk = ((chunk * 64) + (idx - 1))
          bits = (bits + 6)
          while (bits >= 8) do
            bits = (bits - 8)
            table.insert(out, string.char((math.floor((chunk / (2 ^ bits))) % 256)))
          end
        else
          valid_3f = false
        end
      else
      end
    end
    if valid_3f then
      return table.concat(out)
    else
      return nil
    end
  end
end
local function obvious_base64_token(line)
  local trimmed = vim.trim((line or ""))
  local quoted = (string.match(trimmed, "^\"([A-Za-z0-9+/=_-]+)\"$") or string.match(trimmed, "^'([A-Za-z0-9+/=_-]+)'$"))
  local token = (quoted or trimmed)
  if ((#token >= 8) and (0 == (#token % 4)) and (nil ~= string.match(token, "^[A-Za-z0-9+/=_-]+$"))) then
    return token
  else
    return nil
  end
end
local function printable_ratio(s)
  local txt = (s or "")
  local n = #txt
  if (n == 0) then
    return 0
  else
    local score0 = 0
    local score = score0
    for i = 1, n do
      local b = string.byte(txt, i)
      if ((b == 9) or (b == 10) or (b == 13) or ((b >= 32) and (b < 127))) then
        score = (score + 1)
      else
      end
    end
    return (score / n)
  end
end
M["should-apply-line?"] = function(line, _ctx)
  return clj.boolean(obvious_base64_token(line))
end
M["apply-line"] = function(line, _ctx)
  local val_110_auto = obvious_base64_token(line)
  if val_110_auto then
    local token = val_110_auto
    local max_runs = 3
    local current = token
    local last_decoded = nil
    local cur = current
    local out = last_decoded
    for _ = 1, max_runs do
      if cur then
        local decoded = decode_base64(cur)
        if (decoded and (printable_ratio(decoded) >= 0.9)) then
          out = decoded
          cur = obvious_base64_token(decoded)
        else
          cur = nil
        end
      else
      end
    end
    if (out and (out ~= "")) then
      return vim.split(out, "\n", {plain = true, trimempty = false})
    else
      return nil
    end
  else
    return nil
  end
end
local function encode_base64(txt)
  if (vim.base64 and (type(vim.base64.encode) == "function")) then
    local ok,encoded = pcall(vim.base64.encode, txt)
    if ok then
      return encoded
    else
      return nil
    end
  else
    local bytes = {string.byte((txt or ""), 1, -1)}
    local out = {}
    local n = #bytes
    for i = 1, n, 3 do
      local b1 = (bytes[i] or 0)
      local b2 = (bytes[(i + 1)] or 0)
      local b3 = (bytes[(i + 2)] or 0)
      local chunk = ((b1 * 65536) + (b2 * 256) + b3)
      local c1 = (1 + math.floor((chunk / 262144)))
      local c2 = (1 + (math.floor((chunk / 4096)) % 64))
      local c3 = (1 + (math.floor((chunk / 64)) % 64))
      local c4 = (1 + (chunk % 64))
      local rem = (n - i - -1)
      table.insert(out, string.sub(alphabet, c1, c1))
      table.insert(out, string.sub(alphabet, c2, c2))
      local function _14_()
        if (rem >= 2) then
          return string.sub(alphabet, c3, c3)
        else
          return "="
        end
      end
      table.insert(out, _14_())
      local function _15_()
        if (rem >= 3) then
          return string.sub(alphabet, c4, c4)
        else
          return "="
        end
      end
      table.insert(out, _15_())
    end
    return table.concat(out)
  end
end
M["reverse-line"] = function(lines, _ctx)
  local decoded = table.concat((lines or {}), "\n")
  local encoded = encode_base64(decoded)
  return (encoded and {encoded})
end
return M
