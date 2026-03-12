-- [nfnl] fnl/metabuffer/init.fnl
local router = require("metabuffer.router")
local config = require("metabuffer.config")
local M = {}
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
local function statusline_color_from(group)
  local opts = {cterm = {reverse = false}, reverse = false}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  local ok_normal,normal = pcall(vim.api.nvim_get_hl, 0, {name = "Normal", link = false})
  if (ok and (type(hl) == "table")) then
    local fg = (hl.fg or (hl.reverse and hl.bg))
    local cfg = (hl.ctermfg or ((hl.reverse or (hl.cterm and hl.cterm.reverse)) and hl.ctermbg))
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
local function apply_ui_config_21(opts)
  local resolved = config.resolve(opts)
  local ui = resolved.ui
  vim.g["meta#custom_mappings"] = (ui.custom_mappings or {})
  vim.g["meta#highlight_groups"] = (ui.highlight_groups or {All = "Title", Fuzzy = "Number", Regex = "Special"})
  vim.g["meta#syntax_on_init"] = (ui.syntax_on_init or "buffer")
  vim.g["meta#prefix"] = (ui.prefix or "#")
  return nil
end
local function ensure_defaults_and_highlights_21(opts)
  apply_ui_config_21(opts)
  local hi = vim.api.nvim_set_hl
  hi(0, "MetaStatuslineModeInsert", statusline_color_from("Tag"))
  hi(0, "MetaStatuslineModeReplace", statusline_color_from("Todo"))
  hi(0, "MetaStatuslineModeNormal", statusline_color_from("Comment"))
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
  hi(0, "MetaSearchHitAll", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitBuffer", hit_hl("Statement", "Error"))
  hi(0, "MetaSearchHitFuzzy", hit_hl("Number", "WarningMsg"))
  hi(0, "MetaSearchHitFuzzyBetween", hit_hl("IncSearch", "Question"))
  hi(0, "MetaSearchHitRegex", hit_hl("Special", "Type"))
  hi(0, "MetaPromptText", prompt_text_hl())
  hi(0, "MetaPromptNeg", {default = true, link = "ErrorMsg"})
  hi(0, "MetaPromptAnchor", {default = true, link = "SpecialChar"})
  hi(0, "MetaPromptRegex", {default = true, link = "MetaSearchHitRegex", underline = true})
  hi(0, "MetaSourceLineNr", {default = true, link = "LineNr"})
  hi(0, "MetaSourceDir", {default = true, link = "Directory"})
  hi(0, "MetaSourceBoundary", thin_underline_from("Error"))
  hi(0, "MetaSourceAltBg", alt_bg_from("Normal"))
  hi(0, "MetaPathSeg1", {default = true, link = "Directory"})
  hi(0, "MetaPathSeg2", {default = true, link = "Identifier"})
  hi(0, "MetaPathSeg3", {default = true, link = "Type"})
  hi(0, "MetaPathSeg4", {default = true, link = "Special"})
  hi(0, "MetaPathSeg5", {default = true, link = "String"})
  hi(0, "MetaPathSeg6", {default = true, link = "Constant"})
  hi(0, "MetaPathSeg7", {default = true, link = "Function"})
  hi(0, "MetaPathSeg8", {default = true, link = "Statement"})
  hi(0, "MetaPathSeg9", {default = true, link = "PreProc"})
  hi(0, "MetaPathSeg10", {default = true, link = "Keyword"})
  hi(0, "MetaPathSeg11", {default = true, link = "Operator"})
  hi(0, "MetaPathSeg12", {default = true, link = "Character"})
  hi(0, "MetaPathSeg13", {default = true, link = "Tag"})
  hi(0, "MetaPathSeg14", {default = true, link = "Delimiter"})
  hi(0, "MetaPathSeg15", {default = true, link = "Number"})
  hi(0, "MetaPathSeg16", {default = true, link = "Boolean"})
  hi(0, "MetaPathSeg17", {default = true, link = "Macro"})
  hi(0, "MetaPathSeg18", {default = true, link = "Title"})
  hi(0, "MetaPathSeg19", {default = true, link = "Question"})
  hi(0, "MetaPathSeg20", {default = true, link = "Exception"})
  hi(0, "MetaPathSeg21", {default = true, link = "DiffAdd"})
  hi(0, "MetaPathSeg22", {default = true, link = "DiffChange"})
  hi(0, "MetaPathSeg23", {default = true, link = "DiffText"})
  hi(0, "MetaPathSeg24", {default = true, link = "DiagnosticInfo"})
  hi(0, "MetaPathSep", {default = true, link = "Normal"})
  hi(0, "MetaFileSignDirty", {default = true, link = "WarningMsg"})
  hi(0, "MetaFileSignUntracked", {default = true, link = "DiagnosticError"})
  hi(0, "MetaFileSignClean", {default = true, link = "LineNr"})
  hi(0, "MetaBufSignAdded", {default = true, link = "DiffAdd"})
  hi(0, "MetaBufSignModified", {default = true, link = "DiffChange"})
  hi(0, "MetaBufSignRemoved", {default = true, link = "DiffDelete"})
  hi(0, "MetaFileAge", {default = true, link = "Comment"})
  hi(0, "MetaFileAgeMinute", {default = true, link = "DiagnosticOk"})
  hi(0, "MetaFileAgeHour", {default = true, link = "DiagnosticHint"})
  hi(0, "MetaFileAgeDay", {default = true, link = "DiagnosticInfo"})
  hi(0, "MetaFileAgeWeek", {default = true, link = "DiagnosticWarn"})
  hi(0, "MetaFileAgeMonth", {default = true, link = "Constant"})
  hi(0, "MetaFileAgeYear", {default = true, link = "DiagnosticError"})
  hi(0, "MetaAuthor1", {default = true, link = "Identifier"})
  hi(0, "MetaAuthor2", {default = true, link = "Type"})
  hi(0, "MetaAuthor3", {default = true, link = "Special"})
  hi(0, "MetaAuthor4", {default = true, link = "String"})
  hi(0, "MetaAuthor5", {default = true, link = "Constant"})
  hi(0, "MetaAuthor6", {default = true, link = "Function"})
  hi(0, "MetaAuthor7", {default = true, link = "Statement"})
  hi(0, "MetaAuthor8", {default = true, link = "PreProc"})
  hi(0, "MetaAuthor9", {default = true, link = "Keyword"})
  hi(0, "MetaAuthor10", {default = true, link = "Operator"})
  hi(0, "MetaAuthor11", {default = true, link = "Character"})
  hi(0, "MetaAuthor12", {default = true, link = "Tag"})
  hi(0, "MetaAuthor13", {default = true, link = "Delimiter"})
  hi(0, "MetaAuthor14", {default = true, link = "Number"})
  hi(0, "MetaAuthor15", {default = true, link = "Boolean"})
  hi(0, "MetaAuthor16", {default = true, link = "Macro"})
  hi(0, "MetaAuthor17", {default = true, link = "Title"})
  hi(0, "MetaAuthor18", {default = true, link = "Question"})
  hi(0, "MetaAuthor19", {default = true, link = "Exception"})
  hi(0, "MetaAuthor20", {default = true, link = "DiffAdd"})
  hi(0, "MetaAuthor21", {default = true, link = "DiffChange"})
  hi(0, "MetaAuthor22", {default = true, link = "DiffText"})
  hi(0, "MetaAuthor23", {default = true, link = "DiagnosticInfo"})
  hi(0, "MetaAuthor24", {default = true, link = "DiagnosticHint"})
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
  local _42_
  if do_compile then
    _42_ = "[metabuffer] reloaded (compiled)"
  else
    _42_ = "[metabuffer] reloaded"
  end
  vim.notify(_42_, vim.log.levels.INFO)
  return true
end
M.setup = function(opts)
  router.configure(opts)
  ensure_defaults_and_highlights_21(opts)
  local function _44_(args)
    return router.entry_start(args.args, args.bang)
  end
  ensure_command("Meta", _44_, {nargs = "?", bang = true})
  local function _45_(args)
    return router.entry_resume(args.args)
  end
  ensure_command("MetaResume", _45_, {nargs = "?"})
  local function _46_()
    return router.entry_cursor_word(false)
  end
  ensure_command("MetaCursorWord", _46_, {nargs = 0})
  local function _47_()
    return router.entry_cursor_word(true)
  end
  ensure_command("MetaResumeCursorWord", _47_, {nargs = 0})
  local function _48_(args)
    return router.entry_sync(args.args)
  end
  ensure_command("MetaSync", _48_, {nargs = "?"})
  local function _49_()
    return router.entry_push()
  end
  ensure_command("MetaPush", _49_, {nargs = 0})
  local function _50_(args)
    local ok,err = pcall(M.reload, {compile = args.bang})
    if not ok then
      return vim.notify(("[metabuffer] reload failed: " .. tostring(err)), vim.log.levels.ERROR)
    else
      return nil
    end
  end
  ensure_command("MetaReload", _50_, {nargs = 0, bang = true})
  return true
end
M.defaults = config.defaults
return M
