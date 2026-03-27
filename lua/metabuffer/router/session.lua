-- [nfnl] fnl/metabuffer/router/session.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
local M = {}
local function silent_win_set_buf_21(win, buf)
  if (win and buf and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    local function _1_()
      return vim.cmd(("silent keepalt noautocmd buffer " .. buf))
    end
    return (pcall(vim.api.nvim_win_call, win, _1_) or pcall(vim.api.nvim_win_set_buf, win, buf))
  else
    return nil
  end
end
local function launch_source_label(session)
  if session["project-mode"] then
    return ("Project mode in dir " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"))
  else
    local path0 = (session["origin-buf"] and vim.api.nvim_buf_is_valid(session["origin-buf"]) and vim.api.nvim_buf_get_name(session["origin-buf"]))
    local path = (path0 or "")
    if (path ~= "") then
      return vim.fn.fnamemodify(path, ":t")
    else
      return "[No Name]"
    end
  end
end
local function show_launch_message_21(session)
  if session then
    local function _5_()
      return vim.api.nvim_echo({{("Metabuffer \226\128\162 " .. launch_source_label(session) .. " \226\128\162 instance " .. tostring((session["instance-id"] or "?"))), "ModeMsg"}}, true, {})
    end
    return vim.schedule(_5_)
  else
    return nil
  end
end
local function run_step_21(label, f)
  local ok,res = xpcall(f, debug.traceback)
  if ok then
    return res
  else
    return error((label .. ": " .. res))
  end
end
local function startup_ui_delay_ms(animate_enter_3f, animation_settings)
  local settings = (animation_settings or {})
  local global_enabled_3f = (animate_enter_3f and not (false == settings.enabled))
  local global_scale = (settings["time-scale"] or 1)
  local prompt_settings = (settings.prompt or {})
  local info_settings = (settings.info or {})
  local prompt_ms
  if (global_enabled_3f and not (false == prompt_settings.enabled)) then
    prompt_ms = math.max(0, math.floor((0.5 + ((prompt_settings.ms or 140) * global_scale * (prompt_settings["time-scale"] or 1)))))
  else
    prompt_ms = 0
  end
  local info_ms
  if (global_enabled_3f and not (false == info_settings.enabled)) then
    info_ms = math.max(0, math.floor((0.5 + ((info_settings.ms or 220) * global_scale * (info_settings["time-scale"] or 1)))))
  else
    info_ms = 0
  end
  return math.max(prompt_ms, info_ms)
end
local function project_start_selected_index(project_mode, mode, source_view, condition)
  if (project_mode and (mode == "start")) then
    return math.max(0, ((source_view.lnum or ((condition["selected-index"] or 0) + 1)) - 1))
  else
    return (condition["selected-index"] or 0)
  end
end
local function hide_startup_cursor_21(session)
  if (session and not session["startup-cursor-hidden?"]) then
    local ok,current = pcall(vim.api.nvim_get_option_value, "guicursor", {scope = "global"})
    if ok then
      session["startup-saved-guicursor"] = current
    else
      session["startup-saved-guicursor"] = vim.o.guicursor
    end
    session["startup-cursor-hidden?"] = true
    return pcall(vim.api.nvim_set_option_value, "guicursor", "a:ver0", {scope = "global"})
  else
    return nil
  end
end
local function restore_startup_cursor_21(session)
  if (session and session["startup-cursor-hidden?"]) then
    local value = (session["startup-saved-guicursor"] or vim.o.guicursor)
    session["startup-cursor-hidden?"] = false
    session["startup-saved-guicursor"] = nil
    return pcall(vim.api.nvim_set_option_value, "guicursor", value, {scope = "global"})
  else
    return nil
  end
end
local function current_session_for_buffer(router, buf)
  local or_14_ = router["active-by-source"][buf] or router["active-by-prompt"][buf]
  if not or_14_ then
    local found0 = nil
    local found = found0
    for _, session in pairs((router["active-by-prompt"] or {})) do
      if (not found and session) then
        local meta_buf = (session.meta and session.meta.buf and session.meta.buf.buffer)
        if ((buf == meta_buf) or (buf == session["prompt-buf"]) or (buf == session["preview-buf"]) or (buf == session["info-buf"]) or (buf == session["history-browser-buf"]) or (buf == session["source-buf"]) or (buf == session["origin-buf"])) then
          found = session
        else
        end
      else
      end
    end
    or_14_ = found
  end
  return or_14_
end
local function existing_visible_meta(session)
  return (session and not session["ui-hidden"] and not session.closing and session.meta)
end
local function register_prompt_hooks_21(deps, session)
  local router = deps.router
  local mods = deps.mods
  local windows = deps.windows
  local prompt_hooks_mod = mods["prompt-hooks"]
  local active_by_prompt = router["active-by-prompt"]
  local on_prompt_changed = deps["on-prompt-changed"]
  local update_info_window = deps["update-info-window"]
  local update_preview_window = deps["update-preview-window"]
  local maybe_sync_from_main_21 = deps["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = deps["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = deps["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = deps["hide-visible-ui!"]
  local preview_window = windows.preview
  local context_window = windows.context
  local project_source = deps["project-source"]
  local sign_mod = deps["sign-mod"]
  local hooks
  local function _18_(s)
    if (preview_window and preview_window["refresh-statusline!"]) then
      return preview_window["refresh-statusline!"](s)
    else
      return nil
    end
  end
  local function _20_(s)
    if (context_window and context_window["update!"]) then
      return context_window["update!"](s)
    else
      return nil
    end
  end
  local function _22_(s)
    if (project_source and project_source["apply-source-set!"]) then
      return project_source["apply-source-set!"](s)
    else
      return nil
    end
  end
  hooks = prompt_hooks_mod.new({["default-prompt-keymaps"] = router["prompt-keymaps"], ["default-main-keymaps"] = router["main-keymaps"], ["active-by-prompt"] = active_by_prompt, ["on-prompt-changed"] = on_prompt_changed, ["update-info-window"] = update_info_window, ["update-preview-window"] = update_preview_window, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21, ["maybe-restore-hidden-ui!"] = maybe_restore_hidden_ui_21, ["hide-visible-ui!"] = hide_visible_ui_21, ["maybe-refresh-preview-statusline!"] = _18_, ["update-context-window!"] = _20_, ["rebuild-source-set!"] = _22_, ["sign-mod"] = sign_mod})
  session["prompt-hooks"] = hooks
  return hooks["register!"](router, session)
end
local function activate_session_ui_21(deps, session, initial_lines)
  local router = deps.router
  local mods = deps.mods
  local active_by_source = router["active-by-source"]
  local active_by_prompt = router["active-by-prompt"]
  local animation_mod = mods.animation
  local prompt_window_mod = mods["prompt-window"]
  local preview_window = deps.windows.preview
  local update_info_window = deps["update-info-window"]
  local session_view = deps["session-view"]
  local sync_prompt_buffer_name_21 = deps["sync-prompt-buffer-name!"]
  local ui_animation_prompt_ms = deps.ui.animation.prompt.ms
  local prompt_buf = session["prompt-buf"]
  local prompt_win = session["prompt-win"]
  local function startup_live_3f()
    return ((active_by_prompt[prompt_buf] == session) and not session["ui-hidden"] and not session.closing)
  end
  local function restore_main_view_21()
    if (startup_live_3f() and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      return session_view["restore-meta-view!"](session.meta, session["source-view"], session, update_info_window)
    else
      return nil
    end
  end
  local function prompt_enter_duration_ms()
    if (animation_mod and animation_mod["enabled?"](session, "prompt")) then
      return animation_mod["duration-ms"](session, "prompt", (ui_animation_prompt_ms or 140))
    else
      return 0
    end
  end
  local function prompt_float_config(height)
    local host_win = (session["origin-win"] or (session.meta and session.meta.win and session.meta.win.window) or prompt_win)
    local host_width
    if (host_win and vim.api.nvim_win_is_valid(host_win)) then
      host_width = vim.api.nvim_win_get_width(host_win)
    else
      host_width = vim.o.columns
    end
    local host_height
    if (host_win and vim.api.nvim_win_is_valid(host_win)) then
      host_height = vim.api.nvim_win_get_height(host_win)
    else
      host_height = (vim.o.lines - 2)
    end
    return {relative = "win", win = host_win, anchor = "SW", row = host_height, col = 0, width = host_width, height = math.max(1, height), style = "minimal"}
  end
  local function schedule_layout_refresh_21()
    if (session["project-mode"] and update_info_window) then
      local base_delay
      if (animation_mod and animation_mod["enabled?"](session, "prompt")) then
        base_delay = animation_mod["duration-ms"](session, "prompt", (ui_animation_prompt_ms or 140))
      else
        base_delay = 0
      end
      local function refresh_after_21(delay)
        local function _29_()
          if startup_live_3f() then
            return pcall(update_info_window, session, true)
          else
            return nil
          end
        end
        return vim.defer_fn(_29_, delay)
      end
      return refresh_after_21((24 + base_delay))
    else
      return nil
    end
  end
  local function _32_()
    return sync_prompt_buffer_name_21(session)
  end
  run_step_21("activate-session-ui/sync-prompt-buffer-name", _32_)
  local function _33_()
    return hide_startup_cursor_21(session)
  end
  run_step_21("activate-session-ui/hide-startup-cursor", _33_)
  local function _34_()
    return vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, initial_lines)
  end
  run_step_21("activate-session-ui/set-prompt-lines", _34_)
  local function _35_()
    return register_prompt_hooks_21(deps, session)
  end
  run_step_21("activate-session-ui/register-prompt-hooks", _35_)
  active_by_source[session["source-buf"]] = session
  active_by_prompt[prompt_buf] = session
  if (animation_mod and (animation_mod["animation-backend"](session, "scroll") == "mini") and animation_mod["supports-backend?"]("mini")) then
    animation_mod["ensure-mini-global!"](session)
  else
  end
  if (session["animate-enter?"] and animation_mod and prompt_win and vim.api.nvim_win_is_valid(prompt_win) and animation_mod["enabled?"](session, "prompt") and not session["prompt-animated?"]) then
    session["prompt-animated?"] = true
    session["prompt-animating?"] = true
  else
  end
  if (preview_window and preview_window["ensure-window!"]) then
    local function _38_()
      return preview_window["ensure-window!"](session)
    end
    run_step_21("activate-session-ui/ensure-preview-window", _38_)
  else
  end
  if (prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
    local function _40_()
      if session["prompt-floating?"] then
        return pcall(vim.api.nvim_win_set_config, prompt_win, prompt_float_config(1))
      else
        return pcall(vim.api.nvim_win_set_height, prompt_win, 1)
      end
    end
    run_step_21("activate-session-ui/initial-prompt-layout", _40_)
  else
  end
  if (session["animate-enter?"] and animation_mod and prompt_win and vim.api.nvim_win_is_valid(prompt_win) and animation_mod["enabled?"](session, "prompt") and session["prompt-animating?"]) then
    local function _43_()
      if (startup_live_3f() and session["prompt-animating?"] and prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
        local function done_21(_)
          if not startup_live_3f() then
            restore_startup_cursor_21(session)
          else
          end
          session["prompt-animating?"] = false
          if (startup_live_3f() and session["prompt-floating?"] and prompt_window_mod and prompt_window_mod["handoff-to-split!"]) then
            local split = prompt_window_mod["handoff-to-split!"](vim, session["prompt-window"], {["origin-win"] = session["origin-win"], ["window-local-layout"] = session["window-local-layout"], height = math.max(1, (session["prompt-target-height"] or 1))})
            session["prompt-window"] = split
            session["prompt-win"] = split.window
            session["prompt-floating?"] = false
            pcall(session.meta.refresh_statusline)
          else
          end
          if (preview_window and preview_window["update!"]) then
            pcall(preview_window["update!"], session)
          else
          end
          pcall(update_info_window, session)
          restore_main_view_21()
          local function _47_()
            return restore_main_view_21()
          end
          vim.schedule(_47_)
          if (startup_live_3f() and not vim.g.meta_test_no_startinsert) then
            return pcall(vim.api.nvim_set_current_win, session["prompt-win"])
          else
            return nil
          end
        end
        local target_height = math.max(1, (session["prompt-target-height"] or 1))
        local duration = prompt_enter_duration_ms()
        if session["prompt-floating?"] then
          return animation_mod["animate-float!"](session, "prompt-enter", prompt_win, prompt_float_config(1), prompt_float_config(target_height), 0, 0, duration, {["done!"] = done_21, kind = "prompt"})
        else
          return animation_mod["animate-win-height-stepwise!"](session, "prompt-enter", prompt_win, 1, target_height, duration, {["done!"] = done_21})
        end
      else
        return nil
      end
    end
    vim.schedule(_43_)
  else
  end
  schedule_layout_refresh_21()
  local function _52_()
    if (startup_live_3f() and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
      do
        local row = math.max(1, #initial_lines)
        local line = (initial_lines[row] or "")
        local col = #line
        pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, col})
      end
      if not vim.g.meta_test_no_startinsert then
        pcall(vim.api.nvim_set_current_win, session["prompt-win"])
        pcall(vim.cmd, "startinsert!")
      else
      end
    else
    end
    if not session["prompt-animated?"] then
      return restore_main_view_21()
    else
      return nil
    end
  end
  return vim.defer_fn(_52_, prompt_enter_duration_ms())
end
local function finish_session_startup_21(deps, curr, session, initial_query_active)
  local project_source = deps["project-source"]
  local sign_mod = deps["sign-mod"]
  local session_view = deps["session-view"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local update_preview_window = deps["update-preview-window"]
  local update_info_window = deps["update-info-window"]
  local context_window = deps.windows.context
  local active_by_prompt = deps.router["active-by-prompt"]
  local instances = deps.router.instances
  local startup_layout_unsettled_3f = clj.boolean(session["prompt-animating?"])
  local function startup_live_3f()
    return ((active_by_prompt[session["prompt-buf"]] == session) and not session["ui-hidden"] and not session.closing)
  end
  local function schedule_aux_ui_refresh_21()
    local function _56_()
      if startup_live_3f() then
        pcall(curr.refresh_statusline)
        if update_preview_window then
          pcall(update_preview_window, session)
        else
        end
        pcall(update_info_window, session, true)
        if (context_window and context_window["update!"]) then
          return pcall(context_window["update!"], session)
        else
          return nil
        end
      else
        return nil
      end
    end
    return vim.schedule(_56_)
  end
  local function schedule_single_file_info_phases_21()
    if not session["project-mode"] then
      local function _60_()
        if startup_live_3f() then
          session["single-file-info-fetch-ready"] = true
          session["single-file-info-ready"] = true
          return pcall(update_info_window, session, true)
        else
          return nil
        end
      end
      return vim.defer_fn(_60_, (session["startup-ui-delay-ms"] or 320))
    else
      return nil
    end
  end
  local _63_
  if session["project-mode"] then
    _63_ = "finish-session-startup!/apply-minimal-source-set"
  else
    _63_ = "finish-session-startup!/apply-source-set"
  end
  local function _65_()
    if session["project-mode"] then
      return project_source["apply-minimal-source-set!"](session)
    else
      return project_source["apply-source-set!"](session)
    end
  end
  run_step_21(_63_, _65_)
  curr["status-win"] = curr.win
  local function _67_()
    return events.send("on-win-create!", {win = curr.win.window, role = "main"})
  end
  run_step_21("finish-session-startup!/disable-airline", _67_)
  local function _68_()
    return pcall(curr.refresh_statusline)
  end
  run_step_21("finish-session-startup!/refresh-statusline", _68_)
  local function _69_()
    return curr["on-init"]()
  end
  run_step_21("finish-session-startup!/on-init", _69_)
  if sign_mod then
    local function _70_()
      return pcall(sign_mod["capture-baseline!"], session)
    end
    run_step_21("finish-session-startup!/capture-sign-baseline", _70_)
  else
  end
  if (session["project-mode"] and not startup_layout_unsettled_3f) then
    local function _72_()
      return session_view["restore-meta-view!"](curr, session["source-view"], session, update_info_window)
    end
    run_step_21("finish-session-startup!/restore-meta-view-project", _72_)
  else
  end
  if not (session["project-mode"] and not initial_query_active) then
    local function _74_()
      return apply_prompt_lines(session)
    end
    run_step_21("finish-session-startup!/apply-prompt-lines", _74_)
  else
  end
  if (not session["project-mode"] and not startup_layout_unsettled_3f) then
    local function _76_()
      return session_view["restore-meta-view!"](curr, session["source-view"], session, update_info_window)
    end
    run_step_21("finish-session-startup!/restore-meta-view-regular", _76_)
  else
  end
  if (update_preview_window and not startup_layout_unsettled_3f) then
    local function _78_()
      return pcall(update_preview_window, session)
    end
    run_step_21("finish-session-startup!/update-preview-window", _78_)
  else
  end
  local function _80_()
    return pcall(update_info_window, session, true)
  end
  run_step_21("finish-session-startup!/update-info-window", _80_)
  if session["project-mode"] then
    local function _81_()
      if startup_live_3f() then
        return pcall(update_info_window, session, true)
      else
        return nil
      end
    end
    vim.defer_fn(_81_, (session["startup-ui-delay-ms"] or 350))
  else
  end
  schedule_single_file_info_phases_21()
  local function _84_()
    if startup_live_3f() then
      session["startup-initializing"] = false
      if not session["project-mode"] then
        session["project-mode-starting?"] = false
      else
      end
      pcall(update_info_window, session)
      local function _86_()
        if startup_live_3f() then
          session["animate-enter?"] = false
          restore_startup_cursor_21(session)
          if (session["project-mode"] and session.meta and session.meta.buf and session["lazy-stream-done"]) then
            session.meta.buf["visible-source-syntax-only"] = false
            return pcall(session.meta.buf["apply-source-syntax-regions"])
          else
            return nil
          end
        else
          return nil
        end
      end
      vim.defer_fn(_86_, (session["startup-ui-delay-ms"] or 320))
      if (session["project-mode"] and not session["project-bootstrapped"]) then
        return project_source["schedule-project-bootstrap!"](session, 17)
      else
        return nil
      end
    else
      return restore_startup_cursor_21(session)
    end
  end
  vim.schedule(_84_)
  if ((session["project-mode"] and not initial_query_active) or (context_window and context_window["update!"])) then
    schedule_aux_ui_refresh_21()
  else
  end
  instances[session["instance-id"]] = session
  return nil
end
M["start!"] = function(deps, query, mode, _meta, project_mode)
  local router = deps.router
  local mods = deps.mods
  local ui = deps.ui
  local ui_animation = ui.animation
  local ui_animation_prompt = ui_animation.prompt
  local ui_animation_preview = ui_animation.preview
  local ui_animation_info = ui_animation.info
  local ui_animation_loading = ui_animation.loading
  local ui_animation_scroll = ui_animation.scroll
  local history_api = deps["history-api"]
  local query_mod = deps["query-mod"]
  local remove_session_21 = deps["remove-session!"]
  local active_by_source = router["active-by-source"]
  local session_view = deps["session-view"]
  local meta_mod = mods.meta
  local router_util_mod = mods["router-util"]
  local prompt_window_mod = mods["prompt-window"]
  local history_store = deps["history-store"]
  local read_file_lines_cached = deps["read-file-lines-cached"]
  local settings = router
  local next_instance_id_21 = deps["next-instance-id!"]
  local launching_by_source = router["launching-by-source"]
  local maybe_restore_hidden_ui_21 = deps["maybe-restore-hidden-ui!"]
  local current_buf = vim.api.nvim_get_current_buf()
  local current_session = current_session_for_buffer(router, current_buf)
  if (current_session and existing_visible_meta(current_session)) then
    return existing_visible_meta(current_session)
  else
    local start_query = (query or "")
    local latest_history = history_api["history-latest"](nil)
    local expanded_query
    if (start_query == "!!") then
      expanded_query = latest_history
    elseif (start_query == "!$") then
      expanded_query = history_api["history-entry-token"](latest_history)
    elseif (start_query == "!^!") then
      expanded_query = history_api["history-entry-tail"](latest_history)
    else
      expanded_query = start_query
    end
    local parsed_query = query_mod["apply-default-source"](query_mod["parse-query-text"](expanded_query), query_mod["truthy?"](settings["default-include-lgrep"]))
    local query0 = parsed_query.query
    local prompt_query
    if (parsed_query["include-files"] ~= nil) then
      prompt_query = expanded_query
    else
      prompt_query = query0
    end
    local prompt_query0
    if ((type(prompt_query) == "string") and (prompt_query ~= "") and not vim.endswith(prompt_query, " ") and not vim.endswith(prompt_query, "\n")) then
      prompt_query0 = (prompt_query .. " ")
    else
      prompt_query0 = prompt_query
    end
    local start_hidden
    do
      local val_113_auto = parsed_query["include-hidden"]
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_hidden = v
      else
        start_hidden = query_mod["truthy?"](settings["default-include-hidden"])
      end
    end
    local start_ignored
    do
      local val_113_auto = parsed_query["include-ignored"]
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_ignored = v
      else
        start_ignored = query_mod["truthy?"](settings["default-include-ignored"])
      end
    end
    local start_deps
    do
      local val_113_auto = parsed_query["include-deps"]
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_deps = v
      else
        start_deps = query_mod["truthy?"](settings["default-include-deps"])
      end
    end
    local start_binary
    do
      local val_113_auto = parsed_query["include-binary"]
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_binary = v
      else
        start_binary = query_mod["truthy?"](settings["default-include-binary"])
      end
    end
    local start_files
    do
      local val_113_auto = parsed_query["include-files"]
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_files = v
      else
        start_files = query_mod["truthy?"](settings["default-include-files"])
      end
    end
    local start_prefilter
    do
      local val_113_auto = parsed_query.prefilter
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_prefilter = v
      else
        start_prefilter = query_mod["truthy?"](settings["project-lazy-prefilter-enabled"])
      end
    end
    local start_lazy
    do
      local val_113_auto = parsed_query.lazy
      if (nil ~= val_113_auto) then
        local v = val_113_auto
        start_lazy = v
      else
        start_lazy = query_mod["truthy?"](settings["project-lazy-enabled"])
      end
    end
    local start_expansion = (parsed_query.expansion or "none")
    local start_transforms = transform_mod["enabled-map"](parsed_query, nil, settings)
    local query1 = query0
    local source_buf = vim.api.nvim_get_current_buf()
    local existing = active_by_source[source_buf]
    if (launching_by_source[source_buf] and existing and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode))) then
      return (existing or existing_visible_meta(existing))
    else
      if (existing and existing["ui-hidden"] and maybe_restore_hidden_ui_21 and existing.meta and existing.meta.buf and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode)) and (source_buf == existing.meta.buf.buffer)) then
        maybe_restore_hidden_ui_21(existing, true)
        return existing.meta
      else
        launching_by_source[source_buf] = true
        if (existing and not existing["ui-hidden"]) then
          remove_session_21(existing)
        else
        end
        local origin_win = vim.api.nvim_get_current_win()
        local origin_buf = source_buf
        local source_view = vim.fn.winsaveview()
        local _
        source_view["_meta_win_height"] = vim.api.nvim_win_get_height(origin_win)
        _ = nil
        local condition = session_view["setup-state"](query1, mode, source_view)
        local _0
        condition["selected-index"] = project_start_selected_index(project_mode, mode, source_view, condition)
        _0 = nil
        local curr = meta_mod.new(vim, condition)
        curr["project-mode"] = (project_mode or false)
        router_util_mod["ensure-source-refs!"](curr)
        curr.buf["keep-modifiable"] = true
        local fast_test_startup_3f = clj.boolean(vim.g.meta_test_running)
        do
          local bo = vim.bo[curr.buf.buffer]
          bo["buftype"] = "acwrite"
          bo["modifiable"] = true
          bo["readonly"] = false
          bo["bufhidden"] = "hide"
        end
        pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, "meta_manual_edit_active", false)
        pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, "meta_internal_render", false)
        pcall(curr.buf.render)
        local initial_lines
        if (prompt_query0 and (prompt_query0 ~= "")) then
          initial_lines = vim.split(prompt_query0, "\n", {plain = true})
        else
          initial_lines = {""}
        end
        local prompt_animates_3f = (not fast_test_startup_3f and ui_animation.enabled and not (false == ui_animation_prompt.enabled))
        local animation_settings = {enabled = (not fast_test_startup_3f and not (false == ui_animation.enabled)), backend = (ui_animation.backend or "native"), ["time-scale"] = (ui_animation["time-scale"] or 1), prompt = {enabled = not (false == ui_animation_prompt.enabled), ms = ui_animation_prompt.ms, ["time-scale"] = (ui_animation_prompt["time-scale"] or 1), backend = (ui_animation_prompt.backend or "native")}, preview = {enabled = not (false == ui_animation_preview.enabled), ms = ui_animation_preview.ms, ["time-scale"] = (ui_animation_preview["time-scale"] or 1)}, info = {enabled = not (false == ui_animation_info.enabled), ms = ui_animation_info.ms, ["time-scale"] = (ui_animation_info["time-scale"] or 1), backend = (ui_animation_info.backend or "native")}, loading = {enabled = not (false == ui_animation_loading.enabled), ms = ui_animation_loading.ms, ["time-scale"] = (ui_animation_loading["time-scale"] or 1)}, scroll = {enabled = not (false == ui_animation_scroll.enabled), ms = ui_animation_scroll.ms, ["time-scale"] = (ui_animation_scroll["time-scale"] or 1), backend = (ui_animation_scroll.backend or "native")}}
        local prompt_win
        local _104_
        if prompt_animates_3f then
          _104_ = 1
        else
          _104_ = router_util_mod["prompt-height"]()
        end
        prompt_win = prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"](), ["start-height"] = _104_, ["floating?"] = prompt_animates_3f, ["window-local-layout"] = settings["window-local-layout"], ["origin-win"] = origin_win})
        local prompt_buf = prompt_win.buffer
        local session
        local _106_
        if query_mod["query-lines-has-active?"](parsed_query.lines) then
          _106_ = settings["project-bootstrap-delay-ms"]
        else
          _106_ = settings["project-bootstrap-idle-delay-ms"]
        end
        session = {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["prompt-window"] = prompt_win, ["prompt-win"] = prompt_win.window, ["prompt-target-height"] = router_util_mod["prompt-height"](), ["prompt-buf"] = prompt_buf, ["prompt-floating?"] = prompt_win["floating?"], ["window-local-layout"] = settings["window-local-layout"], ["prompt-keymaps"] = settings["prompt-keymaps"], ["main-keymaps"] = settings["main-keymaps"], ["prompt-fallback-keymaps"] = settings["prompt-fallback-keymaps"], ["info-file-entry-view"] = (settings["info-file-entry-view"] or "meta"), ["initial-prompt-text"] = table.concat(initial_lines, "\n"), ["last-prompt-text"] = table.concat(initial_lines, "\n"), ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = table.concat(initial_lines, "\n"), ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["animate-enter?"] = (not fast_test_startup_3f and clj.boolean(ui_animation.enabled)), ["startup-ui-delay-ms"] = startup_ui_delay_ms(clj.boolean(ui_animation.enabled), animation_settings), ["loading-indicator?"] = clj.boolean(ui["loading-indicator"]), ["animation-settings"] = animation_settings, ["project-mode"] = (project_mode or false), ["project-mode-starting?"] = clj.boolean(project_mode), ["read-file-lines-cached"] = read_file_lines_cached, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["default-include-lgrep"] = query_mod["truthy?"](settings["default-include-lgrep"]), ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["effective-include-binary"] = start_binary, ["effective-include-files"] = start_files, ["transform-flags"] = vim.deepcopy(start_transforms), ["effective-transforms"] = vim.deepcopy(start_transforms), ["active-source-key"] = source_mod["query-source-key"](parsed_query), ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _106_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["expansion-mode"] = start_expansion, ["project-source-syntax-chunk-lines"] = settings["project-source-syntax-chunk-lines"], ["last-parsed-query"] = vim.tbl_extend("force", {lines = (parsed_query.lines or {""}), ["lgrep-lines"] = (parsed_query["lgrep-lines"] or {}), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["file-lines"] = (parsed_query["file-lines"] or {}), prefilter = start_prefilter, lazy = start_lazy, expansion = start_expansion}, transform_mod["compat-view"](start_transforms)), ["file-query-lines"] = (parsed_query["file-lines"] or {}), ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), ["instance-id"] = next_instance_id_21(), meta = curr, ["project-bootstrap-pending"] = false, ["prompt-animating?"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
        transform_mod["apply-flags!"](session, start_transforms)
        transform_mod["apply-flags!"](curr, start_transforms)
        local start_wrap
        do
          local persisted = router_util_mod["results-wrap-enabled?"]()
          if (persisted ~= nil) then
            start_wrap = persisted
          else
            local ok,wrap_3f = pcall(vim.api.nvim_get_option_value, "wrap", {win = origin_win})
            start_wrap = (ok and clj.boolean(wrap_3f))
          end
        end
        if vim.api.nvim_win_is_valid(origin_win) then
          silent_win_set_buf_21(origin_win, curr.buf.buffer)
        else
        end
        if (curr.win and curr.win.window and vim.api.nvim_win_is_valid(curr.win.window)) then
          pcall(vim.api.nvim_set_option_value, "wrap", clj.boolean(start_wrap), {win = curr.win.window})
          pcall(vim.api.nvim_set_option_value, "linebreak", clj.boolean(start_wrap), {win = curr.win.window})
        else
        end
        if not project_mode then
          session_view["restore-meta-view!"](curr, source_view, session, nil)
        else
        end
        local initial_query_active = session["initial-query-active"]
        curr.session = session
        curr.buf.session = session
        activate_session_ui_21(deps, session, initial_lines)
        events.send("on-session-start!", {session = session})
        finish_session_startup_21(deps, curr, session, initial_query_active)
        launching_by_source[source_buf] = nil
        show_launch_message_21(session)
        return curr
      end
    end
  end
end
M["project-start-selected-index"] = project_start_selected_index
return M
