-- [nfnl] fnl/metabuffer/init.fnl
local router = require("metabuffer.router")
local config = require("metabuffer.config")
local PRIMARY_LINE_GROUPS = {"Title", "String", "Number", "Special", "Type", "Identifier"}
local M = {}
local PATH_SEG_GROUPS = {"Directory", "Identifier", "Type", "Special", "String", "Constant", "Function", "Statement", "PreProc", "Keyword", "Operator", "Character", "Tag", "Delimiter", "Number", "Boolean", "Macro", "Title", "Question", "Exception", "DiffAdd", "DiffChange", "DiffText", "DiagnosticInfo"}
local AUTHOR_GROUPS = {"Identifier", "Type", "Special", "String", "Constant", "Function", "Statement", "PreProc", "Keyword", "Operator", "Character", "Tag", "Delimiter", "Number", "Boolean", "Macro", "Title", "Question", "Exception", "DiffAdd", "DiffChange", "DiffText", "DiagnosticInfo", "DiagnosticHint"}
local function rgb_luma(n)
  if not n then
    return nil
  else
    local r = math.floor((n / 65536))
    local g = math.floor(((n / 256) % 256))
    local b = (n % 256)
    return ((0.2126 * r) + (0.7152 * g) + (0.0722 * b))
  end
end
local function hl_rendered_fg(hl)
  if (hl and hl.reverse) then
    return (hl.bg or hl.fg)
  else
    return hl.fg
  end
end
local function hl_rendered_bg(hl)
  if (hl and hl.reverse) then
    return (hl.fg or hl.bg)
  else
    return hl.bg
  end
end
local meta_statusline_bg = nil
local meta_preview_statusline_bg = nil
local refresh_augroup = nil
local last_setup_opts = nil
local function statusline_color_from(group)
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  if (ok and (type(hl) == "table")) then
    local fg = hl.fg
    local cfg = hl.ctermfg
    if fg then
      opts["fg"] = fg
    else
      if (ok_sl and (type(sl) == "table")) then
        opts["fg"] = hl_rendered_fg(sl)
      else
      end
    end
    if cfg then
      opts["ctermfg"] = cfg
    else
      if (ok_sl and (type(sl) == "table")) then
        opts["ctermfg"] = sl.ctermfg
      else
      end
    end
    if hl.bold then
      opts["bold"] = hl.bold
    else
    end
  else
  end
  opts["bg"] = meta_statusline_bg()
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_normal and (type(normal) == "table") and normal.ctermbg) or 0)
  if not opts.fg then
    opts["fg"] = ((ok_sl and (type(sl) == "table") and hl_rendered_fg(sl)) or 16777215)
  else
  end
  if not opts.ctermfg then
    opts["ctermfg"] = ((ok_sl and (type(sl) == "table") and sl.ctermfg) or 15)
  else
  end
  return opts
end
local function statusline_color_from_with_bg(group, bg_fn)
  local opts = statusline_color_from(group)
  opts["default"] = true
  opts["bg"] = bg_fn()
  return opts
end
local function hit_hl(main_group, curl_group)
  local opts = {default = true, undercurl = true}
  local ok_main,main = pcall(vim.api.nvim_get_hl, 0, {name = main_group, link = false})
  local ok_curl,curl = pcall(vim.api.nvim_get_hl, 0, {name = curl_group, link = false})
  if (ok_main and (type(main) == "table")) then
    if main.fg then
      opts["fg"] = main.fg
    else
    end
    if main.bg then
      opts["bg"] = main.bg
    else
    end
    if main.ctermfg then
      opts["ctermfg"] = main.ctermfg
    else
    end
    if main.ctermbg then
      opts["ctermbg"] = main.ctermbg
    else
    end
  else
  end
  if (ok_curl and (type(curl) == "table")) then
    if curl.sp then
      opts["sp"] = curl.sp
    else
      if curl.fg then
        opts["sp"] = curl.fg
      else
      end
    end
  else
  end
  return opts
end
local function hit_hl_primary(main_group, curl_group)
  local opts = hit_hl(main_group, curl_group)
  opts["default"] = true
  return opts
end
local function thin_underline_from(group)
  local opts = {default = true, underdotted = true, nocombine = true}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    if hl.sp then
      opts["sp"] = hl.sp
    else
      if hl.fg then
        opts["sp"] = hl.fg
      else
        opts["sp"] = 16711680
      end
    end
  else
  end
  return opts
end
local function plain_hl_from(group)
  local opts = {default = true}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    if hl_rendered_fg(hl) then
      opts["fg"] = hl_rendered_fg(hl)
    else
    end
    if hl_rendered_bg(hl) then
      opts["bg"] = hl_rendered_bg(hl)
    else
    end
    if hl.ctermfg then
      opts["ctermfg"] = hl.ctermfg
    else
    end
    if hl.ctermbg then
      opts["ctermbg"] = hl.ctermbg
    else
    end
  else
  end
  return opts
end
local function fg_only_hl_from(group)
  local opts = {default = true}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    if hl_rendered_fg(hl) then
      opts["fg"] = hl_rendered_fg(hl)
    else
    end
    if hl.ctermfg then
      opts["ctermfg"] = hl.ctermfg
    else
    end
  else
  end
  return opts
end
local function statusline_fg_hl_from(group)
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok_hl,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_hl and (type(hl) == "table") and hl_rendered_fg(hl)) or (ok_sl and (type(sl) == "table") and hl_rendered_fg(sl)) or 16777215)
  opts["bg"] = meta_statusline_bg()
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_normal and (type(normal) == "table") and normal.ctermbg) or 0)
  opts["ctermfg"] = ((ok_hl and (type(hl) == "table") and hl.ctermfg) or (ok_sl and (type(sl) == "table") and sl.ctermfg) or 15)
  return opts
end
local function statusline_sep_hl()
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_sl and (type(sl) == "table") and hl_rendered_fg(sl)) or (ok_normal and (type(normal) == "table") and hl_rendered_fg(normal)) or 16777215)
  opts["bg"] = meta_statusline_bg()
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_normal and (type(normal) == "table") and normal.ctermbg) or 0)
  opts["ctermfg"] = ((ok_sl and (type(sl) == "table") and sl.ctermfg) or (ok_normal and (type(normal) == "table") and normal.ctermfg) or 15)
  return opts
end
local function statusline_fg_hl_with_bg(group, bg_fn)
  local opts = {default = true, cterm = {reverse = false}, reverse = false}
  local ok_hl,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_hl and (type(hl) == "table") and hl_rendered_fg(hl)) or (ok_sl and (type(sl) == "table") and hl_rendered_fg(sl)) or 16777215)
  opts["bg"] = bg_fn()
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_normal and (type(normal) == "table") and normal.ctermbg) or 0)
  opts["ctermfg"] = ((ok_hl and (type(hl) == "table") and hl.ctermfg) or (ok_sl and (type(sl) == "table") and sl.ctermfg) or 15)
  return opts
end
local function statusline_sep_hl_with_bg(bg_fn)
  local opts = {default = true, cterm = {reverse = false}, reverse = false}
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_sl and (type(sl) == "table") and hl_rendered_fg(sl)) or (ok_normal and (type(normal) == "table") and hl_rendered_fg(normal)) or 16777215)
  opts["bg"] = bg_fn()
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_normal and (type(normal) == "table") and normal.ctermbg) or 0)
  opts["ctermfg"] = ((ok_sl and (type(sl) == "table") and sl.ctermfg) or (ok_normal and (type(normal) == "table") and normal.ctermfg) or 15)
  return opts
end
local function underlined_text_from(text_group, underline_group)
  local opts = fg_only_hl_from(text_group)
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = underline_group, link = false})
  opts["undercurl"] = true
  if (ok and (type(hl) == "table")) then
    if hl.sp then
      opts["sp"] = hl.sp
    else
      if hl.fg then
        opts["sp"] = hl.fg
      else
      end
    end
  else
  end
  return opts
end
local function darken_rgb(n, factor)
  if not n then
    return nil
  else
    local r = math.floor((n / 65536))
    local g = math.floor(((n / 256) % 256))
    local b = (n % 256)
    local f = math.max(0, math.min(factor, 1))
    local dr = math.max(0, math.min(255, math.floor((r * (1 - f)))))
    local dg = math.max(0, math.min(255, math.floor((g * (1 - f)))))
    local db = math.max(0, math.min(255, math.floor((b * (1 - f)))))
    return ((dr * 65536) + (dg * 256) + db)
  end
end
local function brighten_rgb(n, factor)
  if not n then
    return nil
  else
    local r = math.floor((n / 65536))
    local g = math.floor(((n / 256) % 256))
    local b = (n % 256)
    local f = math.max(0, math.min(factor, 1))
    local br = math.max(0, math.min(255, math.floor((r + ((255 - r) * f)))))
    local bg = math.max(0, math.min(255, math.floor((g + ((255 - g) * f)))))
    local bb = math.max(0, math.min(255, math.floor((b + ((255 - b) * f)))))
    return ((br * 65536) + (bg * 256) + bb)
  end
end
local function hl_bg(group)
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    return hl_rendered_bg(hl)
  else
    return nil
  end
end
local function darker_bg(a, b)
  local la = rgb_luma(a)
  local lb = rgb_luma(b)
  if (la and lb) then
    if (la <= lb) then
      return a
    else
      return b
    end
  else
    return (a or b)
  end
end
local function alt_bg_from(group)
  local opts = {}
  local base_bg = (hl_bg(group) or hl_bg("Normal") or hl_bg("NormalNC") or hl_bg("ColorColumn") or hl_bg("CursorLine") or 1973790)
  local bg = darken_rgb(base_bg, 0.15)
  if bg then
    opts["bg"] = bg
  else
  end
  return opts
end
local function _40_()
  return (brighten_rgb(darker_bg(hl_bg("StatusLine"), (hl_bg("Normal") or hl_bg("NormalNC"))), 0.09) or hl_bg("StatusLine") or hl_bg("StatusLineNC") or hl_bg("Normal") or 2763306)
end
meta_statusline_bg = _40_
local function meta_statusline_middle_hl()
  local opts = plain_hl_from("StatusLine")
  opts["default"] = true
  opts["bg"] = meta_statusline_bg()
  return opts
end
local function meta_statusline_middle_hl_with_bg(bg_fn)
  local opts = plain_hl_from("StatusLine")
  opts["default"] = true
  opts["bg"] = bg_fn()
  return opts
end
local function meta_preview_statusline_hl()
  local opts = plain_hl_from("StatusLine")
  local base_bg = meta_preview_statusline_bg()
  opts["default"] = true
  opts["bg"] = base_bg
  return opts
end
local function _41_()
  return meta_statusline_bg()
end
meta_preview_statusline_bg = _41_
local function results_pulse_bg(step)
  local base = meta_statusline_bg()
  if (step == 2) then
    return (brighten_rgb(base, 0.02) or base)
  elseif (step == 3) then
    return (brighten_rgb(base, 0.04) or base)
  elseif (step == 4) then
    return (brighten_rgb(base, 0.06) or base)
  elseif (step == 5) then
    return (brighten_rgb(base, 0.04) or base)
  elseif (step == 6) then
    return (brighten_rgb(base, 0.02) or base)
  elseif (step == 7) then
    return (darken_rgb(base, 0.02) or base)
  elseif (step == 8) then
    return (darken_rgb(base, 0.04) or base)
  elseif (step == 9) then
    return (brighten_rgb(base, 0.06) or base)
  elseif (step == 10) then
    return (brighten_rgb(base, 0.04) or base)
  elseif (step == 11) then
    return (darken_rgb(base, 0.02) or base)
  else
    return base
  end
end
local function cterm_bg(group)
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    return hl.ctermbg
  else
    return nil
  end
end
local function meta_window_cursorline_hl()
  local opts = plain_hl_from("CursorLine")
  local bg = (opts.bg or hl_bg("CursorLine") or hl_bg("Normal") or 1973790)
  local ok_cl,cl = pcall(vim.api.nvim_get_hl, 0, {name = "CursorLine", link = false})
  local ctermbg = ((ok_cl and (type(cl) == "table") and cl.ctermbg) or cterm_bg("Normal") or 0)
  opts["default"] = true
  opts["bg"] = bg
  opts["ctermbg"] = ctermbg
  opts["underline"] = false
  opts["undercurl"] = false
  opts["underdotted"] = false
  opts["underdashed"] = false
  opts["underdouble"] = false
  opts["bold"] = false
  opts["italic"] = false
  opts["nocombine"] = true
  opts["cterm"] = {}
  return opts
end
local function meta_window_separator_hl()
  local bg = (hl_bg("Normal") or hl_bg("NormalNC") or 1973790)
  local fg = (darken_rgb(bg, 0.18) or bg)
  local opts = {default = true, fg = fg, bg = bg}
  local ctermbg = (cterm_bg("Normal") or cterm_bg("NormalNC") or 0)
  opts["ctermbg"] = ctermbg
  opts["ctermfg"] = ctermbg
  return opts
end
local function prompt_text_hl()
  local opts = {default = true, bold = true, cterm = {bold = true}}
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  local ok_title,title = pcall(vim.api.nvim_get_hl, 0, {name = "Title", link = false})
  local bg = (ok_normal and (type(normal) == "table") and normal.bg)
  local fg0 = ((ok_title and (type(title) == "table") and title.fg) or (ok_normal and (type(normal) == "table") and normal.fg))
  local dark_3f = (bg and ((rgb_luma(bg) or 255) < 120))
  local fg
  if dark_3f then
    fg = brighten_rgb(fg0, 0.18)
  else
    fg = fg0
  end
  if fg then
    opts["fg"] = fg
  else
  end
  return opts
end
local function prompt_text_hl_from(group)
  local opts = prompt_text_hl()
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local fg = (ok and (type(hl) == "table") and hl_rendered_fg(hl))
  if fg then
    opts["fg"] = fg
  else
  end
  if (ok and (type(hl) == "table") and hl.ctermfg) then
    opts["ctermfg"] = hl.ctermfg
  else
  end
  return opts
end
local function loading_hl(group, factor)
  local opts = {default = true, bold = true, cterm = {bold = true}}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local base = (ok and (type(hl) == "table") and hl.fg)
  local fg
  if (base and (factor < 0)) then
    fg = darken_rgb(base, math.abs(factor))
  else
    if base then
      fg = brighten_rgb(base, factor)
    else
      fg = nil
    end
  end
  if fg then
    opts["fg"] = fg
  else
  end
  return opts
end
local function apply_ui_config_21(opts)
  local resolved = config.resolve(opts)
  local ui = resolved.ui
  vim.g["meta#custom_mappings"] = (ui.custom_mappings or {})
  vim.g["meta#highlight_groups"] = (ui.highlight_groups or {All = "Title", Fuzzy = "Number", Regex = "Special"})
  vim.g["meta#syntax_on_init"] = (ui.syntax_on_init or "buffer")
  vim.g["meta#prefix"] = (ui.prefix or "#")
  return nil
end
local function ensure_fennel_syntax_defaults_21()
  if (vim.g.fennel_lua_version == nil) then
    vim.g["fennel_lua_version"] = "5.1"
  else
  end
  if (vim.g.fennel_use_luajit == nil) then
    if _G.jit then
      vim.g["fennel_use_luajit"] = 1
    else
      vim.g["fennel_use_luajit"] = 0
    end
    return nil
  else
    return nil
  end
end
local function ensure_defaults_and_highlights_21(opts)
  ensure_fennel_syntax_defaults_21()
  apply_ui_config_21(opts)
  local hi = vim.api.nvim_set_hl
  hi(0, "MetaStatuslineModeInsert", statusline_color_from("ErrorMsg"))
  hi(0, "MetaStatuslineModeReplace", statusline_color_from("Todo"))
  do
    local normal_mode_hl = meta_statusline_middle_hl()
    normal_mode_hl["bold"] = true
    normal_mode_hl["cterm"] = {bold = true}
    hi(0, "MetaStatuslineModeNormal", normal_mode_hl)
  end
  hi(0, "MetaStatuslineQuery", statusline_color_from("Normal"))
  hi(0, "MetaStatuslineFile", statusline_fg_hl_from("Comment"))
  hi(0, "MetaStatuslineMiddle", meta_statusline_middle_hl())
  hi(0, "MetaPreviewStatusline", meta_preview_statusline_hl())
  hi(0, "MetaStatuslineMatcherAll", statusline_color_from("Statement"))
  hi(0, "MetaStatuslineMatcherFuzzy", statusline_color_from("Number"))
  hi(0, "MetaStatuslineMatcherRegex", statusline_color_from("Special"))
  hi(0, "MetaStatuslineCaseSmart", statusline_color_from("String"))
  hi(0, "MetaStatuslineCaseIgnore", statusline_color_from("Special"))
  hi(0, "MetaStatuslineCaseNormal", statusline_color_from("Normal"))
  hi(0, "MetaStatuslineSyntaxBuffer", statusline_color_from("Comment"))
  hi(0, "MetaStatuslineSyntaxMeta", statusline_color_from("Number"))
  hi(0, "MetaStatuslineIndicator", statusline_color_from("Tag"))
  hi(0, "MetaStatuslineKey", statusline_color_from("Comment"))
  hi(0, "MetaStatuslineFlagOn", statusline_color_from("String"))
  hi(0, "MetaStatuslineFlagOff", statusline_color_from("ErrorMsg"))
  for i = 1, 11 do
    local bg_fn
    local function _54_()
      return results_pulse_bg(i)
    end
    bg_fn = _54_
    local suffix = tostring(i)
    hi(0, ("MetaStatuslineMiddlePulse" .. suffix), meta_statusline_middle_hl_with_bg(bg_fn))
    hi(0, ("MetaStatuslineIndicatorPulse" .. suffix), statusline_color_from_with_bg("Tag", bg_fn))
    hi(0, ("MetaStatuslineKeyPulse" .. suffix), statusline_color_from_with_bg("Comment", bg_fn))
    hi(0, ("MetaStatuslineFlagOnPulse" .. suffix), statusline_color_from_with_bg("String", bg_fn))
    hi(0, ("MetaStatuslineFlagOffPulse" .. suffix), statusline_color_from_with_bg("ErrorMsg", bg_fn))
  end
  hi(0, "MetaSearchHitAll", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitBuffer", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitFuzzy", hit_hl("Number", "WarningMsg"))
  hi(0, "MetaSearchHitFuzzyBetween", hit_hl("IncSearch", "Question"))
  hi(0, "MetaSearchHitRegex", hit_hl("Special", "Type"))
  hi(0, "MetaPromptText", prompt_text_hl())
  for i, src in ipairs(PRIMARY_LINE_GROUPS) do
    local suffix = tostring(i)
    hi(0, ("MetaPromptText" .. suffix), prompt_text_hl_from(src))
    hi(0, ("MetaSearchHitAll" .. suffix), hit_hl_primary(src, "Error"))
    hi(0, ("MetaSearchHitFuzzy" .. suffix), hit_hl_primary(src, "WarningMsg"))
    hi(0, ("MetaSearchHitRegex" .. suffix), hit_hl_primary(src, "Type"))
  end
  hi(0, "MetaPromptNeg", {default = true, link = "ErrorMsg"})
  hi(0, "MetaPromptAnchor", {default = true, link = "SpecialChar"})
  hi(0, "MetaPromptRegex", {default = true, link = "MetaSearchHitRegex", underline = true})
  hi(0, "MetaPromptFlagHashOn", statusline_color_from("String"))
  hi(0, "MetaPromptFlagHashOff", statusline_color_from("ErrorMsg"))
  hi(0, "MetaPromptFlagTextOn", fg_only_hl_from("String"))
  hi(0, "MetaPromptFlagTextOff", fg_only_hl_from("ErrorMsg"))
  hi(0, "MetaPromptFlagTextFuncOn", underlined_text_from("String", "Special"))
  hi(0, "MetaPromptFlagTextFuncOff", underlined_text_from("ErrorMsg", "Special"))
  hi(0, "MetaLoading1", loading_hl("Comment", -0.1))
  hi(0, "MetaLoading2", loading_hl("Comment", 0))
  hi(0, "MetaLoading3", loading_hl("Comment", 0.14))
  hi(0, "MetaLoading4", loading_hl("Title", 0.08))
  hi(0, "MetaLoading5", loading_hl("Title", 0.2))
  hi(0, "MetaLoading6", loading_hl("Title", 0.32))
  hi(0, "MetaSourceLineNr", {default = true, link = "LineNr"})
  hi(0, "MetaSourceDir", {default = true, link = "Directory"})
  hi(0, "MetaSourceBoundary", thin_underline_from("Error"))
  hi(0, "MetaWindowCursorLine", meta_window_cursorline_hl())
  hi(0, "MetaWindowSeparator", meta_window_separator_hl())
  hi(0, "MetaSourceAltBg", alt_bg_from("Normal"))
  for i, src in ipairs(PATH_SEG_GROUPS) do
    hi(0, ("MetaPathSeg" .. tostring(i)), {default = true, link = src})
  end
  hi(0, "MetaPathSep", {default = true, link = "Normal"})
  for i, src in ipairs(PATH_SEG_GROUPS) do
    hi(0, ("MetaStatuslinePathSeg" .. tostring(i)), statusline_fg_hl_from(src))
  end
  hi(0, "MetaStatuslinePathSep", statusline_sep_hl())
  hi(0, "MetaStatuslinePathFile", statusline_fg_hl_from("Comment"))
  for i, src in ipairs(PATH_SEG_GROUPS) do
    hi(0, ("MetaPreviewStatuslinePathSeg" .. tostring(i)), statusline_fg_hl_with_bg(src, meta_preview_statusline_bg))
  end
  hi(0, "MetaPreviewStatuslinePathSep", statusline_sep_hl_with_bg(meta_preview_statusline_bg))
  hi(0, "MetaPreviewStatuslinePathFile", statusline_fg_hl_with_bg("Comment", meta_preview_statusline_bg))
  hi(0, "MetaFileSignDirty", {default = true, link = "WarningMsg"})
  hi(0, "MetaFileSignUntracked", {default = true, link = "DiagnosticError"})
  hi(0, "MetaFileSignClean", {default = true, link = "LineNr"})
  hi(0, "MetaBufSignAdded", {default = true, link = "DiagnosticOk"})
  hi(0, "MetaBufSignModified", {default = true, link = "Statement"})
  hi(0, "MetaBufSignRemoved", {default = true, link = "DiagnosticError"})
  hi(0, "MetaFileAge", {default = true, link = "Comment"})
  hi(0, "MetaFileAgeMinute", {default = true, link = "DiagnosticHint"})
  hi(0, "MetaFileAgeHour", {default = true, link = "DiagnosticHint"})
  hi(0, "MetaFileAgeDay", {default = true, link = "DiagnosticInfo"})
  hi(0, "MetaFileAgeWeek", {default = true, link = "DiagnosticWarn"})
  hi(0, "MetaFileAgeMonth", {default = true, link = "Constant"})
  hi(0, "MetaFileAgeYear", {default = true, link = "DiagnosticError"})
  for i, src in ipairs(AUTHOR_GROUPS) do
    hi(0, ("MetaAuthor" .. tostring(i)), {default = true, link = src})
  end
  if (1 == vim.fn.hlexists("NetrwPlain")) then
    return hi(0, "MetaSourceFile", {default = true, link = "NetrwPlain"})
  else
    return hi(0, "MetaSourceFile", {default = true, link = "Normal"})
  end
end
local function ensure_highlight_refresh_autocmd_21()
  if refresh_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, refresh_augroup)
  else
  end
  refresh_augroup = vim.api.nvim_create_augroup("MetabufferHighlights", {clear = true})
  local function _57_(event)
    if ((event.event == "ColorScheme") or (event.match == "background")) then
      ensure_defaults_and_highlights_21(last_setup_opts)
      return pcall(vim.cmd, "redrawstatus")
    else
      return nil
    end
  end
  return vim.api.nvim_create_autocmd({"ColorScheme", "OptionSet"}, {group = refresh_augroup, pattern = {"*", "background"}, callback = _57_})
end
local function ensure_command(name, callback, opts)
  pcall(vim.api.nvim_del_user_command, name)
  return vim.api.nvim_create_user_command(name, callback, opts)
end
local function plugin_root()
  local src = debug.getinfo(1, "S").source
  local path
  if vim.startswith(src, "@") then
    path = string.sub(src, 2)
  else
    path = src
  end
  return vim.fn.fnamemodify(path, ":p:h:h:h")
end
local function clear_module_cache()
  for k, _ in pairs(package.loaded) do
    if ((k == "metabuffer") or vim.startswith(k, "metabuffer.")) then
      package.loaded[k] = nil
    else
    end
  end
  return nil
end
local function clear_plugin_loaded_flags_21()
  vim.g.loaded_metabuffer = nil
  vim.g.meta_loaded = nil
  return nil
end
local function source_plugin_bootstrap_21()
  local root = plugin_root()
  local file = (root .. "/plugin/metabuffer.lua")
  if (1 == vim.fn.filereadable(file)) then
    return vim.cmd(("silent source " .. vim.fn.fnameescape(file)))
  else
    return error(("plugin bootstrap not found: " .. file))
  end
end
local function maybe_compile_21()
  local root = plugin_root()
  local script = (root .. "/scripts/compile-fennel.sh")
  if (1 == vim.fn.filereadable(script)) then
    local out = vim.fn.system({"sh", script})
    if (vim.v.shell_error == 0) then
      return true
    else
      return error(("compile failed:\n" .. out))
    end
  else
    return error(("compile script not found: " .. script))
  end
end
M.reload = function(opts)
  local cfg = (opts or {})
  local do_compile = (cfg.compile and true)
  if do_compile then
    maybe_compile_21()
  else
  end
  clear_module_cache()
  clear_plugin_loaded_flags_21()
  source_plugin_bootstrap_21()
  local _65_
  if do_compile then
    _65_ = "[metabuffer] reloaded (compiled)"
  else
    _65_ = "[metabuffer] reloaded"
  end
  vim.notify(_65_, vim.log.levels.INFO)
  return true
end
M.setup = function(opts)
  last_setup_opts = opts
  router.configure(opts)
  ensure_defaults_and_highlights_21(opts)
  ensure_highlight_refresh_autocmd_21()
  local function _67_(args)
    return router.entry_start(args.args, args.bang)
  end
  ensure_command("Meta", _67_, {nargs = "?", bang = true})
  local function _68_(args)
    return router.entry_resume(args.args)
  end
  ensure_command("MetaResume", _68_, {nargs = "?"})
  local function _69_()
    return router.entry_cursor_word(false)
  end
  ensure_command("MetaCursorWord", _69_, {nargs = 0})
  local function _70_()
    return router.entry_cursor_word(true)
  end
  ensure_command("MetaResumeCursorWord", _70_, {nargs = 0})
  local function _71_(args)
    return router.entry_sync(args.args)
  end
  ensure_command("MetaSync", _71_, {nargs = "?"})
  local function _72_()
    return router.entry_push()
  end
  ensure_command("MetaPush", _72_, {nargs = 0})
  local function _73_(args)
    local ok,err = pcall(M.reload, {compile = args.bang})
    if not ok then
      return vim.notify(("[metabuffer] reload failed: " .. tostring(err)), vim.log.levels.ERROR)
    else
      return nil
    end
  end
  ensure_command("MetaReload", _73_, {nargs = 0, bang = true})
  return true
end
M.defaults = config.defaults
return M
