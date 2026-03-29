-- [nfnl] fnl/metabuffer/window/info_render.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local lineno_mod = require("metabuffer.window.lineno")
local source_mod = require("metabuffer.source")
local path_hl = require("metabuffer.path_highlight")
local util = require("metabuffer.util")
local file_info = require("metabuffer.source.file_info")
local helper_mod = require("metabuffer.window.info_helpers")
local info_content_ns = vim.api.nvim_create_namespace("MetaInfoWindow")
local info_selection_ns = vim.api.nvim_create_namespace("MetaInfoSelection")
local str = helper_mod.str
local join_str = helper_mod["join-str"]
local info_placeholder_line = helper_mod["info-placeholder-line"]
local indices_slice_sig = helper_mod["indices-slice-sig"]
local ref_path = helper_mod["ref-path"]
local refs_slice_sig = helper_mod["refs-slice-sig"]
local fit_path_into_width = helper_mod["fit-path-into-width"]
local info_range = helper_mod["info-range"]
local numeric_max = helper_mod["numeric-max"]
local info_winbar_active_3f = helper_mod["info-winbar-active?"]
M.new = function(opts)
  local info_min_width = opts["info-min-width"]
  local info_max_width = opts["info-max-width"]
  local info_max_lines = opts["info-max-lines"]
  local info_height = opts["info-height"]
  local debug_log = opts["debug-log"]
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local read_file_view_cached = opts["read-file-view-cached"]
  local resize_info_window_21 = opts["resize-info-window!"]
  local refresh_info_statusline_21 = opts["refresh-info-statusline!"]
  local valid_info_win_3f = opts["valid-info-win?"]
  local session_host_win = opts["session-host-win"]
  local ext_start_in_file = opts["ext-start-in-file"]
  local icon_field = opts["icon-field"]
  local project_loading_pending_3f = opts["project-loading-pending?"]
  local function apply_info_highlights_21(session, ns, highlights)
    for _, h in ipairs((highlights or {})) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, h[2], h[1], h[3], h[4])
    end
    return nil
  end
  local function sync_info_selection_21(session, meta)
    if (valid_info_win_3f(session) and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local info_lines = vim.api.nvim_buf_line_count(session["info-buf"])
      local selected1 = (meta.selected_index + 1)
      local row0
      if ((info_lines > 0) and (selected1 > 0)) then
        row0 = math.max(0, math.min((selected1 - 1), (info_lines - 1)))
      else
        row0 = nil
      end
      vim.api.nvim_buf_clear_namespace(session["info-buf"], info_selection_ns, 0, -1)
      if (row0 and (row0 >= 0) and (row0 < info_lines)) then
        return vim.api.nvim_buf_add_highlight(session["info-buf"], info_selection_ns, "Visual", row0, 0, -1)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function build_info_row(session, ref, src_idx, target_width, lnum_digit_width, lightweight_3f)
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
    local _17_
    if show_icon_3f then
      _17_ = iconf.width
    else
      _17_ = 0
    end
    local _let_19_ = fit_path_into_width(path, math.max(1, (path_width - _17_)))
    local dir = _let_19_[1]
    local file0 = _let_19_[2]
    local dir_original = _let_19_[3]
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
  local function schedule_info_highlight_fill_21(session, refs, target_width, lnum_digit_width, deferred_rows)
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
              local built = build_info_row(session, ref, src_idx, target_width, lnum_digit_width, false)
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
  local function set_info_topline_21(session, top)
    if valid_info_win_3f(session) then
      local function _34_()
        local line_count = math.max(1, vim.api.nvim_buf_line_count(session["info-buf"]))
        local top_2a = math.max(1, math.min(top, line_count))
        local selected1 = math.max(top_2a, math.min((session.meta.selected_index + 1), line_count))
        local view = vim.fn.winsaveview()
        view["topline"] = top_2a
        view["lnum"] = selected1
        view["col"] = 0
        view["leftcol"] = 0
        return pcall(vim.fn.winrestview, view)
      end
      return vim.api.nvim_win_call(session["info-win"], _34_)
    else
      return nil
    end
  end
  local function ensure_regular_info_buffer_shape_21(session, render_stop)
    if (session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local needed = math.max(1, (render_stop or 0))
      local current = vim.api.nvim_buf_line_count(session["info-buf"])
      if (current ~= needed) then
        do
          local bo = vim.bo[session["info-buf"]]
          bo["modifiable"] = true
        end
        if (current < needed) then
          local function _36_(_)
            return info_placeholder_line(session)
          end
          vim.api.nvim_buf_set_lines(session["info-buf"], current, current, false, vim.tbl_map(_36_, vim.fn.range((current + 1), needed)))
        else
          vim.api.nvim_buf_set_lines(session["info-buf"], needed, -1, false, {})
        end
        local bo = vim.bo[session["info-buf"]]
        bo["modifiable"] = false
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function fit_info_width_21(session, lines)
    if valid_info_win_3f(session) then
      local widths
      local function _40_(line)
        return vim.fn.strdisplaywidth((line or ""))
      end
      widths = vim.tbl_map(_40_, (lines or {}))
      local max_len = numeric_max(widths, 0)
      local host_win = session_host_win(session)
      local host_width
      if (session["window-local-layout"] and host_win and vim.api.nvim_win_is_valid(host_win)) then
        host_width = vim.api.nvim_win_get_width(host_win)
      else
        host_width = vim.o.columns
      end
      local max_available = math.max(info_min_width, math.floor((host_width * 0.34)))
      local upper = math.min(info_max_width, max_available)
      local fit_target = math.max(info_min_width, math.min(max_len, upper))
      local frozen_width = (not session["project-mode"] and session["info-fixed-width"])
      local target = (frozen_width or fit_target)
      local height = info_height(session)
      if (not session["project-mode"] and not frozen_width) then
        session["info-fixed-width"] = math.max(info_min_width, fit_target)
      else
      end
      return resize_info_window_21(session, target, height)
    else
      return nil
    end
  end
  local function info_max_width_now(session)
    local host_win = session_host_win(session)
    local host_width
    if (session and session["window-local-layout"] and host_win and vim.api.nvim_win_is_valid(host_win)) then
      host_width = vim.api.nvim_win_get_width(host_win)
    else
      host_width = vim.o.columns
    end
    local max_available = math.max(info_min_width, math.floor((host_width * 0.34)))
    return math.min(info_max_width, max_available)
  end
  local function info_visible_range(session, meta, total, cap)
    if ((total <= 0) or (cap <= 0)) then
      return {1, 0}
    else
      if (session and meta and meta.win and vim.api.nvim_win_is_valid(meta.win.window)) then
        local view
        local function _45_()
          return vim.fn.winsaveview()
        end
        view = vim.api.nvim_win_call(meta.win.window, _45_)
        local top0 = math.max(1, math.min(total, (view.topline or 1)))
        local overlay_offset
        if info_winbar_active_3f(session, project_loading_pending_3f) then
          overlay_offset = 1
        else
          overlay_offset = 0
        end
        local top = math.max(1, math.min(total, (top0 + overlay_offset)))
        local height0 = math.max(1, vim.api.nvim_win_get_height(meta.win.window))
        local height = math.max(1, (height0 - overlay_offset))
        local stop0 = math.min(total, (top + height + -1))
        local shown = math.max(1, ((stop0 - top) + 1))
        if (shown <= cap) then
          return {top, stop0}
        else
          return {top, (top + cap + -1)}
        end
      else
        return info_range(meta.selected_index, total, cap)
      end
    end
  end
  local function build_info_lines(session, refs, idxs, target_width, start_index, stop_index, visible_start, visible_stop)
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
        local built = build_info_row(session, ref, src_idx, target_width, lnum_digit_width, false)
        table.insert(lines, built.line)
        for _, h in ipairs((built.highlights or {})) do
          table.insert(highlights, {row0, h[1], h[2], h[3]})
        end
      end
    end
    return {lines = lines, highlights = highlights, ["deferred-rows"] = deferred_rows, ["lnum-digit-width"] = lnum_digit_width}
  end
  local function render_info_lines_21(session, meta, render_start, render_stop, visible_start, visible_stop)
    local refs = (meta.buf["source-refs"] or {})
    local idxs = (meta.buf.indices or {})
    local _
    session["info-start-index"] = visible_start
    _ = nil
    local _0
    session["info-stop-index"] = visible_stop
    _0 = nil
    local _1
    session["info-render-start"] = render_start
    _1 = nil
    local _2
    session["info-render-stop"] = render_stop
    _2 = nil
    local built = build_info_lines(session, refs, idxs, info_max_width_now(session), render_start, render_stop, visible_start, visible_stop)
    local raw_lines = built.lines
    local lines
    if (type(raw_lines) == "table") then
      lines = vim.tbl_map(str, raw_lines)
    else
      lines = {str(raw_lines)}
    end
    local highlights = (built.highlights or {})
    local deferred_rows = (built["deferred-rows"] or {})
    local lnum_digit_width = (built["lnum-digit-width"] or 1)
    debug_log(join_str(" ", {"info render", ("hits=" .. #idxs), ("lines=" .. #lines)}))
    session["info-highlight-fill-token"] = (1 + (session["info-highlight-fill-token"] or 0))
    session["info-highlight-fill-pending?"] = false
    fit_info_width_21(session, lines)
    ensure_regular_info_buffer_shape_21(session, render_stop)
    do
      local bo = vim.bo[session["info-buf"]]
      bo["modifiable"] = true
    end
    do
      local ok_set,err_set = pcall(vim.api.nvim_buf_set_lines, session["info-buf"], (render_start - 1), render_stop, false, lines)
      if not ok_set then
        debug_log(("info set_lines failed: " .. tostring(err_set)))
      else
      end
    end
    vim.api.nvim_buf_clear_namespace(session["info-buf"], info_content_ns, (render_start - 1), render_stop)
    apply_info_highlights_21(session, info_content_ns, highlights)
    schedule_info_highlight_fill_21(session, refs, info_max_width_now(session), lnum_digit_width, deferred_rows)
    do
      local bo = vim.bo[session["info-buf"]]
      bo["modifiable"] = false
    end
    set_info_topline_21(session, visible_start)
    return refresh_info_statusline_21(session)
  end
  local function render_current_range_21(session, meta)
    local total = #(meta.buf.indices or {})
    local _let_54_ = info_visible_range(session, meta, total, info_max_lines)
    local start_index = _let_54_[1]
    local stop_index = _let_54_[2]
    local overscan = math.max(1, info_height(session))
    local render_start = math.max(1, (start_index - overscan))
    local render_stop = math.min(total, (stop_index + overscan))
    render_info_lines_21(session, meta, render_start, render_stop, start_index, stop_index)
    sync_info_selection_21(session, meta)
    return {start_index, stop_index}
  end
  local function schedule_regular_line_meta_refresh_21(session, meta, start_index, stop_index)
    local refs = (meta.buf["source-refs"] or {})
    local idxs = (meta.buf.indices or {})
    local first_row = ((#idxs > 0) and idxs[start_index])
    local first_ref = (first_row and refs[first_row])
    local path = ref_path(session, first_ref)
    local rerender_21 = nil
    local function _55_()
      if (session and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"]) and not session["project-mode"] and session["single-file-info-ready"]) then
        if (session["scroll-animating?"] or session["scroll-command-view"] or session["scroll-sync-pending"] or session["selection-refresh-pending"]) then
          if not session["info-line-meta-refresh-pending"] then
            session["info-line-meta-refresh-pending"] = true
            local function _56_()
              session["info-line-meta-refresh-pending"] = false
              return rerender_21()
            end
            return vim.defer_fn(_56_, 90)
          else
            return nil
          end
        else
          local _let_58_ = render_current_range_21(session, meta)
          local start1 = _let_58_[1]
          local stop1 = _let_58_[2]
          session["info-start-index"] = start1
          session["info-stop-index"] = stop1
          return nil
        end
      else
        return nil
      end
    end
    rerender_21 = _55_
    if (session["single-file-info-fetch-ready"] and (path ~= "") and (1 == vim.fn.filereadable(path))) then
      local lnums = {}
      for i = start_index, stop_index do
        local src_idx = idxs[i]
        local ref = refs[src_idx]
        if (ref and (ref_path(session, ref) == path) and (type(ref.lnum) == "number")) then
          table.insert(lnums, ref.lnum)
        else
        end
      end
      table.sort(lnums)
      if (#lnums > 0) then
        local first_lnum = lnums[1]
        local last_lnum = lnums[#lnums]
        local range_key = (path .. ":" .. start_index .. ":" .. stop_index .. ":" .. first_lnum .. ":" .. last_lnum)
        if (range_key ~= session["info-line-meta-range-key"]) then
          session["info-line-meta-range-key"] = range_key
          local function _62_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          file_info["ensure-file-status-async!"](session, path, _62_)
          local function _64_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          return file_info["ensure-line-meta-range-async!"](session, path, lnums, _64_)
        else
          return nil
        end
      else
        return nil
      end
    else
      return nil
    end
  end
  local function update_regular_21(session, refresh_lines)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local meta = session.meta
      local _ = refresh_info_statusline_21(session)
      local force_refresh_3f = ((session["info-render-sig"] == nil) or (session["info-start-index"] == nil) or (session["info-stop-index"] == nil))
      local selected1 = (meta.selected_index + 1)
      local idxs = (meta.buf.indices or {})
      local overscan = math.max(1, info_height(session))
      local _let_70_ = info_visible_range(session, meta, #idxs, info_max_lines)
      local wanted_start = _let_70_[1]
      local wanted_stop = _let_70_[2]
      local render_start
      if (#idxs > 0) then
        render_start = math.max(1, (wanted_start - overscan))
      else
        render_start = 1
      end
      local render_stop
      if (#idxs > 0) then
        render_stop = math.min(#idxs, (wanted_stop + overscan))
      else
        render_stop = 0
      end
      local start_index = (session["info-start-index"] or 1)
      local stop_index = (session["info-stop-index"] or 0)
      local rendered_start = (session["info-render-start"] or 1)
      local rendered_stop = (session["info-render-stop"] or 0)
      local out_of_range = ((selected1 < start_index) or (selected1 > stop_index))
      local range_changed = ((wanted_start ~= start_index) or (wanted_stop ~= stop_index))
      local rendered_range_changed = ((wanted_start < rendered_start) or (wanted_stop > rendered_stop) or (render_start ~= rendered_start) or (render_stop ~= rendered_stop))
      local sig = join_str("|", {#idxs, indices_slice_sig(idxs, render_start, render_stop), refs_slice_sig(session, meta.buf["source-refs"], idxs, render_start, render_stop), render_start, render_stop, (session["active-source-key"] or ""), (session["info-file-entry-view"] or ""), info_max_width_now(session), info_height(session), vim.o.columns, str(clj.boolean(session["single-file-info-ready"])), str(clj.boolean(session["single-file-info-fetch-ready"]))})
      if (force_refresh_3f or refresh_lines or out_of_range or range_changed or rendered_range_changed or (session["info-render-sig"] ~= sig)) then
        if refresh_lines then
          session["info-line-meta-range-key"] = nil
        else
        end
        session["info-render-sig"] = sig
        render_info_lines_21(session, meta, render_start, render_stop, wanted_start, wanted_stop)
        session["info-start-index"] = wanted_start
        session["info-stop-index"] = wanted_stop
        sync_info_selection_21(session, meta)
        return schedule_regular_line_meta_refresh_21(session, meta, wanted_start, wanted_stop)
      else
        set_info_topline_21(session, wanted_start)
        return sync_info_selection_21(session, meta)
      end
    else
      return nil
    end
  end
  return {["fit-info-width!"] = fit_info_width_21, ["info-visible-range"] = info_visible_range, ["render-info-lines!"] = render_info_lines_21, ["sync-info-selection!"] = sync_info_selection_21, ["update-regular!"] = update_regular_21}
end
return M
