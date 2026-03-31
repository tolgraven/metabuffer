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
local function startup_layout_pending_3f(session)
  local initializing = (session["startup-initializing"] or false)
  local animating = (session["prompt-animating?"] or false)
  return (session and session["project-mode"] and (initializing or animating))
end
local function build_info_float(deps, project_loading_pending_3f)
  return info_float_mod.new({["floating-window-mod"] = deps["floating-window-mod"], ["info-min-width"] = deps["info-min-width"], ["info-height"] = deps["info-height"], ["animation-mod"] = deps["animation-mod"], ["animate-enter?"] = deps["animate-enter?"], ["info-fade-ms"] = deps["info-fade-ms"], ["valid-info-win?"] = valid_info_win_3f, ["session-host-win"] = session_host_win, ["effective-info-height"] = effective_info_height, ["info-winbar-active?"] = info_winbar_active_3f, ["project-loading-pending?"] = project_loading_pending_3f, events = events, ["apply-metabuffer-window-highlights!"] = apply_metabuffer_window_highlights_21, ["info-buffer-mod"] = info_buffer_mod})
end
local function build_info_render(deps, resize_info_window_21, refresh_info_statusline_21, project_loading_pending_3f)
  return info_render_mod.new({["info-min-width"] = deps["info-min-width"], ["info-max-width"] = deps["info-max-width"], ["info-max-lines"] = deps["info-max-lines"], ["info-height"] = deps["info-height"], ["debug-log"] = deps["debug-log"], ["read-file-lines-cached"] = deps["read-file-lines-cached"], ["read-file-view-cached"] = deps["read-file-view-cached"], ["resize-info-window!"] = resize_info_window_21, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["valid-info-win?"] = valid_info_win_3f, ["session-host-win"] = session_host_win, ["ext-start-in-file"] = ext_start_in_file, ["icon-field"] = icon_field, ["project-loading-pending?"] = project_loading_pending_3f})
end
local function build_project_info(deps, ensure_info_window, settle_info_window_21, refresh_info_statusline_21, render_info_lines_21, sync_info_selection_21, info_visible_range, fit_info_width_21, set_info_topline_21)
  return info_project_mod.new({["startup-layout-pending?"] = startup_layout_pending_3f, ["loading-skeleton-lines"] = loading_skeleton_lines, ["info-height"] = deps["info-height"], ["ensure-info-window"] = ensure_info_window, ["settle-info-window!"] = settle_info_window_21, ["refresh-info-statusline!"] = refresh_info_statusline_21, ["render-info-lines!"] = render_info_lines_21, ["sync-info-selection!"] = sync_info_selection_21, ["refs-slice-sig"] = refs_slice_sig, ["info-visible-range"] = info_visible_range, ["fit-info-width!"] = fit_info_width_21, ["set-info-topline!"] = set_info_topline_21, ["info-max-lines"] = deps["info-max-lines"], ["debug-log"] = deps["debug-log"], ["valid-info-win?"] = valid_info_win_3f})
end
local function update_info_21(session, refresh_lines, ensure_info_window, settle_info_window_21, update_project_21, update_regular_21)
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
M.new = function(opts)
  local deps = (opts or {})
  local update_21 = nil
  local project_loading_pending_3f = nil
  local update_project_21 = nil
  local function project_loading_3f(session)
    return project_loading_pending_3f(session)
  end
  local info_float = build_info_float(deps, project_loading_3f)
  local ensure_info_window
  local function _3_(session)
    return info_float["ensure-window!"](session, update_21)
  end
  ensure_info_window = _3_
  local settle_info_window_21 = info_float["settle-window!"]
  local resize_info_window_21 = info_float["resize-window!"]
  local refresh_info_statusline_21 = info_float["refresh-statusline!"]
  local close_info_window_21 = info_float["close-window!"]
  local info_render = build_info_render(deps, resize_info_window_21, refresh_info_statusline_21, project_loading_3f)
  local update_regular_21 = info_render["update-regular!"]
  local fit_info_width_21 = info_render["fit-info-width!"]
  local render_info_lines_21 = info_render["render-info-lines!"]
  local set_info_topline_21 = info_render["set-info-topline!"]
  local sync_info_selection_21 = info_render["sync-info-selection!"]
  local info_visible_range = info_render["info-visible-range"]
  local project_info = build_project_info(deps, ensure_info_window, settle_info_window_21, refresh_info_statusline_21, render_info_lines_21, sync_info_selection_21, info_visible_range, fit_info_width_21, set_info_topline_21)
  project_loading_pending_3f = project_info["project-loading-pending?"]
  update_project_21 = project_info["update-project!"]
  local function _4_(session, refresh_lines)
    return update_info_21(session, refresh_lines, ensure_info_window, settle_info_window_21, update_project_21, update_regular_21)
  end
  update_21 = _4_
  return {["close-window!"] = close_info_window_21, ["update!"] = update_21, ["refresh-statusline!"] = refresh_info_statusline_21}
end
return M
