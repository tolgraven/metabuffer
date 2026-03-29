-- [nfnl] fnl/metabuffer/window/info_viewport.fnl
local M = {}
local helper_mod = require("metabuffer.window.info_helpers")
local info_placeholder_line = helper_mod["info-placeholder-line"]
local info_range = helper_mod["info-range"]
local numeric_max = helper_mod["numeric-max"]
local info_winbar_active_3f = helper_mod["info-winbar-active?"]
M.new = function(opts)
  local _let_1_ = (opts or {})
  local info_min_width = _let_1_["info-min-width"]
  local info_max_width = _let_1_["info-max-width"]
  local info_height = _let_1_["info-height"]
  local resize_info_window_21 = _let_1_["resize-info-window!"]
  local valid_info_win_3f = _let_1_["valid-info-win?"]
  local session_host_win = _let_1_["session-host-win"]
  local project_loading_pending_3f = _let_1_["project-loading-pending?"]
  local function set_info_topline_21(session, top)
    if valid_info_win_3f(session) then
      local function _2_()
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
      return vim.api.nvim_win_call(session["info-win"], _2_)
    else
      return nil
    end
  end
  local function ensure_buffer_shape_21(session, render_stop)
    if (session["info-buf"] and vim.api.nvim_buf_is_valid(session["info-buf"])) then
      local needed = math.max(1, (render_stop or 0))
      local current = vim.api.nvim_buf_line_count(session["info-buf"])
      if (current ~= needed) then
        do
          local bo = vim.bo[session["info-buf"]]
          bo["modifiable"] = true
        end
        if (current < needed) then
          local function _4_(_)
            return info_placeholder_line(session)
          end
          vim.api.nvim_buf_set_lines(session["info-buf"], current, current, false, vim.tbl_map(_4_, vim.fn.range((current + 1), needed)))
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
      local function _8_(line)
        return vim.fn.strdisplaywidth((line or ""))
      end
      widths = vim.tbl_map(_8_, (lines or {}))
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
        local function _13_()
          return vim.fn.winsaveview()
        end
        view = vim.api.nvim_win_call(meta.win.window, _13_)
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
  return {["ensure-buffer-shape!"] = ensure_buffer_shape_21, ["fit-info-width!"] = fit_info_width_21, ["info-max-width-now"] = info_max_width_now, ["info-visible-range"] = info_visible_range, ["set-info-topline!"] = set_info_topline_21}
end
return M
