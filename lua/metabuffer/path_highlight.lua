-- [nfnl] fnl/metabuffer/path_highlight.fnl
local M = {}
local util = require("metabuffer.util")
M["sep-group"] = "MetaPathSep"
M["segment-groups"] = util["build-group-names"]("MetaPathSeg", 24)
local function normalize_segment(s)
  return string.lower(vim.trim(tostring((s or ""))))
end
local function split_dir_segments(dir)
  local txt = (dir or "")
  local raw = vim.split(txt, "/", {plain = true})
  local out = {}
  for _, seg in ipairs(raw) do
    if (seg ~= "") then
      table.insert(out, seg)
    else
    end
  end
  return out
end
local function map_display_to_original(display_segments, original_segments)
  local disp = (display_segments or {})
  local orig = (original_segments or {})
  local mapped = {}
  for _ = 1, #disp do
    table.insert(mapped, nil)
  end
  if (#disp == #orig) then
    for i = 1, #disp do
      mapped[i] = orig[i]
    end
  else
    if ((#disp > 0) and (#orig > 0) and not vim.startswith((disp[1] or ""), "\226\128\166")) then
      mapped[1] = orig[1]
    else
    end
    local di = #disp
    local oi = #orig
    while ((di >= 1) and (oi >= 1)) do
      if (mapped[di] == nil) then
        mapped[di] = orig[oi]
      else
      end
      di = (di - 1)
      oi = (oi - 1)
    end
  end
  return mapped
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
M["ranges-for-dir"] = function(dir, start_col, original_dir)
  local txt = (dir or "")
  local original_segments = split_dir_segments((original_dir or dir))
  local display_segments = split_dir_segments(dir)
  local bucket_segments = map_display_to_original(display_segments, original_segments)
  local out = {}
  local col = (start_col or 0)
  local token = ""
  local token_start = col
  local seg_idx = 0
  for i = 1, #txt do
    local ch = string.sub(txt, i, i)
    if (ch == "/") then
      if (#token > 0) then
        seg_idx = (seg_idx + 1)
        do
          local bucket_segment = (bucket_segments[seg_idx] or display_segments[seg_idx] or token)
          table.insert(out, {start = token_start, ["end"] = col, hl = M["group-for-segment"](bucket_segment)})
        end
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
    seg_idx = (seg_idx + 1)
    local bucket_segment = (bucket_segments[seg_idx] or display_segments[seg_idx] or token)
    table.insert(out, {start = token_start, ["end"] = col, hl = M["group-for-segment"](bucket_segment)})
  else
  end
  return out
end
return M
