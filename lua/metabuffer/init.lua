-- [nfnl] fnl/metabuffer/init.fnl
local router = require("metabuffer.router")
local config = require("metabuffer.config")
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
local function effective_fg(hl)
  return (hl.fg or (hl.reverse and hl.bg))
end
local function effective_ctermfg(hl)
  return (hl.ctermfg or ((hl.reverse or (hl.cterm and hl.cterm.reverse)) and hl.ctermbg))
end
local function statusline_color_from(group)
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  if (ok and (type(hl) == "table")) then
    local fg = effective_fg(hl)
    local cfg = effective_ctermfg(hl)
    if fg then
      opts["bg"] = fg
    else
      if (ok_normal and (type(normal) == "table") and normal.bg) then
        opts["bg"] = normal.bg
      else
      end
    end
    if cfg then
      opts["ctermbg"] = cfg
    else
      if (ok_normal and (type(normal) == "table") and normal.ctermbg) then
        opts["ctermbg"] = normal.ctermbg
      else
      end
    end
    if hl.bold then
      opts["bold"] = hl.bold
    else
    end
  else
  end
  do
    local bl = rgb_luma(opts.bg)
    if (bl and (bl > 128)) then
      opts["fg"] = 0
    else
      opts["fg"] = 16777215
    end
  end
  if (opts.ctermbg and (opts.ctermbg > 7)) then
    opts["ctermfg"] = 0
  else
    opts["ctermfg"] = 15
  end
  return opts
end
local function undercurl_from(group)
  local opts = {default = true, undercurl = true}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    if hl.sp then
      opts["sp"] = hl.sp
    else
    end
    if (not opts.sp and hl.fg) then
      opts["sp"] = hl.fg
    else
    end
  else
  end
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
    if hl.fg then
      opts["fg"] = hl.fg
    else
    end
    if hl.bg then
      opts["bg"] = hl.bg
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
    if hl.fg then
      opts["fg"] = hl.fg
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
local function statusline_path_hl_from(group)
  local opts = {default = true}
  local ok_hl,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  opts["fg"] = ((ok_hl and (type(hl) == "table") and effective_fg(hl)) or (ok_sl and (type(sl) == "table") and effective_fg(sl)) or 16777215)
  opts["bg"] = ((ok_sl and (type(sl) == "table") and sl.bg) or (ok_hl and (type(hl) == "table") and hl.bg) or 0)
  opts["ctermfg"] = ((ok_hl and (type(hl) == "table") and effective_ctermfg(hl)) or (ok_sl and (type(sl) == "table") and effective_ctermfg(sl)) or 15)
  opts["ctermbg"] = ((ok_sl and (type(sl) == "table") and sl.ctermbg) or (ok_hl and (type(hl) == "table") and hl.ctermbg) or 0)
  return opts
end
local function statusline_fg_hl_from(group)
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok_hl,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_hl and (type(hl) == "table") and effective_fg(hl)) or (ok_sl and (type(sl) == "table") and effective_fg(sl)) or 16777215)
  if (ok_normal and (type(normal) == "table")) then
    if normal.bg then
      opts["bg"] = normal.bg
    else
    end
    if normal.ctermbg then
      opts["ctermbg"] = normal.ctermbg
    else
    end
  else
  end
  opts["ctermfg"] = ((ok_hl and (type(hl) == "table") and effective_ctermfg(hl)) or (ok_sl and (type(sl) == "table") and effective_ctermfg(sl)) or 15)
  return opts
end
local function statusline_sep_hl()
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok_sl,sl = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  opts["fg"] = ((ok_sl and (type(sl) == "table") and effective_fg(sl)) or (ok_normal and (type(normal) == "table") and effective_fg(normal)) or 16777215)
  if (ok_normal and (type(normal) == "table")) then
    if normal.bg then
      opts["bg"] = normal.bg
    else
    end
    if normal.ctermbg then
      opts["ctermbg"] = normal.ctermbg
    else
    end
  else
  end
  opts["ctermfg"] = ((ok_sl and (type(sl) == "table") and effective_ctermfg(sl)) or (ok_normal and (type(normal) == "table") and effective_ctermfg(normal)) or 15)
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
    return hl.bg
  else
    return nil
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
    local normal_mode_hl = plain_hl_from("StatusLine")
    normal_mode_hl["bold"] = true
    normal_mode_hl["cterm"] = {bold = true}
    hi(0, "MetaStatuslineModeNormal", normal_mode_hl)
  end
  hi(0, "MetaStatuslineQuery", statusline_color_from("Normal"))
  hi(0, "MetaStatuslineFile", statusline_color_from("Comment"))
  hi(0, "MetaStatuslineMiddle", plain_hl_from("StatusLine"))
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
  hi(0, "MetaSearchHitAll", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitBuffer", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitFuzzy", hit_hl("Number", "WarningMsg"))
  hi(0, "MetaSearchHitFuzzyBetween", hit_hl("IncSearch", "Question"))
  hi(0, "MetaSearchHitRegex", hit_hl("Special", "Type"))
  hi(0, "MetaPromptText", prompt_text_hl())
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
  hi(0, "MetaFileSignDirty", {default = true, link = "WarningMsg"})
  hi(0, "MetaFileSignUntracked", {default = true, link = "DiagnosticError"})
  hi(0, "MetaFileSignClean", {default = true, link = "LineNr"})
  hi(0, "MetaBufSignAdded", {default = true, link = "DiagnosticOk"})
  hi(0, "MetaBufSignModified", {default = true, link = "Statement"})
  hi(0, "MetaBufSignRemoved", {default = true, link = "DiagnosticError"})
  hi(0, "MetaFileAge", {default = true, link = "Comment"})
  hi(0, "MetaFileAgeMinute", {default = true, link = "DiagnosticOk"})
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
  local _60_
  if do_compile then
    _60_ = "[metabuffer] reloaded (compiled)"
  else
    _60_ = "[metabuffer] reloaded"
  end
  vim.notify(_60_, vim.log.levels.INFO)
  return true
end
M.setup = function(opts)
  router.configure(opts)
  ensure_defaults_and_highlights_21(opts)
  local function _62_(args)
    return router.entry_start(args.args, args.bang)
  end
  ensure_command("Meta", _62_, {nargs = "?", bang = true})
  local function _63_(args)
    return router.entry_resume(args.args)
  end
  ensure_command("MetaResume", _63_, {nargs = "?"})
  local function _64_()
    return router.entry_cursor_word(false)
  end
  ensure_command("MetaCursorWord", _64_, {nargs = 0})
  local function _65_()
    return router.entry_cursor_word(true)
  end
  ensure_command("MetaResumeCursorWord", _65_, {nargs = 0})
  local function _66_(args)
    return router.entry_sync(args.args)
  end
  ensure_command("MetaSync", _66_, {nargs = "?"})
  local function _67_()
    return router.entry_push()
  end
  ensure_command("MetaPush", _67_, {nargs = 0})
  local function _68_(args)
    local ok,err = pcall(M.reload, {compile = args.bang})
    if not ok then
      return vim.notify(("[metabuffer] reload failed: " .. tostring(err)), vim.log.levels.ERROR)
    else
      return nil
    end
  end
  ensure_command("MetaReload", _68_, {nargs = 0, bang = true})
  return true
end
M.defaults = config.defaults
return M
