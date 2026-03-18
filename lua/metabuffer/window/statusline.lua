-- [nfnl] fnl/metabuffer/window/statusline.fnl
local path_highlight = require("metabuffer.path_highlight")
local M = {}
M.escape = function(s)
  return string.gsub((s or ""), "%%", "%%%%")
end
M["title-case"] = function(s)
  if ((type(s) == "string") and (#s > 0)) then
    return (string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2)))
  else
    return ""
  end
end
M.reset = function(group)
  if ((type(group) == "string") and (group ~= "")) then
    return ("%#" .. group .. "#")
  else
    return "%*"
  end
end
local function path_hl(hl, opts)
  local h = (hl or "")
  if (h == "MetaPathSep") then
    return ((opts or {})["sep-group"] or (opts or {})["file-group"] or "MetaStatuslinePathFile")
  else
    if vim.startswith(h, "MetaPathSeg") then
      return (((opts or {})["seg-prefix"] or "MetaStatuslinePathSeg") .. string.sub(h, (#"MetaPathSeg" + 1)))
    else
      return ((opts or {})["file-group"] or "MetaStatuslinePathFile")
    end
  end
end
M["render-path"] = function(path, opts)
  local default_text = ((opts or {})["default-text"] or "Preview")
  local file_group = ((opts or {})["file-group"] or "MetaStatuslinePathFile")
  local base_group = ((opts or {})["base-group"] or file_group)
  if ((type(path) == "string") and (path ~= "")) then
    local short = vim.fn.fnamemodify(path, ":~:.")
    local file = vim.fn.fnamemodify(short, ":t")
    local dir0 = vim.fn.fnamemodify(short, ":h")
    local dir
    if (dir0 == ".") then
      dir = ""
    else
      dir = dir0
    end
    local dirtxt
    if (dir == "") then
      dirtxt = ""
    else
      dirtxt = (dir .. "/")
    end
    local ranges = path_highlight["ranges-for-dir"](dirtxt, 0)
    local out = {(M.reset(base_group) .. " ")}
    for _, dr in ipairs(ranges) do
      local seg = string.sub(dirtxt, (dr.start + 1), dr["end"])
      table.insert(out, ("%#" .. path_hl(dr.hl, opts) .. "#" .. M.escape(seg)))
    end
    if (#file > 0) then
      table.insert(out, ("%#" .. file_group .. "#" .. M.escape(file)))
    else
    end
    table.insert(out, (M.reset(base_group) .. " "))
    return table.concat(out, "")
  else
    return (M.reset(base_group) .. " " .. default_text .. " ")
  end
end
return M
