-- [nfnl] fnl/metabuffer/prompt/key.fnl
local util = require("metabuffer.prompt.util")
local M = {}
M.SPECIAL_KEYS = {CR = "<CR>", ESC = "<Esc>", BS = "<BS>", TAB = "<Tab>", ["S-TAB"] = "<S-Tab>", DEL = "<Del>", LEFT = "<Left>", RIGHT = "<Right>", UP = "<Up>", DOWN = "<Down>", INSERT = "<Insert>", HOME = "<Home>", END = "<End>", PAGEUP = "<PageUp>", PAGEDOWN = "<PageDown>"}
local cache = {}
local reverse_termcodes = nil
M.EXTRA_KEYS = {"<LeftMouse>", "<LeftRelease>", "<MiddleMouse>", "<MiddleRelease>", "<RightMouse>", "<RightRelease>", "<2-LeftMouse>", "<ScrollWheelUp>", "<ScrollWheelDown>"}
local function canonical_token(s)
  if ((type(s) == "string") and vim.startswith(s, "<") and vim.endswith(s, ">")) then
    local inner = string.sub(s, 2, (#s - 1))
    if string.find(inner, ":", 1, true) then
      return s
    else
      return ("<" .. string.upper(inner) .. ">")
    end
  else
    return s
  end
end
local function ensure_reverse_termcodes()
  if not reverse_termcodes then
    reverse_termcodes = {}
    local tokens = {}
    for _, v in pairs(M.SPECIAL_KEYS) do
      table.insert(tokens, v)
    end
    for _, v in ipairs(M.EXTRA_KEYS) do
      table.insert(tokens, v)
    end
    for _, tok in ipairs(tokens) do
      local canonical = canonical_token(tok)
      local encoded = vim.keycode(tok)
      local trans = vim.fn.keytrans(encoded)
      reverse_termcodes[encoded] = canonical
      reverse_termcodes[trans] = canonical
    end
  else
  end
  return reverse_termcodes
end
local function decode_special_string(s)
  if (type(s) == "string") then
    return ensure_reverse_termcodes()[s]
  else
    return nil
  end
end
local function normalize(expr)
  if (type(expr) == "number") then
    return canonical_token(vim.fn.keytrans(util.int2char(expr)))
  elseif (type(expr) == "string") then
    if (vim.startswith(expr, "<") and vim.endswith(expr, ">")) then
      return canonical_token(expr)
    else
      local or_5_ = decode_special_string(expr)
      if not or_5_ then
        local trans = vim.fn.keytrans(expr)
        or_5_ = (decode_special_string(trans) or canonical_token(trans))
      end
      return or_5_
    end
  else
    return tostring(expr)
  end
end
M.represent = function(_, code)
  if (type(code) == "number") then
    return canonical_token(vim.fn.keytrans(util.int2char(code)))
  elseif (type(code) == "string") then
    return code
  else
    return tostring(code)
  end
end
M.parse = function(_, expr)
  local k = normalize(expr)
  if cache[k] then
    return cache[k]
  else
    local char = M.represent(nil, k)
    local obj = {code = k, char = char}
    cache[k] = obj
    return obj
  end
end
return M
