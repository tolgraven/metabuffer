local util = require("metabuffer.prompt.util")
local M = {}
M.SPECIAL_KEYS = {[{"CR"}] = "<CR>", [{"ESC"}] = "<Esc>", [{"BS"}] = "<BS>", [{"TAB"}] = "<Tab>", [{"S-TAB"}] = "<S-Tab>", [{"DEL"}] = "<Del>", [{"LEFT"}] = "<Left>", [{"RIGHT"}] = "<Right>", [{"UP"}] = "<Up>", [{"DOWN"}] = "<Down>", [{"INSERT"}] = "<Insert>", [{"HOME"}] = "<Home>", [{"END"}] = "<End>", [{"PAGEUP"}] = "<PageUp>", [{"PAGEDOWN"}] = "<PageDown>"}
local cache = {}
local function normalize(expr)
  return cond((type(expr) == "number"), expr, (type(expr) == "string"), expr, true, tostring(expr))
end
M.represent = function(_, code)
  return cond((type(code) == "number"), util.int2char(code), (type(code) == "string"), code, true, tostring(code))
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
