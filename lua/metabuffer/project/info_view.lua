-- [nfnl] fnl/metabuffer/project/info_view.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M.new = function(opts)
  local startup_layout_pending_3f = opts["startup-layout-pending?"]
  local loading_skeleton_lines = opts["loading-skeleton-lines"]
  local info_height = opts["info-height"]
  local ensure_info_window = opts["ensure-info-window"]
  local settle_info_window_21 = opts["settle-info-window!"]
  local refresh_info_statusline_21 = opts["refresh-info-statusline!"]
  local render_info_lines_21 = opts["render-info-lines!"]
  local sync_info_selection_21 = opts["sync-info-selection!"]
  local refs_slice_sig = opts["refs-slice-sig"]
  local info_range = opts["info-range"]
  local info_max_lines = opts["info-max-lines"]
  local debug_log = opts["debug-log"]
  local valid_info_win_3f = opts["valid-info-win?"]
  local function project_loading_pending_3f(session)
    local startup = startup_layout_pending_3f(session)
    local bootstrap_pending = (session["project-bootstrap-pending"] or false)
    local bootstrapped = (session["project-bootstrapped"] or false)
    local stream_done = (session["lazy-stream-done"] or false)
    local pending = (session and session["project-mode"] and (startup or bootstrap_pending or not bootstrapped or not stream_done))
    return pending
  end
  local function render_project_loading_21(session, fit_info_width_21)
    local lines = loading_skeleton_lines(info_height(session))
    local ns = vim.api.nvim_create_namespace("MetaInfoWindow")
    session["info-start-index"] = 1
    session["info-stop-index"] = #lines
    do
      local bo = vim.bo[session["info-buf"]]
      bo.modifiable = true
    end
    session["info-highlight-fill-token"] = (1 + (session["info-highlight-fill-token"] or 0))
    session["info-highlight-fill-pending?"] = false
    session["info-showing-project-loading?"] = true
    session["info-render-sig"] = nil
    fit_info_width_21(session, lines)
    vim.api.nvim_buf_set_lines(session["info-buf"], 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(session["info-buf"], ns, 0, -1)
    for row = 0, (#lines - 1) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Comment", row, 0, -1)
    end
    local bo = vim.bo[session["info-buf"]]
    bo.modifiable = false
    return nil
  end
  local function update_project_startup_21(session, fit_info_width_21, info_visible_range)
    session["info-project-loading-active?"] = true
    ensure_info_window(session)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    settle_info_window_21(session)
    if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local meta = session.meta
      local idxs = (meta.buf.indices or {})
      local total = #idxs
      if (total > 0) then
        local _let_2_ = info_visible_range(session, meta, total, info_max_lines)
        local wanted_start = _let_2_[1]
        local wanted_stop = _let_2_[2]
        session["info-showing-project-loading?"] = false
        render_info_lines_21(session, meta, wanted_start, wanted_stop, wanted_start, wanted_stop)
        return sync_info_selection_21(session, meta)
      else
        return render_project_loading_21(session, fit_info_width_21)
      end
    else
      return nil
    end
  end
  local function settle_info_render_state_21(session)
    ensure_info_window(session)
    if (session["info-render-suspended?"] and not session["prompt-animating?"] and not session["startup-initializing"]) then
      session["info-post-fade-refresh?"] = nil
      session["info-render-suspended?"] = false
    else
    end
    return settle_info_window_21(session)
  end
  local function project_info_debug_21(session, refresh_lines)
    if debug_log then
      local _6_
      if refresh_lines then
        _6_ = " refresh"
      else
        _6_ = ""
      end
      local _8_
      if session["project-bootstrap-pending"] then
        _8_ = " bootstrap-pending"
      else
        _8_ = ""
      end
      local _10_
      if session["info-project-loading-active?"] then
        _10_ = " loading-active"
      else
        _10_ = ""
      end
      local function _12_()
        if session["info-render-suspended?"] then
          return " suspended"
        else
          return ""
        end
      end
      return debug_log(table.concat({"info project", _6_, _8_, _10_, _12_()}, ""))
    else
      return nil
    end
  end
  local function project_info_force_refresh_3f(session, refresh_lines)
    return (refresh_lines or (session["info-render-sig"] == nil) or session["info-project-loading-active?"] or session["info-showing-project-loading?"])
  end
  local function project_info_range_state(session, meta)
    local idxs = (meta.buf.indices or {})
    local total = #idxs
    local _let_14_ = info_range(meta.selected_index, total, info_max_lines)
    local wanted_start = _let_14_[1]
    local wanted_stop = _let_14_[2]
    local out_of_range = (((session["info-start-index"] or 1) < wanted_start) or ((session["info-stop-index"] or 0) > wanted_stop))
    local range_changed = ((wanted_start ~= (session["info-start-index"] or 1)) or (wanted_stop ~= (session["info-stop-index"] or 0)))
    return {["wanted-start"] = wanted_start, ["wanted-stop"] = wanted_stop, ["out-of-range"] = out_of_range, ["range-changed"] = range_changed}
  end
  local function project_info_render_sig(session, meta, wanted_start, wanted_stop)
    local idxs = (meta.buf.indices or {})
    local refs = (meta.buf["source-refs"] or {})
    return table.concat({(session["info-max-width"] or 0), wanted_start, wanted_stop, refs_slice_sig(session, refs, idxs, wanted_start, wanted_stop), (session["info-project-loading-active?"] or false)}, "|")
  end
  local function schedule_project_info_finish_refresh_21(session)
    if not session["info-project-finish-refresh-pending?"] then
      session["info-project-finish-refresh-pending?"] = true
      local function _15_()
        session["info-project-finish-refresh-pending?"] = false
        if (valid_info_win_3f(session) and not project_loading_pending_3f(session)) then
          session["info-project-loading-active?"] = false
          session["info-showing-project-loading?"] = false
          return refresh_info_statusline_21(session)
        else
          return nil
        end
      end
      return vim.defer_fn(_15_, 30)
    else
      return nil
    end
  end
  local function rerender_project_info_21(session, meta, wanted_start, wanted_stop, loading_finished_3f)
    session["info-render-sig"] = project_info_render_sig(session, meta, wanted_start, wanted_stop)
    session["info-project-loading-active?"] = not loading_finished_3f
    session["info-showing-project-loading?"] = false
    render_info_lines_21(session, meta, wanted_start, wanted_stop, wanted_start, wanted_stop)
    sync_info_selection_21(session, meta)
    if loading_finished_3f then
      return schedule_project_info_finish_refresh_21(session)
    else
      return nil
    end
  end
  local function update_project_21(session, refresh_lines, fit_info_width_21, info_visible_range)
    if project_loading_pending_3f(session) then
      return update_project_startup_21(session, fit_info_width_21, info_visible_range)
    else
      settle_info_render_state_21(session)
      project_info_debug_21(session, refresh_lines)
      refresh_info_statusline_21(session)
      if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
        local meta = session.meta
        local loading_finished_3f = not clj.boolean(session["info-project-loading-active?"])
        local force_refresh_3f = project_info_force_refresh_3f(session, refresh_lines)
        local _let_19_ = project_info_range_state(session, meta)
        local wanted_start = _let_19_["wanted-start"]
        local wanted_stop = _let_19_["wanted-stop"]
        local out_of_range = _let_19_["out-of-range"]
        local range_changed = _let_19_["range-changed"]
        if (force_refresh_3f or out_of_range or range_changed) then
          local sig = project_info_render_sig(session, meta, wanted_start, wanted_stop)
          if (force_refresh_3f or out_of_range or range_changed or (session["info-render-sig"] ~= sig)) then
            rerender_project_info_21(session, meta, wanted_start, wanted_stop, loading_finished_3f)
          else
          end
        else
        end
        return sync_info_selection_21(session, meta)
      else
        return nil
      end
    end
  end
  return {["project-loading-pending?"] = project_loading_pending_3f, ["update-project!"] = update_project_21}
end
return M
