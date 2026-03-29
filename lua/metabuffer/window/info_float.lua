-- [nfnl] fnl/metabuffer/window/info_float.fnl
local M = {}
M.new = function(opts)
  local floating_window_mod = opts["floating-window-mod"]
  local info_min_width = opts["info-min-width"]
  local info_height = opts["info-height"]
  local animation_mod = opts["animation-mod"]
  local animate_enter_3f = opts["animate-enter?"]
  local info_fade_ms = opts["info-fade-ms"]
  local valid_info_win_3f = opts["valid-info-win?"]
  local session_host_win = opts["session-host-win"]
  local effective_info_height = opts["effective-info-height"]
  local info_winbar_active_3f = opts["info-winbar-active?"]
  local project_loading_pending_3f = opts["project-loading-pending?"]
  local events = opts.events
  local apply_metabuffer_window_highlights_21 = opts["apply-metabuffer-window-highlights!"]
  local info_buffer_mod = opts["info-buffer-mod"]
  local function info_config_signature(cfg)
    return table.concat({(cfg.relative or ""), tostring((cfg.win or 0)), (cfg.anchor or ""), tostring((cfg.row or 0)), tostring((cfg.col or 0)), tostring((cfg.width or 0)), tostring((cfg.height or 0)), tostring(not not cfg.focusable)}, "|")
  end
  local function apply_info_config_if_changed_21(session, cfg)
    if valid_info_win_3f(session) then
      local sig = info_config_signature(cfg)
      if (sig ~= session["info-config-sig"]) then
        session["info-config-sig"] = sig
        return pcall(vim.api.nvim_win_set_config, session["info-win"], cfg)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function info_window_config(session, width, height)
    local host_win = (session_host_win(session) or vim.api.nvim_get_current_win())
    local _own_winbar_row
    if info_winbar_active_3f(session, project_loading_pending_3f) then
      _own_winbar_row = 1
    else
      _own_winbar_row = 0
    end
    if session["window-local-layout"] then
      local wb_ok,wb_val = pcall(vim.api.nvim_get_option_value, "winbar", {win = host_win})
      local has_winbar_3f = (wb_ok and (type(wb_val) == "string") and (wb_val ~= ""))
      local base_row
      if has_winbar_3f then
        base_row = 1
      else
        base_row = 0
      end
      local row = base_row
      local host_height = vim.api.nvim_win_get_height(host_win)
      local wanted_h = math.max(1, height)
      local max_h = math.max(1, (host_height - math.max(row, 0)))
      local h = math.min(wanted_h, max_h)
      return {relative = "win", win = host_win, anchor = "NW", row = row, col = vim.api.nvim_win_get_width(host_win), width = width, height = h, focusable = false}
    else
      return {relative = "editor", anchor = "NE", row = 1, col = vim.o.columns, width = width, height = math.max(1, height), focusable = false}
    end
  end
  local function info_target_config(session)
    local width = info_min_width
    local height = effective_info_height(session, info_height, project_loading_pending_3f)
    return {width = width, height = height, target = info_window_config(session, width, height)}
  end
  local function animate_info_enter_3f(session, prompt_target)
    return (animation_mod and animate_enter_3f and animate_enter_3f(session) and animation_mod["enabled?"](session, "info") and not session["info-animated?"] and prompt_target)
  end
  local function initial_info_config(target, animate_info_3f)
    if animate_info_3f then
      local start = vim.deepcopy(target)
      start["col"] = (target.col + 8)
      start["winblend"] = 100
      return start
    else
      return target
    end
  end
  local function configure_info_buffer_21(session, buf)
    info_buffer_mod.new(buf)
    session["info-buf"] = buf
    return buf
  end
  local function configure_info_window_21(session, target, win)
    session["info-win"] = win.window
    session["info-config-sig"] = info_config_signature(target)
    events.send("on-win-create!", {win = session["info-win"], role = "info"})
    apply_metabuffer_window_highlights_21(session["info-win"])
    local wo = vim.wo[win.window]
    wo["statusline"] = ""
    wo["winbar"] = ""
    wo["number"] = false
    wo["relativenumber"] = false
    wo["wrap"] = false
    wo["linebreak"] = false
    wo["signcolumn"] = "no"
    wo["foldcolumn"] = "0"
    wo["spell"] = false
    wo["cursorline"] = false
    return nil
  end
  local function start_info_enter_animation_21(session, update_21, cfg, target)
    session["info-animated?"] = true
    session["info-render-suspended?"] = true
    session["info-post-fade-refresh?"] = true
    pcall(vim.api.nvim_set_option_value, "winblend", 100, {win = session["info-win"]})
    local function _7_()
      if valid_info_win_3f(session) then
        local function _8_(_)
          if valid_info_win_3f(session) then
            session["info-post-fade-refresh?"] = nil
            session["info-render-suspended?"] = false
            return update_21(session, true)
          else
            return nil
          end
        end
        return animation_mod["animate-float!"](session, "info-enter", session["info-win"], cfg, target, 100, (vim.g.meta_float_winblend or 13), animation_mod["duration-ms"](session, "info", (info_fade_ms or 220)), {kind = "info", ["done!"] = _8_})
      else
        return nil
      end
    end
    return vim.defer_fn(_7_, 17)
  end
  local function ensure_window_21(session, update_21)
    if not valid_info_win_3f(session) then
      local _let_11_ = info_target_config(session)
      local target = _let_11_.target
      local buf = vim.api.nvim_create_buf(false, true)
      local animate_info_3f = animate_info_enter_3f(session, target)
      local cfg = initial_info_config(target, animate_info_3f)
      local win = floating_window_mod.new(vim, buf, cfg)
      configure_info_buffer_21(session, buf)
      configure_info_window_21(session, target, win)
      if animate_info_3f then
        return start_info_enter_animation_21(session, update_21, cfg, target)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function settle_window_21(session)
    if valid_info_win_3f(session) then
      local width = vim.api.nvim_win_get_width(session["info-win"])
      local height = effective_info_height(session, info_height, project_loading_pending_3f)
      local cfg = info_window_config(session, width, height)
      return apply_info_config_if_changed_21(session, cfg)
    else
      return nil
    end
  end
  local function resize_window_21(session, width, height)
    if valid_info_win_3f(session) then
      local cfg = info_window_config(session, width, height)
      return apply_info_config_if_changed_21(session, cfg)
    else
      return nil
    end
  end
  local function refresh_statusline_21(session)
    if valid_info_win_3f(session) then
      local total = #((session and session.meta and session.meta.buf and session.meta.buf.indices) or {})
      local start_index = (session["info-start-index"] or 1)
      local stop_index
      local or_16_ = session["info-stop-index"]
      if not or_16_ then
        if (total > 0) then
          or_16_ = total
        else
          or_16_ = 0
        end
      end
      stop_index = or_16_
      local range
      if (total <= 0) then
        range = "0/0"
      else
        range = (start_index .. "-" .. stop_index .. "/" .. total)
      end
      local loading_title
      if project_loading_pending_3f(session) then
        local streamed = math.max(0, ((session["lazy-stream-next"] or 1) - 1))
        local total_files = (session["lazy-stream-total"] or 0)
        if (total_files > 0) then
          loading_title = ("Info  loading " .. streamed .. "/" .. total_files .. " files")
        else
          loading_title = "Info  loading project"
        end
      else
        if session["info-highlight-fill-pending?"] then
          loading_title = ("Info  loading " .. range)
        else
          loading_title = nil
        end
      end
      local winbar
      if loading_title then
        winbar = ("%#Comment#" .. loading_title)
      else
        winbar = ""
      end
      pcall(vim.api.nvim_set_option_value, "statusline", "", {win = session["info-win"]})
      return pcall(vim.api.nvim_set_option_value, "winbar", winbar, {win = session["info-win"]})
    else
      return nil
    end
  end
  local function close_window_21(session)
    if valid_info_win_3f(session) then
      pcall(vim.api.nvim_win_close, session["info-win"], true)
    else
    end
    session["info-win"] = nil
    session["info-buf"] = nil
    session["info-config-sig"] = nil
    session["info-post-fade-refresh?"] = nil
    session["info-render-suspended?"] = nil
    session["info-highlight-fill-pending?"] = nil
    session["info-highlight-fill-token"] = nil
    session["info-line-meta-refresh-pending"] = nil
    session["info-fixed-width"] = nil
    return nil
  end
  return {["ensure-window!"] = ensure_window_21, ["settle-window!"] = settle_window_21, ["resize-window!"] = resize_window_21, ["refresh-statusline!"] = refresh_statusline_21, ["close-window!"] = close_window_21}
end
return M
