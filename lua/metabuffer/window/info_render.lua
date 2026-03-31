-- [nfnl] fnl/metabuffer/window/info_render.fnl
local M = {}
local helper_mod = require("metabuffer.window.info_helpers")
local info_row_mod = require("metabuffer.window.info_row")
local info_regular_mod = require("metabuffer.window.info_regular")
local info_viewport_mod = require("metabuffer.window.info_viewport")
local info_content_ns = vim.api.nvim_create_namespace("MetaInfoWindow")
local info_selection_ns = vim.api.nvim_create_namespace("MetaInfoSelection")
local str = helper_mod.str
local join_str = helper_mod["join-str"]
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
  local regular_info = info_regular_mod.new({["info-height"] = info_height, ["info-max-lines"] = info_max_lines, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["render-info-lines!"] = render_info_lines_21, ["set-info-topline!"] = set_info_topline_21, ["sync-info-selection!"] = sync_info_selection_21, ["info-visible-range"] = info_visible_range, ["info-max-width-now"] = info_max_width_now})
  return {["fit-info-width!"] = fit_info_width_21, ["info-visible-range"] = info_visible_range, ["render-info-lines!"] = render_info_lines_21, ["set-info-topline!"] = set_info_topline_21, ["sync-info-selection!"] = sync_info_selection_21, ["update-regular!"] = regular_info["update-regular!"]}
end
return M
