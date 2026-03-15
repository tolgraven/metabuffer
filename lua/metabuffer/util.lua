-- [nfnl] fnl/metabuffer/util.fnl
local str = require("io.gitlab.andreyorst.cljlib.string")
local str_join = str.join
local str_lower_case = str["lower-case"]
local str_substring = str.substring
local str_match = str.match
local join_pattern = "\\|"
local ext_pattern = ".*()%."
local split_input = function(text)
  return vim.split((text or ""), "%s+", {trimempty = true})
end
local convert2regex_pattern = function(text)
  return str_join(join_pattern, split_input(text))
end
local assign_content = function(buf, lines)
  local view = vim.fn.winsaveview()
  do
    local bo = vim.bo[buf]
    bo["modifiable"] = true
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  do
    local bo = vim.bo[buf]
    bo["modifiable"] = false
  end
  return vim.fn.winrestview(view)
end
local escape_vim_pattern = function(text)
  return vim.fn.escape((text or ""), "\\^$~.*[]")
end
local query_is_lower = function(query)
  return (str_lower_case(query) == (query or ""))
end
local buf_valid_3f = function(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
local win_valid_3f = function(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
local deepcopy = function(x)
  return vim.deepcopy(x)
end
local clamp = function(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end
local build_group_names = function(prefix, count)
  local groups = {}
  for i = 1, count do
    table.insert(groups, (prefix .. i))
  end
  return groups
end
local ext_from_path = function(path)
  local file = vim.fn.fnamemodify((path or ""), ":t")
  local dot = str_match(file, ext_pattern)
  if (dot and (dot > 0) and (dot < #file)) then
    return str_substring(file, (dot + 1))
  else
    return ""
  end
end
local devicon_info = function(path, fallback_hl)
  local file = vim.fn.fnamemodify((path or ""), ":t")
  local ext = ext_from_path(path)
  local ok_web,web = pcall(require, "nvim-web-devicons")
  if (ok_web and web) then
    local ok_i,icon,icon_hl = pcall(web.get_icon, file, ext, {default = true})
    local next_hl
    if (ok_i and (type(icon_hl) == "string") and (icon_hl ~= "")) then
      next_hl = icon_hl
    else
      next_hl = fallback_hl
    end
    local _3_
    if (ok_i and (type(icon) == "string") and (icon ~= "")) then
      _3_ = icon
    else
      _3_ = ""
    end
    return {icon = _3_, ["icon-hl"] = next_hl, ["ext-hl"] = next_hl, ["file-hl"] = fallback_hl}
  else
    if (1 == vim.fn.exists("*WebDevIconsGetFileTypeSymbol")) then
      local icon = vim.fn.WebDevIconsGetFileTypeSymbol(file)
      local _5_
      if ((type(icon) == "string") and (icon ~= "")) then
        _5_ = icon
      else
        _5_ = ""
      end
      return {icon = _5_, ["icon-hl"] = fallback_hl, ["ext-hl"] = fallback_hl, ["file-hl"] = fallback_hl}
    else
      return {icon = "", ["icon-hl"] = fallback_hl, ["ext-hl"] = fallback_hl, ["file-hl"] = fallback_hl}
    end
  end
end
local buf_lines = function(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
local cursor = function()
  return vim.api.nvim_win_get_cursor(0)
end
local set_cursor = function(row, col)
  return vim.api.nvim_win_set_cursor(0, {row, (col or 0)})
end
return {["split-input"] = split_input, ["convert2regex-pattern"] = convert2regex_pattern, ["assign-content"] = assign_content, ["escape-vim-pattern"] = escape_vim_pattern, ["query-is-lower"] = query_is_lower, ["buf-valid?"] = buf_valid_3f, ["win-valid?"] = win_valid_3f, deepcopy = deepcopy, clamp = clamp, ["build-group-names"] = build_group_names, ["ext-from-path"] = ext_from_path, ["devicon-info"] = devicon_info, ["buf-lines"] = buf_lines, cursor = cursor, ["set-cursor"] = set_cursor}
