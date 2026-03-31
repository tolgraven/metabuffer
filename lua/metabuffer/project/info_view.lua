-- [nfnl] fnl/metabuffer/project/info_view.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local info_loading_ns = vim.api.nvim_create_namespace("MetaInfoWindow")
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
  local info_visible_range = opts["info-visible-range"]
  local fit_info_width_21 = opts["fit-info-width!"]
  local set_info_topline_21 = opts["set-info-topline!"]
  local info_max_lines = opts["info-max-lines"]
  local debug_log = opts["debug-log"]
  local valid_info_win_3f = opts["valid-info-win?"]
  local update_project_21 = nil
  local function project_loading_pending_3f(session)
    local startup = startup_layout_pending_3f(session)
    local bootstrap_pending = (session["project-bootstrap-pending"] or false)
    local bootstrapped = (session["project-bootstrapped"] or false)
    local stream_done = (session["lazy-stream-done"] or false)
    local pending = (session and session["project-mode"] and (startup or bootstrap_pending or not bootstrapped or not stream_done))
    return pending
  end
  local function render_project_loading_21(session, fit_info_width_210)
    local lines = loading_skeleton_lines(info_height(session))
    local ns = info_loading_ns
    session["info-last-project-loading?"] = true
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
    fit_info_width_210(session, lines)
    vim.api.nvim_buf_set_lines(session["info-buf"], 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(session["info-buf"], ns, 0, -1)
    for row = 0, (#lines - 1) do
      vim.api.nvim_buf_add_highlight(session["info-buf"], ns, "Comment", row, 0, -1)
    end
    local bo = vim.bo[session["info-buf"]]
    bo.modifiable = false
    return nil
  end
  local function update_project_startup_21(session)
    session["info-last-project-loading?"] = true
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
        render_info_lines_21({session = session, meta = meta, ["render-start"] = wanted_start, ["render-stop"] = wanted_stop, ["visible-start"] = wanted_start, ["visible-stop"] = wanted_stop})
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
  local function project_info_force_refresh_3f(session, meta, refresh_lines, loading_changed_3f)
    return (refresh_lines or loading_changed_3f or ((session["info-last-selected-index"] or -1) ~= (meta.selected_index or -1)) or (session["info-render-sig"] == nil) or session["info-project-loading-active?"] or session["info-showing-project-loading?"])
  end
  local function project_info_range_state(session, meta)
    local idxs = (meta.buf.indices or {})
    local total = #idxs
    local _let_14_ = info_visible_range(session, meta, total, info_max_lines)
    local wanted_start = _let_14_[1]
    local wanted_stop = _let_14_[2]
    local out_of_range = (((session["info-start-index"] or 1) < wanted_start) or ((session["info-stop-index"] or 0) > wanted_stop))
    local range_changed = ((wanted_start ~= (session["info-start-index"] or 1)) or (wanted_stop ~= (session["info-stop-index"] or 0)))
    return {["wanted-start"] = wanted_start, ["wanted-stop"] = wanted_stop, ["out-of-range"] = out_of_range, ["range-changed"] = range_changed}
  end
  local function project_info_render_sig(session, meta, wanted_start, wanted_stop)
    local idxs = (meta.buf.indices or {})
    local refs = (meta.buf["source-refs"] or {})
    return table.concat({tostring((session["info-max-width"] or 0)), tostring(wanted_start), tostring(wanted_stop), tostring((meta.selected_index or 0)), refs_slice_sig(session, refs, idxs, wanted_start, wanted_stop), tostring((session["info-project-loading-active?"] or false))}, "|")
  end
  local function schedule_project_info_finish_refresh_21(session)
    if not session["info-project-finish-refresh-pending?"] then
      session["info-project-finish-refresh-pending?"] = true
      local function _15_()
        session["info-project-finish-refresh-pending?"] = false
        if (valid_info_win_3f(session) and not project_loading_pending_3f(session)) then
          session["info-project-loading-active?"] = false
          session["info-showing-project-loading?"] = false
          session["info-render-sig"] = nil
          return update_project_21(session, false)
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
    render_info_lines_21({session = session, meta = meta, ["render-start"] = wanted_start, ["render-stop"] = wanted_stop, ["visible-start"] = wanted_start, ["visible-stop"] = wanted_stop})
    return sync_info_selection_21(session, meta)
  end
  local function _18_(session, refresh_lines)
    local loading_pending_3f = project_loading_pending_3f(session)
    local loading_changed_3f = (clj.boolean(session["info-last-project-loading?"]) ~= clj.boolean(loading_pending_3f))
    if loading_pending_3f then
      return update_project_startup_21(session)
    else
      settle_info_render_state_21(session)
      project_info_debug_21(session, refresh_lines)
      refresh_info_statusline_21(session)
      if (not session["info-render-suspended?"] and session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
        local meta = session.meta
        local loading_finished_3f = true
        local force_refresh_3f = project_info_force_refresh_3f(session, meta, refresh_lines, loading_changed_3f)
        local _let_19_ = project_info_range_state(session, meta)
        local wanted_start = _let_19_["wanted-start"]
        local wanted_stop = _let_19_["wanted-stop"]
        local out_of_range = _let_19_["out-of-range"]
        local range_changed = _let_19_["range-changed"]
        local sig = project_info_render_sig(session, meta, wanted_start, wanted_stop)
        local sig_changed_3f = (session["info-render-sig"] ~= sig)
        if (force_refresh_3f or out_of_range or range_changed or sig_changed_3f) then
          rerender_project_info_21(session, meta, wanted_start, wanted_stop, loading_finished_3f)
        else
        end
        if (not (force_refresh_3f or out_of_range or range_changed or sig_changed_3f) and set_info_topline_21) then
          set_info_topline_21(session, wanted_start)
        else
        end
        if loading_changed_3f then
          schedule_project_info_finish_refresh_21(session)
        else
        end
        session["info-last-selected-index"] = (meta.selected_index or -1)
        session["info-last-project-loading?"] = false
        return sync_info_selection_21(session, meta)
      else
        return nil
      end
    end
  end
  update_project_21 = _18_
  return {["project-loading-pending?"] = project_loading_pending_3f, ["update-project!"] = update_project_21}
end
return M
