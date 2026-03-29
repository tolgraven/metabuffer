-- [nfnl] fnl/metabuffer/window/info.fnl
local M = {}
local info_buffer_mod = require("metabuffer.buffer.info")
local helper_mod = require("metabuffer.window.info_helpers")
local base_window_mod = require("metabuffer.window.base")
local events = require("metabuffer.events")
local info_float_mod = require("metabuffer.window.info_float")
local info_project_mod = require("metabuffer.project.info_view")
local info_render_mod = require("metabuffer.window.info_render")
local apply_metabuffer_window_highlights_21 = base_window_mod["apply-metabuffer-window-highlights!"]
local loading_skeleton_lines = helper_mod["loading-skeleton-lines"]
local valid_info_win_3f = helper_mod["valid-info-win?"]
local session_host_win = helper_mod["session-host-win"]
local ext_start_in_file = helper_mod["ext-start-in-file"]
local icon_field = helper_mod["icon-field"]
local refs_slice_sig = helper_mod["refs-slice-sig"]
local info_winbar_active_3f = helper_mod["info-winbar-active?"]
local effective_info_height = helper_mod["effective-info-height"]
M.new = function(opts)
  local deps = (opts or {})
  local floating_window_mod = deps["floating-window-mod"]
  local info_min_width = deps["info-min-width"]
  local info_max_width = deps["info-max-width"]
  local info_max_lines = deps["info-max-lines"]
  local info_height = deps["info-height"]
  local debug_log = deps["debug-log"]
  local read_file_lines_cached = deps["read-file-lines-cached"]
  local read_file_view_cached = deps["read-file-view-cached"]
  local animation_mod = deps["animation-mod"]
  local animate_enter_3f = deps["animate-enter?"]
  local info_fade_ms = deps["info-fade-ms"]
  local update_21 = nil
  local project_loading_pending_3f = nil
  local update_project_21 = nil
  local update_regular_21 = nil
  local ensure_info_window = nil
  local settle_info_window_21 = nil
  local resize_info_window_21 = nil
  local refresh_info_statusline_21 = nil
  local close_info_window_21 = nil
  local fit_info_width_21 = nil
  local render_info_lines_21 = nil
  local sync_info_selection_21 = nil
  local info_visible_range = nil
  local function startup_layout_pending_3f(session)
    local initializing = (session["startup-initializing"] or false)
    local animating = (session["prompt-animating?"] or false)
    return (session and session["project-mode"] and (initializing or animating))
  end
  do
    local info_float
    local function _1_(session)
      return project_loading_pending_3f(session)
    end
    info_float = info_float_mod.new({["floating-window-mod"] = floating_window_mod, ["info-min-width"] = info_min_width, ["info-height"] = info_height, ["animation-mod"] = animation_mod, ["animate-enter?"] = animate_enter_3f, ["info-fade-ms"] = info_fade_ms, ["valid-info-win?"] = valid_info_win_3f, ["session-host-win"] = session_host_win, ["effective-info-height"] = effective_info_height, ["info-winbar-active?"] = info_winbar_active_3f, ["project-loading-pending?"] = _1_, events = events, ["apply-metabuffer-window-highlights!"] = apply_metabuffer_window_highlights_21, ["info-buffer-mod"] = info_buffer_mod})
    local function _2_(session)
      return info_float["ensure-window!"](session, update_21)
    end
    ensure_info_window = _2_
    settle_info_window_21 = info_float["settle-window!"]
    resize_info_window_21 = info_float["resize-window!"]
    refresh_info_statusline_21 = info_float["refresh-statusline!"]
    close_info_window_21 = info_float["close-window!"]
  end
  do
    local info_render
    local function _3_(session)
      return project_loading_pending_3f(session)
    end
    info_render = info_render_mod.new({["info-min-width"] = info_min_width, ["info-max-width"] = info_max_width, ["info-max-lines"] = info_max_lines, ["info-height"] = info_height, ["debug-log"] = debug_log, ["read-file-lines-cached"] = read_file_lines_cached, ["read-file-view-cached"] = read_file_view_cached, ["resize-info-window!"] = resize_info_window_21, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["valid-info-win?"] = valid_info_win_3f, ["session-host-win"] = session_host_win, ["ext-start-in-file"] = ext_start_in_file, ["icon-field"] = icon_field, ["project-loading-pending?"] = _3_})
    update_regular_21 = info_render["update-regular!"]
    fit_info_width_21 = info_render["fit-info-width!"]
    render_info_lines_21 = info_render["render-info-lines!"]
    sync_info_selection_21 = info_render["sync-info-selection!"]
    info_visible_range = info_render["info-visible-range"]
  end
  do
    local project_info = info_project_mod.new({["startup-layout-pending?"] = startup_layout_pending_3f, ["loading-skeleton-lines"] = loading_skeleton_lines, ["info-height"] = info_height, ["ensure-info-window"] = ensure_info_window, ["settle-info-window!"] = settle_info_window_21, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["render-info-lines!"] = render_info_lines_21, ["sync-info-selection!"] = sync_info_selection_21, ["refs-slice-sig"] = refs_slice_sig, ["info-visible-range"] = info_visible_range, ["fit-info-width!"] = fit_info_width_21, ["info-max-lines"] = info_max_lines, ["debug-log"] = debug_log, ["valid-info-win?"] = valid_info_win_3f})
    project_loading_pending_3f = project_info["project-loading-pending?"]
    local function _4_(session, refresh_lines)
      return project_info["update-project!"](session, refresh_lines)
    end
    update_project_21 = _4_
  end
  local function _5_(session, refresh_lines)
    ensure_info_window(session)
    settle_info_window_21(session)
    local refresh_lines0
    if (refresh_lines == nil) then
      refresh_lines0 = true
    else
      refresh_lines0 = refresh_lines
    end
    if session["project-mode"] then
      return update_project_21(session, refresh_lines0)
    else
      return update_regular_21(session, refresh_lines0)
    end
  end
  update_21 = _5_
  return {["close-window!"] = close_info_window_21, ["update!"] = update_21, ["refresh-statusline!"] = refresh_info_statusline_21}
end
return M
