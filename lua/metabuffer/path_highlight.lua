-- [nfnl] fnl/metabuffer/path_highlight.fnl
local M = {}
local util = require("metabuffer.util")
M["sep-group"] = "MetaPathSep"
M["segment-groups"] = util["build-group-names"]("MetaPathSeg", 24)
M["segment->group"] = {}
M["next-group-idx"] = 1
local function normalize_segment(s)
  local txt = string.lower(tostring((s or "")))
  if (txt == "") then
    return ""
  else
    return string.sub(txt, 1, 1)
  end
end
M["group-for-segment"] = function(segment)
  local key = normalize_segment(segment)
  local existing = M["segment->group"][key]
  if existing then
    return M["segment-groups"][existing]
  else
    local idx = math.max(1, math.min((M["next-group-idx"] or 1), #M["segment-groups"]))
    M["segment->group"][key] = idx
    if (idx < #M["segment-groups"]) then
      M["next-group-idx"] = (idx + 1)
    else
      M["next-group-idx"] = 1
    end
    return M["segment-groups"][idx]
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
