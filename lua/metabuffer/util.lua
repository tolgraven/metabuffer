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
M["set-buffer-name!"] = function(buf, base_name)
  if not M["buf-valid?"](buf) then
    return (base_name or "")
  else
    local base = (base_name or "metabuffer")
    local name0 = base
    local name = name0
    local n = 1
    while ((vim.fn.bufnr(name) > 0) and (vim.fn.bufnr(name) ~= buf)) do
      n = (n + 1)
      name = (base .. " [" .. n .. "]")
    end
    local ok = pcall(vim.api.nvim_buf_set_name, buf, name)
    if ok then
      return name
    else
      return (base .. " [" .. buf .. "]")
    end
  end
end
M["disable-heavy-buffer-features!"] = function(buf)
  if M["buf-valid?"](buf) then
    pcall(vim.api.nvim_buf_set_var, buf, "conjure_disable", true)
    pcall(vim.api.nvim_buf_set_var, buf, "lsp_disabled", 1)
    pcall(vim.api.nvim_buf_set_var, buf, "gitgutter_enabled", 0)
    pcall(vim.api.nvim_buf_set_var, buf, "gitsigns_disable", true)
    pcall(vim.diagnostic.enable, false, {bufnr = buf})
    if (1 == vim.fn.exists("*rainbow_parentheses#deactivate")) then
      pcall(vim.api.nvim_buf_set_var, buf, "metabuffer_rainbow_parentheses_disabled", true)
      local deactivate_21
      local function _3_()
        return vim.cmd("silent! call rainbow_parentheses#deactivate()")
      end
      deactivate_21 = _3_
      return pcall(vim.api.nvim_buf_call, buf, deactivate_21)
    else
      return nil
    end
  else
    return nil
  end
end
M["restore-heavy-buffer-features!"] = function(buf)
  if M["buf-valid?"](buf) then
    local ok,disabled_3f = pcall(vim.api.nvim_buf_get_var, buf, "metabuffer_rainbow_parentheses_disabled")
    if (ok and disabled_3f and (1 == vim.fn.exists("*rainbow_parentheses#activate"))) then
      do
        local activate_21
        local function _6_()
          return vim.cmd("silent! call rainbow_parentheses#activate()")
        end
        activate_21 = _6_
        pcall(vim.api.nvim_buf_call, buf, activate_21)
      end
      return pcall(vim.api.nvim_buf_del_var, buf, "metabuffer_rainbow_parentheses_disabled")
    else
      return nil
    end
  else
    return nil
  end
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
    local _11_
    if (ok_i and (type(icon) == "string") and (icon ~= "")) then
      _11_ = icon
    else
      _11_ = ""
    end
    return {icon = _11_, ["icon-hl"] = next_hl, ["ext-hl"] = next_hl, ["file-hl"] = fallback_hl}
  else
    if (1 == vim.fn.exists("*WebDevIconsGetFileTypeSymbol")) then
      local icon = vim.fn.WebDevIconsGetFileTypeSymbol(file)
      local _13_
      if ((type(icon) == "string") and (icon ~= "")) then
        _13_ = icon
      else
        _13_ = ""
      end
      return {icon = _13_, ["icon-hl"] = fallback_hl, ["ext-hl"] = fallback_hl, ["file-hl"] = fallback_hl}
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
