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
M.new = function(opts)
  local _let_1_ = (opts or {})
  local info_content_ns = _let_1_["info-content-ns"]
  local info_height = _let_1_["info-height"]
  local refresh_info_statusline_21 = _let_1_["refresh-info-statusline!"]
  local read_file_lines_cached = _let_1_["read-file-lines-cached"]
  local read_file_view_cached = _let_1_["read-file-view-cached"]
  local ext_start_in_file = _let_1_["ext-start-in-file"]
  local icon_field = _let_1_["icon-field"]
  local function apply_highlights_21(session, ns, highlights)
    for _, h in ipairs((highlights or {})) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[2], h[1], h[3], h[4])
    end
    return nil
  end
  local function build_info_row(_2_)
    local session = _2_.session
    local ref = _2_.ref
    local src_idx = _2_["src-idx"]
    local target_width = _2_["target-width"]
    local lnum_digit_width = _2_["lnum-digit-width"]
    local lightweight_3f = _2_["lightweight?"]
    local line_hl = "LineNr"
    local signcol_display_width = 2
    local file_hl
    if (1 == vim.fn.hlexists("NERDTreeFile")) then
      file_hl = "NERDTreeFile"
    else
      if (1 == vim.fn.hlexists("NetrwPlain")) then
        file_hl = "NetrwPlain"
      else
        if (1 == vim.fn.hlexists("NvimTreeFileName")) then
          file_hl = "NvimTreeFileName"
        else
          file_hl = "Normal"
        end
      end
    end
    local lnum = tostring(((ref and ref.lnum) or src_idx))
    local lnum_cell0 = lineno_mod["lnum-cell"](lnum, lnum_digit_width)
    local base_path = vim.fn.fnamemodify(((ref and ref.path) or "[Current Buffer]"), ":~:.")
    local path_width = math.max(1, (target_width - (lnum_digit_width + 1) - signcol_display_width))
    local info_view
    if lightweight_3f then
      info_view = {path = base_path, suffix = "", ["suffix-highlights"] = {}, sign = {text = "  ", hl = "LineNr"}, ["highlight-dir"] = false, ["highlight-file"] = false, ["show-icon"] = false}
    else
      info_view = source_mod["info-view"](session, ref, {mode = (session["info-file-entry-view"] or "meta"), ["path-width"] = path_width, ["single-source?"] = (not session["project-mode"] and not session["active-source-key"]), ["read-file-lines-cached"] = read_file_lines_cached, ["read-file-view-cached"] = read_file_view_cached})
    end
    local sign = (info_view.sign or {text = "  ", hl = "LineNr"})
    local sign_raw = (sign.text or "")
    local sign_pad = math.max(0, (signcol_display_width - vim.fn.strdisplaywidth(sign_raw)))
    local sign_prefix = (sign_raw .. string.rep(" ", sign_pad))
    local sign_hl = (sign.hl or "LineNr")
    local sign_highlights = (sign.highlights or {})
    local sign_width = #sign_prefix
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
    local path = (info_view.path or base_path)
    local icon_path = (info_view["icon-path"] or path)
    local show_icon_3f
    if (info_view["show-icon"] == nil) then
      show_icon_3f = true
    else
      show_icon_3f = info_view["show-icon"]
    end
    local highlight_dir_3f
    if (info_view["highlight-dir"] == nil) then
      highlight_dir_3f = true
    else
      highlight_dir_3f = info_view["highlight-dir"]
    end
    local highlight_file_3f
    if (info_view["highlight-file"] == nil) then
      highlight_file_3f = true
    else
      highlight_file_3f = info_view["highlight-file"]
    end
    local suffix0 = (info_view.suffix or "")
    local suffix_prefix
    if (#suffix0 > 0) then
      suffix_prefix = (info_view["suffix-prefix"] or "  ")
    else
      suffix_prefix = ""
    end
    local suffix_hls = (info_view["suffix-highlights"] or {})
    local icon_info
    if show_icon_3f then
      icon_info = util["file-icon-info"](icon_path, file_hl)
    else
      icon_info = {icon = "", ["icon-hl"] = file_hl, ["file-hl"] = file_hl, ["ext-hl"] = file_hl}
    end
    local icon = (icon_info.icon or "")
    local iconf = icon_field(icon)
    local icon_prefix
    if show_icon_3f then
      icon_prefix = iconf.text
    else
      icon_prefix = ""
    end
    local ext0 = util["ext-from-path"](icon_path)
    local ext_bucket_hl
    if (ext0 == "") then
      ext_bucket_hl = nil
    else
      ext_bucket_hl = path_hl["group-for-segment"](ext0)
    end
    local ext_hl = (ext_bucket_hl or icon_info["ext-hl"] or icon_info["icon-hl"] or file_hl)
    local icon_hl = (ext_bucket_hl or icon_info["icon-hl"] or file_hl)
    local _16_
    if show_icon_3f then
      _16_ = iconf.width
    else
      _16_ = 0
    end
    local _let_18_ = fit_path_into_width(path, math.max(1, (path_width - _16_)))
    local dir = _let_18_[1]
    local file0 = _let_18_[2]
    local dir_original = _let_18_[3]
    local this_file_hl = (icon_info["file-hl"] or file_hl)
    local line = (sign_prefix .. lnum_cell0 .. icon_prefix .. dir .. file0 .. suffix_prefix .. suffix0)
    local sign_start = 0
    local sign_end = (sign_start + sign_width)
    local num_start = sign_end
    local num_end = (num_start + #lnum_cell0)
    local icon_start = num_end
    local icon_end = (icon_start + #icon_prefix)
    local dir_start = icon_end
    local file_start = (dir_start + #dir)
    local suffix_start = (file_start + #file0 + #suffix_prefix)
    local highlights = {}
    if (sign_width > 0) then
      table.insert(highlights, {"SignColumn", sign_start, sign_end})
    else
    end
    if (#sign_highlights > 0) then
      for _, part in ipairs(sign_highlights) do
        local s = (sign_start + (part.start or 0))
        local e = (sign_start + (part["end"] or 0))
        if (e > s) then
          table.insert(highlights, {(part.hl or sign_hl), s, e})
        else
        end
      end
    else
      if ((sign_glyph_end > sign_glyph_start) and (sign_width > 0)) then
        table.insert(highlights, {sign_hl, (sign_start + sign_glyph_start), (sign_start + sign_glyph_end)})
      else
      end
    end
    table.insert(highlights, {line_hl, num_start, num_end})
    if (#icon_prefix > 0) then
      table.insert(highlights, {icon_hl, icon_start, icon_end})
    else
    end
    if (highlight_dir_3f and (#dir > 0)) then
      for _, dr in ipairs(path_hl["ranges-for-dir"](dir, dir_start, dir_original)) do
        table.insert(highlights, {dr.hl, dr.start, dr["end"]})
      end
    else
    end
    if (highlight_file_3f and (#file0 > 0)) then
      table.insert(highlights, {this_file_hl, file_start, (file_start + #file0)})
    else
    end
    if (highlight_file_3f and (#file0 > 0)) then
      local dot = ext_start_in_file(file0)
      if (dot > 0) then
        table.insert(highlights, {ext_hl, (file_start + (dot - 1)), (file_start + #file0)})
      else
      end
    else
    end
    if (#suffix0 > 0) then
      table.insert(highlights, {"Comment", suffix_start, (suffix_start + #suffix0)})
    else
    end
    for _, sh in ipairs(suffix_hls) do
      local s = (suffix_start + (sh.start or 0))
      local e = (suffix_start + (sh["end"] or 0))
      if (e > s) then
        table.insert(highlights, {(sh.hl or "Comment"), s, e})
      else
      end
    end
    return {line = line, highlights = highlights}
  end
  local function build_info_lines(_30_)
    local session = _30_.session
    local refs = _30_.refs
    local idxs = _30_.idxs
    local target_width = _30_["target-width"]
    local start_index = _30_["start-index"]
    local stop_index = _30_["stop-index"]
    local visible_start = _30_["visible-start"]
    local visible_stop = _30_["visible-stop"]
    local lnum_digit_width
    do
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
      lnum_digit_width = lineno_mod["digit-width-from-max-len"](max_lnum_len)
    end
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
        local built = build_info_row({session = session, ref = ref, ["src-idx"] = src_idx, ["target-width"] = target_width, ["lnum-digit-width"] = lnum_digit_width, ["lightweight?"] = false})
        table.insert(lines, built.line)
        for _, h in ipairs((built.highlights or {})) do
          table.insert(highlights, {row0, h[1], h[2], h[3]})
        end
      end
    end
    return {lines = lines, highlights = highlights, ["deferred-rows"] = deferred_rows, ["lnum-digit-width"] = lnum_digit_width}
  end
  local function schedule_highlight_fill_21(_33_)
    local session = _33_.session
    local refs = _33_.refs
    local target_width = _33_["target-width"]
    local lnum_digit_width = _33_["lnum-digit-width"]
    local deferred_rows = _33_["deferred-rows"]
    local pending = (deferred_rows or {})
    local batch_size = math.max(4, math.min(24, math.max(1, info_height(session))))
    if (#pending == 0) then
      session["info-highlight-fill-pending?"] = false
      return refresh_info_statusline_21(session)
    else
      local token = (1 + (session["info-highlight-fill-token"] or 0))
      session["info-highlight-fill-token"] = token
      session["info-highlight-fill-pending?"] = true
      refresh_info_statusline_21(session)
      local next_index = 1
      local function run_batch()
        if (session and session["info-highlight-fill-pending?"] and (token == session["info-highlight-fill-token"]) and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
          do
            local bo = vim.bo[session["info-buf"]]
            bo["modifiable"] = true
          end
          do
            local stop = math.min(#pending, (next_index + batch_size + -1))
            for i = next_index, stop do
              local spec = pending[i]
              local row0 = spec[1]
              local src_idx = spec[2]
              local ref = refs[src_idx]
              local built = build_info_row({session = session, ref = ref, ["src-idx"] = src_idx, ["target-width"] = target_width, ["lnum-digit-width"] = lnum_digit_width, ["lightweight?"] = false})
              local line = str(built.line)
              local highlights = (built.highlights or {})
              vim.api.nvim_buf_set_lines(session["info-buf"], row0, (row0 + 1), false, {line})
              vim.api.nvim_buf_clear_namespace(session["info-buf"], info_content_ns, row0, (row0 + 1))
              for _, h in ipairs(highlights) do
                vim.api.nvim_buf_add_highlight(session["info-buf"], info_content_ns, h[1], row0, h[2], h[3])
              end
            end
            if (stop < #pending) then
              next_index = (stop + 1)
              vim.defer_fn(run_batch, 17)
            else
              session["info-highlight-fill-pending?"] = false
              refresh_info_statusline_21(session)
            end
          end
          local bo = vim.bo[session["info-buf"]]
          bo["modifiable"] = false
          return nil
        else
          return nil
        end
      end
      return vim.defer_fn(run_batch, 17)
    end
  end
  return {["apply-highlights!"] = apply_highlights_21, ["build-info-lines"] = build_info_lines, ["schedule-highlight-fill!"] = schedule_highlight_fill_21}
end
return M
