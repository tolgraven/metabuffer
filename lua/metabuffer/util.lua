-- [nfnl] fnl/metabuffer/util.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local mini_icons_cache = nil
local mini_icons_tried_3f = false
local function ensure_mini_icons()
  if not mini_icons_tried_3f then
    mini_icons_tried_3f = true
    local ok,mod = pcall(require, "mini.icons")
    if (ok and mod) then
      mini_icons_cache = mod
    else
    end
  else
  end
  return (_G.MiniIcons or mini_icons_cache)
end
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
M["delete-transient-unnamed-buffer!"] = function(buf)
  if not M["buf-valid?"](buf) then
    return false
  else
    local name = vim.api.nvim_buf_get_name(buf)
    local lines = vim.api.nvim_buf_line_count(buf)
    local wins = vim.fn.win_findbuf(buf)
    local attached_3f = (#(wins or {}) > 0)
    if (((name or "") == "") and (lines <= 1) and not attached_3f) then
      local bo = vim.bo[buf]
      bo["buflisted"] = false
      bo["bufhidden"] = "wipe"
      bo["swapfile"] = false
      local ok = pcall(vim.api.nvim_buf_delete, buf, {force = true})
      return ok
    else
      return false
    end
  end
end
M["mark-transient-unnamed-buffer!"] = function(buf)
  if M["buf-valid?"](buf) then
    local name = vim.api.nvim_buf_get_name(buf)
    if ((name or "") == "") then
      local bo = vim.bo[buf]
      bo["buflisted"] = false
      bo["bufhidden"] = "wipe"
      bo["swapfile"] = false
      return nil
    else
      return nil
    end
  else
    return nil
  end
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
    local rename_21
    local function _7_()
      return vim.cmd(("silent noautocmd file " .. vim.fn.fnameescape(name)))
    end
    rename_21 = _7_
    local ok = pcall(vim.api.nvim_buf_call, buf, rename_21)
    if ok then
      return name
    else
      local ok_api = pcall(vim.api.nvim_buf_set_name, buf, name)
      if ok_api then
        return name
      else
        return (base .. " [" .. buf .. "]")
      end
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
      local function _11_()
        return vim.cmd("silent! call rainbow_parentheses#deactivate()")
      end
      deactivate_21 = _11_
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
        local function _14_()
          return vim.cmd("silent! call rainbow_parentheses#activate()")
        end
        activate_21 = _14_
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
  local mini = ensure_mini_icons()
  if (mini and (type(mini.get) == "function")) then
    local ok_i,icon,icon_hl = pcall(mini.get, "file", file)
    local next_hl
    if (ok_i and (type(icon_hl) == "string") and (icon_hl ~= "")) then
      next_hl = icon_hl
    else
      next_hl = fallback_hl
    end
    local _19_
    if (ok_i and (type(icon) == "string") and (icon ~= "")) then
      _19_ = icon
    else
      _19_ = ""
    end
    return {icon = _19_, ["icon-hl"] = next_hl, ["ext-hl"] = next_hl, ["file-hl"] = fallback_hl}
  else
    return {icon = "", ["icon-hl"] = fallback_hl, ["ext-hl"] = fallback_hl, ["file-hl"] = fallback_hl}
  end
end
local function first_visible_glyph(text)
  local s = (text or "")
  local val_111_auto = string.find(s, "%S")
  if val_111_auto then
    local pos = val_111_auto
    return vim.fn.strcharpart(s, (pos - 1), 1)
  else
    return ""
  end
end
local function marker_sign(glyph, hl)
  if ((glyph or "") ~= "") then
    return {text = glyph, hl = hl, highlights = {{start = 0, ["end"] = #glyph, hl = hl}}}
  else
    return {text = "  ", hl = "LineNr"}
  end
end
M["icon-sign"] = function(spec)
  local marker = (spec or {})
  local mini = ensure_mini_icons()
  local icon_result
  if (mini and (type(mini.get) == "function") and ((marker.category or "") ~= "")) then
    icon_result = {pcall(mini.get, marker.category, marker.name)}
  else
    icon_result = {false, nil, nil}
  end
  local ok = icon_result[1]
  local glyph = icon_result[2]
  local hl = icon_result[3]
  local text
  if (ok and (type(glyph) == "string") and (glyph ~= "")) then
    text = glyph
  else
    text = marker.fallback
  end
  local sign_hl
  if (ok and (type(hl) == "string") and (hl ~= "")) then
    sign_hl = hl
  else
    sign_hl = marker.hl
  end
  return marker_sign(text, sign_hl)
end
M["combine-signs"] = function(primary, secondary)
  local left = first_visible_glyph((primary and primary.text))
  local right = first_visible_glyph((secondary and secondary.text))
  local left_hl = ((primary and primary.hl) or "LineNr")
  local right_hl = ((secondary and secondary.hl) or "LineNr")
  local text
  if (left ~= "") then
    if ((right == "") or (vim.fn.strdisplaywidth(left) >= 2)) then
      text = left
    else
      text = (left .. right)
    end
  else
    if (right ~= "") then
      text = right
    else
      text = "  "
    end
  end
  local highs = {}
  if (left ~= "") then
    table.insert(highs, {start = 0, ["end"] = #left, hl = left_hl})
  else
  end
  if ((right ~= "") and (text ~= left)) then
    table.insert(highs, {start = #left, ["end"] = (#left + #right), hl = right_hl})
  else
  end
  local _32_
  if (left ~= "") then
    _32_ = left_hl
  else
    _32_ = right_hl
  end
  return {text = text, hl = _32_, highlights = highs}
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
