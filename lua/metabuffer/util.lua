-- [nfnl] fnl/metabuffer/util.fnl
local M = {}
M["split-input"] = function(text)
  return vim.split((text or ""), "%s+", {trimempty = true})
end
M["convert2regex-pattern"] = function(text)
  return table.concat(M["split-input"](text), "\\|")
end
M["assign-content"] = function(buf, lines)
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
M["escape-vim-pattern"] = function(text)
  return vim.fn.escape((text or ""), "\\^$~.*[]")
end
M["query-is-lower"] = function(query)
  return (string.lower((query or "")) == (query or ""))
end
M["buf-valid?"] = function(buf)
  return (buf and vim.api.nvim_buf_is_valid(buf))
end
M["win-valid?"] = function(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
M.deepcopy = function(x)
  return vim.deepcopy(x)
end
M.clamp = function(n, lo, hi)
  return math.max(lo, math.min(hi, n))
end
M["build-group-names"] = function(prefix, count)
  local groups = {}
  for i = 1, count do
    table.insert(groups, (prefix .. i))
  end
  return groups
end
M["ext-from-path"] = function(path)
  local file = vim.fn.fnamemodify((path or ""), ":t")
  local dot = string.match(file, ".*()%.")
  if (dot and (dot > 0) and (dot < #file)) then
    return string.sub(file, (dot + 1))
  else
    return ""
  end
end
M["devicon-info"] = function(path, fallback_hl)
  local file = vim.fn.fnamemodify((path or ""), ":t")
  local ext = M["ext-from-path"](path)
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
M["buf-lines"] = function(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end
M.cursor = function()
  return vim.api.nvim_win_get_cursor(0)
end
M["set-cursor"] = function(row, col)
  return vim.api.nvim_win_set_cursor(0, {row, (col or 0)})
end
return M
