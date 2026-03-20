-- [nfnl] fnl/metabuffer/path_highlight.fnl
local M = {}
local util = require("metabuffer.util")
M["sep-group"] = "MetaPathSep"
M["segment-groups"] = util["build-group-names"]("MetaPathSeg", 24)
local function normalize_segment(s)
  return string.lower(vim.trim(tostring((s or ""))))
end
M["group-for-segment"] = function(segment)
  local key = normalize_segment(segment)
  local n = math.max(1, #M["segment-groups"])
  if (key == "") then
    return M["segment-groups"][1]
  else
    local acc0 = 5381
    local acc = acc0
    for i = 1, #key do
      acc = (((acc * 33) + string.byte(key, i)) % 2147483647)
    end
    return M["segment-groups"][((acc % n) + 1)]
  end
end
M["ranges-for-dir"] = function(dir, start_col)
  local txt = (dir or "")
  local out = {}
  local col = (start_col or 0)
  local token = ""
  local token_start = col
  for i = 1, #txt do
    local ch = string.sub(txt, i, i)
    if (ch == "/") then
      if (#token > 0) then
        table.insert(out, {start = token_start, ["end"] = col, hl = M["group-for-segment"](token)})
        token = ""
      else
      end
      table.insert(out, {start = col, ["end"] = (col + 1), hl = M["sep-group"]})
      col = (col + 1)
      token_start = col
    else
      if (#token == 0) then
        token_start = col
      else
      end
      token = (token .. ch)
      col = (col + 1)
    end
  end
  if (#token > 0) then
    table.insert(out, {start = token_start, ["end"] = col, hl = M["group-for-segment"](token)})
  else
  end
  return out
end
return M
