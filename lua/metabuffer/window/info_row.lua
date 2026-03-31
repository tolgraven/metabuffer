-- [nfnl] fnl/metabuffer/window/info_row.fnl
local M = {}
local lineno_mod = require("metabuffer.window.lineno")
local source_mod = require("metabuffer.source")
local path_hl = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
local helper_mod = require("metabuffer.window.info_helpers")
local str = helper_mod.str
local fit_path_into_width = helper_mod["fit-path-into-width"]
local numeric_max = helper_mod["numeric-max"]
local signcol_display_width = 2
local function apply_highlights_21(session, ns, highlights)
  for _, h in ipairs((highlights or {})) do
    vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[2], h[1], h[3], h[4])
  end
  return nil
end
local function default_file_hl()
  if (1 == vim.fn.hlexists("NERDTreeFile")) then
    return "NERDTreeFile"
  else
    if (1 == vim.fn.hlexists("NetrwPlain")) then
      return "NetrwPlain"
    else
      if (1 == vim.fn.hlexists("NvimTreeFileName")) then
        return "NvimTreeFileName"
      else
        return "Normal"
      end
    end
  end
end
local function lightweight_info_view(base_path)
  return {path = base_path, suffix = "", ["suffix-highlights"] = {}, sign = {text = "  ", hl = "LineNr"}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
end
local function info_view_for_row(deps, session, ref, base_path, path_width, lightweight_3f)
  if lightweight_3f then
    return lightweight_info_view(base_path)
  else
    return source_mod["info-view"](session, ref, {mode = (session["info-file-entry-view"] or "meta"), ["path-width"] = path_width, ["single-source?"] = (not session["project-mode"] and not session["active-source-key"]), ["read-file-lines-cached"] = deps["read-file-lines-cached"], ["read-file-view-cached"] = deps["read-file-view-cached"]})
  end
end
local function sign_parts(sign)
  local sign_raw = (sign.text or "")
  local sign_pad = math.max(0, (signcol_display_width - vim.fn.strdisplaywidth(sign_raw)))
  local sign_prefix = (sign_raw .. string.rep(" ", sign_pad))
  local sign_glyph_start1 = (string.find(sign_prefix, "%S") or 0)
  local sign_glyph = vim.trim(sign_prefix)
  local sign_glyph_start
  if (sign_glyph_start1 > 0) then
    sign_glyph_start = (sign_glyph_start1 - 1)
  else
    sign_glyph_start = -1
  end
  local sign_glyph_end
  if ((sign_glyph_start1 > 0) and (#sign_glyph > 0)) then
    sign_glyph_end = (sign_glyph_start + #sign_glyph)
  else
    sign_glyph_end = -1
  end
  return {prefix = sign_prefix, width = #sign_prefix, hl = (sign.hl or "LineNr"), highlights = (sign.highlights or {}), ["glyph-start"] = sign_glyph_start, ["glyph-end"] = sign_glyph_end}
end
local function normalized_info_view(base_path, info_view)
  local path = (info_view.path or base_path)
  local suffix = (info_view.suffix or "")
  local _7_
  if (info_view["show-icon"] == nil) then
    _7_ = true
  else
    _7_ = info_view["show-icon"]
  end
  local _9_
  if (info_view["highlight-dir"] == nil) then
    _9_ = true
  else
    _9_ = info_view["highlight-dir"]
  end
  local _11_
  if (info_view["highlight-file"] == nil) then
    _11_ = true
  else
    _11_ = info_view["highlight-file"]
  end
  local _13_
  if (#suffix > 0) then
    _13_ = (info_view["suffix-prefix"] or "  ")
  else
    _13_ = ""
  end
  return {path = path, ["icon-path"] = (info_view["icon-path"] or path), ["show-icon?"] = _7_, ["highlight-dir?"] = _9_, ["highlight-file?"] = _11_, suffix = suffix, ["suffix-prefix"] = _13_, ["suffix-highlights"] = (info_view["suffix-highlights"] or {}), sign = (info_view.sign or {text = "  ", hl = "LineNr"})}
end
local function icon_parts(icon_field, show_icon_3f, icon_path, file_hl)
  local icon_info
  if show_icon_3f then
    icon_info = util["file-icon-info"](icon_path, file_hl)
  else
    icon_info = {icon = "", ["icon-hl"] = file_hl, ["file-hl"] = file_hl, ["ext-hl"] = file_hl}
  end
  local icon = (icon_info.icon or "")
  local iconf = icon_field(icon)
  local ext0 = util["ext-from-path"](icon_path)
  local ext_bucket_hl
  if (ext0 == "") then
    ext_bucket_hl = nil
  else
    ext_bucket_hl = path_hl["group-for-segment"](ext0)
  end
  local _17_
  if show_icon_3f then
    _17_ = iconf.text
  else
    _17_ = ""
  end
  local _19_
  if show_icon_3f then
    _19_ = iconf.width
  else
    _19_ = 0
  end
  return {["icon-prefix"] = _17_, ["icon-width"] = _19_, ["icon-hl"] = (ext_bucket_hl or icon_info["icon-hl"] or file_hl), ["ext-hl"] = (ext_bucket_hl or icon_info["ext-hl"] or icon_info["icon-hl"] or file_hl), ["file-hl"] = (icon_info["file-hl"] or file_hl)}
end
local function row_layout(path, path_width, icon_width, sign_prefix, lnum_cell, icon_prefix, suffix, suffix_prefix)
  local _let_21_ = fit_path_into_width(path, math.max(1, (path_width - icon_width)))
  local dir = _let_21_[1]
  local file0 = _let_21_[2]
  local dir_original = _let_21_[3]
  local sign_width = #sign_prefix
  local line = (sign_prefix .. lnum_cell .. icon_prefix .. dir .. file0 .. suffix_prefix .. suffix)
  local sign_start = 0
  local sign_end = (sign_start + sign_width)
  local num_start = sign_end
  local num_end = (num_start + #lnum_cell)
  local icon_start = num_end
  local icon_end = (icon_start + #icon_prefix)
  local dir_start = icon_end
  local file_start = (dir_start + #dir)
  local suffix_start = (file_start + #file0 + #suffix_prefix)
  return {dir = dir, file = file0, ["dir-original"] = dir_original, line = line, ["sign-start"] = sign_start, ["sign-end"] = sign_end, ["num-start"] = num_start, ["num-end"] = num_end, ["icon-start"] = icon_start, ["icon-end"] = icon_end, ["dir-start"] = dir_start, ["file-start"] = file_start, ["suffix-start"] = suffix_start}
end
local function append_sign_highlights_21(highlights, sign, layout)
  if (sign.width > 0) then
    table.insert(highlights, {"SignColumn", layout["sign-start"], layout["sign-end"]})
  else
  end
  if (#sign.highlights > 0) then
    for _, part in ipairs(sign.highlights) do
      local s = (layout["sign-start"] + (part.start or 0))
      local e = (layout["sign-start"] + (part["end"] or 0))
      if (e > s) then
        table.insert(highlights, {(part.hl or sign.hl), s, e})
      else
      end
    end
    return nil
  else
    if ((sign["glyph-end"] > sign["glyph-start"]) and (sign.width > 0)) then
      return table.insert(highlights, {sign.hl, (layout["sign-start"] + sign["glyph-start"]), (layout["sign-start"] + sign["glyph-end"])})
    else
      return nil
    end
  end
end
local function append_path_highlights_21(deps, highlights, row, icon, file_hl, ext_hl)
  table.insert(highlights, {"LineNr", row["num-start"], row["num-end"]})
  if (#icon["icon-prefix"] > 0) then
    table.insert(highlights, {icon["icon-hl"], row["icon-start"], row["icon-end"]})
  else
  end
  if (row["highlight-dir?"] and (#row.dir > 0)) then
    for _, dr in ipairs(path_hl["ranges-for-dir"](row.dir, row["dir-start"], row["dir-original"])) do
      table.insert(highlights, {dr.hl, dr.start, dr["end"]})
    end
  else
  end
  if (row["highlight-file?"] and (#row.file > 0)) then
    table.insert(highlights, {file_hl, row["file-start"], (row["file-start"] + #row.file)})
  else
  end
  if (row["highlight-file?"] and (#row.file > 0)) then
    local dot = deps["ext-start-in-file"](row.file)
    if (dot > 0) then
      return table.insert(highlights, {ext_hl, (row["file-start"] + (dot - 1)), (row["file-start"] + #row.file)})
    else
      return nil
    end
  else
    return nil
  end
end
local function append_suffix_highlights_21(highlights, row)
  if (#row.suffix > 0) then
    table.insert(highlights, {"Comment", row["suffix-start"], (row["suffix-start"] + #row.suffix)})
  else
  end
  for _, sh in ipairs(row["suffix-highlights"]) do
    local s = (row["suffix-start"] + (sh.start or 0))
    local e = (row["suffix-start"] + (sh["end"] or 0))
    if (e > s) then
      table.insert(highlights, {(sh.hl or "Comment"), s, e})
    else
    end
  end
  return nil
end
local function row_highlight_context(layout, info_view)
  return {dir = layout.dir, file = layout.file, ["dir-original"] = layout["dir-original"], line = layout.line, ["sign-start"] = layout["sign-start"], ["sign-end"] = layout["sign-end"], ["num-start"] = layout["num-start"], ["num-end"] = layout["num-end"], ["icon-start"] = layout["icon-start"], ["icon-end"] = layout["icon-end"], ["dir-start"] = layout["dir-start"], ["file-start"] = layout["file-start"], ["suffix-start"] = layout["suffix-start"], ["highlight-dir?"] = info_view["highlight-dir?"], ["highlight-file?"] = info_view["highlight-file?"], suffix = info_view.suffix, ["suffix-highlights"] = info_view["suffix-highlights"]}
end
local function build_info_row(deps, _33_)
  local session = _33_.session
  local ref = _33_.ref
  local src_idx = _33_["src-idx"]
  local target_width = _33_["target-width"]
  local lnum_digit_width = _33_["lnum-digit-width"]
  local lightweight_3f = _33_["lightweight?"]
  local file_hl = default_file_hl()
  local lnum = tostring(((ref and ref.lnum) or src_idx))
  local lnum_cell = lineno_mod["lnum-cell"](lnum, lnum_digit_width)
  local base_path = vim.fn.fnamemodify(((ref and ref.path) or "[Current Buffer]"), ":~:.")
  local path_width = math.max(1, (target_width - (lnum_digit_width + 1) - signcol_display_width))
  local info_view = normalized_info_view(base_path, info_view_for_row(deps, session, ref, base_path, path_width, lightweight_3f))
  local sign = sign_parts(info_view.sign)
  local icon = icon_parts(deps["icon-field"], info_view["show-icon?"], info_view["icon-path"], file_hl)
  local layout = row_layout(info_view.path, path_width, icon["icon-width"], sign.prefix, lnum_cell, icon["icon-prefix"], info_view.suffix, info_view["suffix-prefix"])
  local row = row_highlight_context(layout, info_view)
  local highlights = {}
  append_sign_highlights_21(highlights, sign, layout)
  append_path_highlights_21(deps, highlights, row, icon, icon["file-hl"], icon["ext-hl"])
  append_suffix_highlights_21(highlights, row)
  return {line = row.line, highlights = highlights}
end
local function visible_lnum_digit_width(refs, idxs, start_index, stop_index, visible_start, visible_stop)
  local vis_lo = math.max(1, (visible_start or start_index))
  local vis_hi = math.min(#idxs, (visible_stop or stop_index))
  local max_lnum_len
  if (vis_hi > 0) then
    local lens = {}
    for i = vis_lo, vis_hi do
      local src_idx = idxs[i]
      local ref = refs[src_idx]
      local lnum = tostring(((ref and ref.lnum) or src_idx))
      table.insert(lens, #lnum)
    end
    max_lnum_len = numeric_max(lens, 1)
  else
    max_lnum_len = 1
  end
  return lineno_mod["digit-width-from-max-len"](max_lnum_len)
end
local function build_info_lines(deps, _35_)
  local session = _35_.session
  local refs = _35_.refs
  local idxs = _35_.idxs
  local target_width = _35_["target-width"]
  local start_index = _35_["start-index"]
  local stop_index = _35_["stop-index"]
  local visible_start = _35_["visible-start"]
  local visible_stop = _35_["visible-stop"]
  local lnum_digit_width = visible_lnum_digit_width(refs, idxs, start_index, stop_index, visible_start, visible_stop)
  local lines = {}
  local highlights = {}
  local deferred_rows = {}
  if (#idxs == 0) then
    table.insert(lines, "No matches")
  else
    for i = start_index, stop_index do
      local src_idx = idxs[i]
      local ref = refs[src_idx]
      local row0 = (i - 1)
      local built = build_info_row(deps, {session = session, ref = ref, ["src-idx"] = src_idx, ["target-width"] = target_width, ["lnum-digit-width"] = lnum_digit_width, ["lightweight?"] = false})
      table.insert(lines, built.line)
      for _, h in ipairs((built.highlights or {})) do
        table.insert(highlights, {row0, h[1], h[2], h[3]})
      end
    end
  end
  return {lines = lines, highlights = highlights, ["deferred-rows"] = deferred_rows, ["lnum-digit-width"] = lnum_digit_width}
end
local function apply_highlight_fill_row_21(deps, session, refs, target_width, lnum_digit_width, spec)
  local row0 = spec[1]
  local src_idx = spec[2]
  local ref = refs[src_idx]
  local built = build_info_row(deps, {session = session, ref = ref, ["src-idx"] = src_idx, ["target-width"] = target_width, ["lnum-digit-width"] = lnum_digit_width, ["lightweight?"] = false})
  local highlights = {}
  vim.api.nvim_buf_set_lines(session["info-buf"], row0, (row0 + 1), false, {str(built.line)})
  vim.api.nvim_buf_clear_namespace(session["info-buf"], deps["info-content-ns"], row0, (row0 + 1))
  for _, h in ipairs((built.highlights or {})) do
    table.insert(highlights, {row0, h[1], h[2], h[3]})
  end
  return apply_highlights_21(session, deps["info-content-ns"], highlights)
end
local function fill_highlight_batch_21(deps, session, refs, target_width, lnum_digit_width, pending, next_index, stop)
  do
    local bo = vim.bo[session["info-buf"]]
    bo["modifiable"] = true
  end
  for i = next_index, stop do
    apply_highlight_fill_row_21(deps, session, refs, target_width, lnum_digit_width, pending[i])
  end
  local bo = vim.bo[session["info-buf"]]
  bo["modifiable"] = false
  return nil
end
local function start_highlight_fill_21(deps, session, refs, target_width, lnum_digit_width, pending, batch_size)
  local refresh_info_statusline_21 = deps["refresh-info-statusline!"]
  local token = (1 + (session["info-highlight-fill-token"] or 0))
  session["info-highlight-fill-token"] = token
  session["info-highlight-fill-pending?"] = true
  refresh_info_statusline_21(session)
  local next_index = 1
  local function run_batch()
    if (session and session["info-highlight-fill-pending?"] and (token == session["info-highlight-fill-token"]) and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local stop = math.min(#pending, (next_index + batch_size + -1))
      fill_highlight_batch_21(deps, session, refs, target_width, lnum_digit_width, pending, next_index, stop)
      if (stop < #pending) then
        next_index = (stop + 1)
        return vim.defer_fn(run_batch, 17)
      else
        session["info-highlight-fill-pending?"] = false
        return refresh_info_statusline_21(session)
      end
    else
      return nil
    end
  end
  return vim.defer_fn(run_batch, 17)
end
local function schedule_highlight_fill_21(deps, _39_)
  local session = _39_.session
  local refs = _39_.refs
  local target_width = _39_["target-width"]
  local lnum_digit_width = _39_["lnum-digit-width"]
  local deferred_rows = _39_["deferred-rows"]
  local pending = (deferred_rows or {})
  local batch_size = math.max(4, math.min(24, math.max(1, deps["info-height"](session))))
  if (#pending == 0) then
    session["info-highlight-fill-pending?"] = false
    return deps["refresh-info-statusline!"](session)
  else
    return start_highlight_fill_21(deps, session, refs, target_width, lnum_digit_width, pending, batch_size)
  end
end
M.new = function(opts)
  local deps = (opts or {})
  local function _41_(spec)
    return build_info_lines(deps, spec)
  end
  local function _42_(spec)
    return schedule_highlight_fill_21(deps, spec)
  end
  return {["apply-highlights!"] = apply_highlights_21, ["build-info-lines"] = _41_, ["schedule-highlight-fill!"] = _42_}
end
return M
