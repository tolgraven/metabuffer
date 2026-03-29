-- [nfnl] fnl/metabuffer/window/statusline.fnl
local path_highlight = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
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
    return ((opts or {})["sep-group"] or (opts or {})["file-group"] or "MetaPreviewStatuslinePathFile")
  else
    if vim.startswith(h, "MetaPathSeg") then
      return (((opts or {})["seg-prefix"] or "MetaPreviewStatuslinePathSeg") .. string.sub(h, (#"MetaPathSeg" + 1)))
    else
      return ((opts or {})["file-group"] or "MetaPreviewStatuslinePathFile")
    end
  end
end
M["render-path"] = function(path, opts)
  local default_text = ((opts or {})["default-text"] or "Preview")
  local file_group = ((opts or {})["file-group"] or "MetaPreviewStatuslinePathFile")
  local base_group = ((opts or {})["base-group"] or file_group)
  local left_pad = ((opts or {})["left-pad"] or " ")
  local right_pad = ((opts or {})["right-pad"] or " ")
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
    local icon_info = util["file-icon-info"](path, file_group)
    local icon = (icon_info.icon or "")
    local icon_hl = (icon_info["icon-hl"] or file_group)
    local ext_hl = (icon_info["ext-hl"] or file_group)
    local dot = string.match(file, ".*()%.")
    local base_file
    if (dot and (dot > 1)) then
      base_file = string.sub(file, 1, (dot - 1))
    else
      base_file = file
    end
    local ext_file
    if (dot and (dot > 0) and (dot < #file)) then
      ext_file = string.sub(file, dot)
    else
      ext_file = ""
    end
    local out = {(M.reset(base_group) .. left_pad)}
    for _, dr in ipairs(ranges) do
      local seg = string.sub(dirtxt, (dr.start + 1), dr["end"])
      table.insert(out, ("%#" .. path_hl(dr.hl, opts) .. "#" .. M.escape(seg)))
    end
    if (#icon > 0) then
      table.insert(out, ("%#" .. icon_hl .. "#" .. M.escape(icon) .. " "))
    else
    end
    if (#base_file > 0) then
      table.insert(out, ("%#" .. file_group .. "#" .. M.escape(base_file)))
    else
    end
    if (#ext_file > 0) then
      table.insert(out, ("%#" .. ext_hl .. "#" .. M.escape(ext_file)))
    else
    end
    table.insert(out, (M.reset(base_group) .. right_pad))
    return table.concat(out, "")
  else
    return (M.reset(base_group) .. left_pad .. default_text .. right_pad)
  end
end
return M
