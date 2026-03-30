-- [nfnl] fnl/metabuffer/window/info_render.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local file_info = require("metabuffer.source.file_info")
local helper_mod = require("metabuffer.window.info_helpers")
local info_row_mod = require("metabuffer.window.info_row")
local info_viewport_mod = require("metabuffer.window.info_viewport")
local info_content_ns = vim.api.nvim_create_namespace("MetaInfoWindow")
local info_selection_ns = vim.api.nvim_create_namespace("MetaInfoSelection")
local str = helper_mod.str
local join_str = helper_mod["join-str"]
local indices_slice_sig = helper_mod["indices-slice-sig"]
local ref_path = helper_mod["ref-path"]
local refs_slice_sig = helper_mod["refs-slice-sig"]
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
  local row_builder = info_row_mod.new({["info-content-ns"] = info_content_ns, ["info-height"] = info_height, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["read-file-lines-cached"] = read_file_lines_cached, ["read-file-view-cached"] = read_file_view_cached, ["ext-start-in-file"] = ext_start_in_file, ["icon-field"] = icon_field})
  local apply_info_highlights_21 = row_builder["apply-highlights!"]
  local build_info_lines = row_builder["build-info-lines"]
  local schedule_info_highlight_fill_21 = row_builder["schedule-highlight-fill!"]
  local viewport = info_viewport_mod.new({["info-min-width"] = info_min_width, ["info-max-width"] = info_max_width, ["info-max-lines"] = info_max_lines, ["info-height"] = info_height, ["resize-info-window!"] = resize_info_window_21, ["valid-info-win?"] = valid_info_win_3f, ["session-host-win"] = session_host_win, ["project-loading-pending?"] = project_loading_pending_3f})
  local set_info_topline_21 = viewport["set-info-topline!"]
  local ensure_regular_info_buffer_shape_21 = viewport["ensure-buffer-shape!"]
  local fit_info_width_21 = viewport["fit-info-width!"]
  local info_max_width_now = viewport["info-max-width-now"]
  local info_visible_range = viewport["info-visible-range"]
  local function render_info_lines_21(_4_)
    local session = _4_.session
    local meta = _4_.meta
    local render_start = _4_["render-start"]
    local render_stop = _4_["render-stop"]
    local visible_start = _4_["visible-start"]
    local visible_stop = _4_["visible-stop"]
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
    local built = build_info_lines({session = session, refs = refs, idxs = idxs, ["target-width"] = info_max_width_now(session), ["start-index"] = render_start, ["stop-index"] = render_stop, ["visible-start"] = visible_start, ["visible-stop"] = visible_stop})
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
    schedule_info_highlight_fill_21({session = session, refs = refs, ["target-width"] = info_max_width_now(session), ["lnum-digit-width"] = lnum_digit_width, ["deferred-rows"] = deferred_rows})
    do
      local bo = vim.bo[session["info-buf"]]
      bo["modifiable"] = false
    end
    set_info_topline_21(session, visible_start)
    return refresh_info_statusline_21(session)
  end
  local function render_current_range_21(session, meta)
    local total = #(meta.buf.indices or {})
    local _let_7_ = info_visible_range(session, meta, total, info_max_lines)
    local start_index = _let_7_[1]
    local stop_index = _let_7_[2]
    local overscan = math.max(1, info_height(session))
    local render_start = math.max(1, (start_index - overscan))
    local render_stop = math.min(total, (stop_index + overscan))
    render_info_lines_21({session = session, meta = meta, ["render-start"] = render_start, ["render-stop"] = render_stop, ["visible-start"] = start_index, ["visible-stop"] = stop_index})
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
    local function _8_()
      if (session and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"]) and not session["project-mode"] and session["single-file-info-ready"]) then
        if (session["scroll-animating?"] or session["scroll-command-view"] or session["scroll-sync-pending"] or session["selection-refresh-pending"]) then
          if not session["info-line-meta-refresh-pending"] then
            session["info-line-meta-refresh-pending"] = true
            local function _9_()
              session["info-line-meta-refresh-pending"] = false
              return rerender_21()
            end
            return vim.defer_fn(_9_, 90)
          else
            return nil
          end
        else
          local _let_11_ = render_current_range_21(session, meta)
          local start1 = _let_11_[1]
          local stop1 = _let_11_[2]
          session["info-start-index"] = start1
          session["info-stop-index"] = stop1
          return nil
        end
      else
        return nil
      end
    end
    rerender_21 = _8_
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
          local function _15_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          file_info["ensure-file-status-async!"](session, path, _15_)
          local function _17_()
            if (range_key == session["info-line-meta-range-key"]) then
              return rerender_21()
            else
              return nil
            end
          end
          return file_info["ensure-line-meta-range-async!"](session, path, lnums, _17_)
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
      local _let_23_ = info_visible_range(session, meta, #idxs, info_max_lines)
      local wanted_start = _let_23_[1]
      local wanted_stop = _let_23_[2]
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
        render_info_lines_21({session = session, meta = meta, ["render-start"] = render_start, ["render-stop"] = render_stop, ["visible-start"] = wanted_start, ["visible-stop"] = wanted_stop})
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
