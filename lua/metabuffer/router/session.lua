-- [nfnl] fnl/metabuffer/router/session.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
local util = require("metabuffer.util")
local M = {}
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
    local function _3_()
      return vim.api.nvim_echo({{("Metabuffer \226\128\162 " .. launch_source_label(session) .. " \226\128\162 instance " .. tostring((session["instance-id"] or "?"))), "ModeMsg"}}, true, {})
    end
    return vim.schedule(_3_)
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
  return util["hide-global-cursor!"](session, "startup-cursor-hidden?", "startup-saved-guicursor")
end
local function restore_startup_cursor_21(session)
  return util["restore-global-cursor!"](session, "startup-cursor-hidden?", "startup-saved-guicursor")
end
local function current_session_for_buffer(router, buf)
  local or_9_ = router["active-by-source"][buf] or router["active-by-prompt"][buf]
  if not or_9_ then
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
    or_9_ = found
  end
  return or_9_
end
local function existing_visible_meta(session)
  return (session and not session["ui-hidden"] and not session.closing and session.meta)
end
local function build_refresh_hooks(deps)
  local windows = deps.windows
  local session_view = deps["session-view"]
  local update_preview_window = deps["update-preview-window"]
  local update_info_window = deps["update-info-window"]
  local refresh_source_syntax_21 = deps["refresh-source-syntax!"]
  local context_window = windows.context
  local preview_window = windows.preview
  local info_window = windows.info
  local sign_mod = deps["sign-mod"]
  local function _13_(session)
    if (session and session.meta and session.meta.refresh_statusline) then
      pcall(session.meta.refresh_statusline)
    else
    end
    if (preview_window and preview_window["refresh-statusline!"]) then
      pcall(preview_window["refresh-statusline!"], session)
    else
    end
    if (info_window and info_window["refresh-statusline!"]) then
      return pcall(info_window["refresh-statusline!"], session)
    else
      return nil
    end
  end
  local function _17_(session)
    if update_preview_window then
      return pcall(update_preview_window, session)
    else
      return nil
    end
  end
  local function _19_(session)
    if (session and session.meta) then
      return pcall(session_view["restore-meta-view!"], session.meta, session["source-view"], session, nil)
    else
      return nil
    end
  end
  local function _21_(session, refresh_lines)
    if update_info_window then
      return pcall(update_info_window, session, refresh_lines)
    else
      return nil
    end
  end
  local function _23_(session)
    if (context_window and context_window["update!"]) then
      return pcall(context_window["update!"], session)
    else
      return nil
    end
  end
  local function _25_(session, immediate_3f)
    if refresh_source_syntax_21 then
      return pcall(refresh_source_syntax_21, session, immediate_3f)
    else
      return nil
    end
  end
  local function _27_(session)
    if (sign_mod and sign_mod["refresh-change-signs!"]) then
      return pcall(sign_mod["refresh-change-signs!"], session)
    else
      return nil
    end
  end
  local function _29_(session)
    if (sign_mod and sign_mod["capture-baseline!"]) then
      return pcall(sign_mod["capture-baseline!"], session)
    else
      return nil
    end
  end
  local function _31_(session)
    if (session and session["prompt-hooks"] and session["prompt-hooks"]["loading!"]) then
      return pcall(session["prompt-hooks"]["loading!"], session)
    else
      return nil
    end
  end
  return {["statusline!"] = _13_, ["preview!"] = _17_, ["restore-view!"] = _19_, ["info!"] = _21_, ["context!"] = _23_, ["source-syntax!"] = _25_, ["refresh-change-signs!"] = _27_, ["capture-sign-baseline!"] = _29_, ["loading!"] = _31_}
end
local function prompt_hook_opts(deps)
  local router = deps.router
  local project_source = deps["project-source"]
  local function _33_(s)
    if (project_source and project_source["apply-source-set!"]) then
      return project_source["apply-source-set!"](s)
    else
      return nil
    end
  end
  return {["default-prompt-keymaps"] = router["prompt-keymaps"], ["default-main-keymaps"] = router["main-keymaps"], ["active-by-prompt"] = router["active-by-prompt"], ["on-prompt-changed"] = deps["on-prompt-changed"], ["update-info-window"] = deps["update-info-window"], ["update-preview-window"] = deps["update-preview-window"], ["maybe-sync-from-main!"] = deps["maybe-sync-from-main!"], ["schedule-scroll-sync!"] = deps["schedule-scroll-sync!"], ["maybe-restore-hidden-ui!"] = deps["maybe-restore-hidden-ui!"], ["hide-visible-ui!"] = deps["hide-visible-ui!"], ["rebuild-source-set!"] = _33_, ["sign-mod"] = deps["sign-mod"]}
end
local function register_prompt_hooks_21(deps, session)
  local router = deps.router
  local prompt_hooks_mod = deps.mods["prompt-hooks"]
  local hooks = prompt_hooks_mod.new(prompt_hook_opts(deps))
  session["prompt-hooks"] = hooks
  return hooks["register!"](router, session)
end
local function session_startup_live_3f(active_by_prompt, prompt_buf, session)
  return ((active_by_prompt[prompt_buf] == session) and not session["ui-hidden"] and not session.closing)
end
local function restore_active_main_view_21(active_by_prompt, session)
  if (session_startup_live_3f(active_by_prompt, session["prompt-buf"], session) and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    return events.send("on-restore-view!", {session = session})
  else
    return nil
  end
end
local function prompt_enter_duration_ms(animation_mod, session, ui_animation_prompt_ms)
  if (animation_mod and animation_mod["enabled?"](session, "prompt")) then
    return animation_mod["duration-ms"](session, "prompt", (ui_animation_prompt_ms or 140))
  else
    return 0
  end
end
local function prompt_float_config(session, prompt_win, height)
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
local function maybe_ensure_preview_window_21(preview_window, session)
  if (preview_window and preview_window["ensure-window!"]) then
    local function _39_()
      return preview_window["ensure-window!"](session)
    end
    return run_step_21("activate-session-ui/ensure-preview-window", _39_)
  else
    return nil
  end
end
local function apply_initial_prompt_layout_21(session, prompt_win)
  if (prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
    local function _41_()
      if session["prompt-floating?"] then
        return pcall(vim.api.nvim_win_set_config, prompt_win, prompt_float_config(session, prompt_win, 1))
      else
        return pcall(vim.api.nvim_win_set_height, prompt_win, 1)
      end
    end
    return run_step_21("activate-session-ui/initial-prompt-layout", _41_)
  else
    return nil
  end
end
local function maybe_focus_prompt_after_start_21(startup_live_3f, session)
  if (startup_live_3f() and not vim.g.meta_test_no_startinsert) then
    return pcall(vim.api.nvim_set_current_win, session["prompt-win"])
  else
    return nil
  end
end
local function handoff_animated_prompt_21(startup_live_3f, session, prompt_window_mod)
  if (startup_live_3f() and session["prompt-floating?"] and prompt_window_mod and prompt_window_mod["handoff-to-split!"]) then
    local split = prompt_window_mod["handoff-to-split!"](vim, session["prompt-window"], {["origin-win"] = session["origin-win"], ["window-local-layout"] = session["window-local-layout"], height = math.max(1, (session["prompt-target-height"] or 1))})
    session["prompt-window"] = split
    session["prompt-win"] = split.window
    session["prompt-floating?"] = false
    return nil
  else
    return nil
  end
end
local function finish_prompt_enter_animation_21(active_by_prompt, session, prompt_window_mod)
  if not session_startup_live_3f(active_by_prompt, session["prompt-buf"], session) then
    restore_startup_cursor_21(session)
  else
  end
  session["prompt-animating?"] = false
  local function _47_()
    return session_startup_live_3f(active_by_prompt, session["prompt-buf"], session)
  end
  handoff_animated_prompt_21(_47_, session, prompt_window_mod)
  restore_active_main_view_21(active_by_prompt, session)
  events.send("on-session-ready!", {session = session, ["refresh-lines"] = true})
  local function _48_()
    return restore_active_main_view_21(active_by_prompt, session)
  end
  vim.schedule(_48_)
  local function _49_()
    return session_startup_live_3f(active_by_prompt, session["prompt-buf"], session)
  end
  return maybe_focus_prompt_after_start_21(_49_, session)
end
local function maybe_animate_prompt_enter_21(deps, session, prompt_win)
  local active_by_prompt = deps.router["active-by-prompt"]
  local animation_mod = deps.mods.animation
  local prompt_window_mod = deps.mods["prompt-window"]
  local ui_animation_prompt_ms = deps.ui.animation.prompt.ms
  if (session["animate-enter?"] and animation_mod and prompt_win and vim.api.nvim_win_is_valid(prompt_win) and animation_mod["enabled?"](session, "prompt") and session["prompt-animating?"]) then
    local function _50_()
      if (session_startup_live_3f(active_by_prompt, session["prompt-buf"], session) and session["prompt-animating?"] and prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
        local target_height = math.max(1, (session["prompt-target-height"] or 1))
        local duration = prompt_enter_duration_ms(animation_mod, session, ui_animation_prompt_ms)
        local done_21
        local function _51_(_)
          return finish_prompt_enter_animation_21(active_by_prompt, session, prompt_window_mod)
        end
        done_21 = _51_
        if session["prompt-floating?"] then
          return animation_mod["animate-float!"](session, "prompt-enter", prompt_win, prompt_float_config(session, prompt_win, 1), prompt_float_config(session, prompt_win, target_height), 0, 0, duration, {["done!"] = done_21, kind = "prompt"})
        else
          return animation_mod["animate-win-height-stepwise!"](session, "prompt-enter", prompt_win, 1, target_height, duration, {["done!"] = done_21})
        end
      else
        return nil
      end
    end
    return vim.schedule(_50_)
  else
    return nil
  end
end
local function schedule_initial_prompt_focus_21(deps, session, initial_lines)
  local active_by_prompt = deps.router["active-by-prompt"]
  local animation_mod = deps.mods.animation
  local ui_animation_prompt_ms = deps.ui.animation.prompt.ms
  local function _55_()
    if (session_startup_live_3f(active_by_prompt, session["prompt-buf"], session) and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
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
      return restore_active_main_view_21(active_by_prompt, session)
    else
      return nil
    end
  end
  return vim.defer_fn(_55_, prompt_enter_duration_ms(animation_mod, session, ui_animation_prompt_ms))
end
local function activate_session_ui_21(deps, session, initial_lines)
  local router = deps.router
  local mods = deps.mods
  local active_by_source = router["active-by-source"]
  local active_by_prompt = router["active-by-prompt"]
  local animation_mod = mods.animation
  local preview_window = deps.windows.preview
  local sync_prompt_buffer_name_21 = deps["sync-prompt-buffer-name!"]
  local prompt_buf = session["prompt-buf"]
  local prompt_win = session["prompt-win"]
  local function _59_()
    return sync_prompt_buffer_name_21(session)
  end
  run_step_21("activate-session-ui/sync-prompt-buffer-name", _59_)
  local function _60_()
    return hide_startup_cursor_21(session)
  end
  run_step_21("activate-session-ui/hide-startup-cursor", _60_)
  local function _61_()
    return vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, initial_lines)
  end
  run_step_21("activate-session-ui/set-prompt-lines", _61_)
  local function _62_()
    return register_prompt_hooks_21(deps, session)
  end
  run_step_21("activate-session-ui/register-prompt-hooks", _62_)
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
  maybe_ensure_preview_window_21(preview_window, session)
  apply_initial_prompt_layout_21(session, prompt_win)
  maybe_animate_prompt_enter_21(deps, session, prompt_win)
  return schedule_initial_prompt_focus_21(deps, session, initial_lines)
end
local function emit_session_ready_21(session, refresh_lines, restore_view_3f, capture_sign_baseline_3f)
  return events.send("on-session-ready!", {session = session, ["refresh-lines"] = refresh_lines, ["restore-view?"] = restore_view_3f, ["capture-sign-baseline?"] = capture_sign_baseline_3f})
end
local function maybe_apply_start_query_21(apply_prompt_lines, session, initial_query_active)
  if not (session["project-mode"] and not initial_query_active) then
    local function _65_()
      return apply_prompt_lines(session)
    end
    return run_step_21("finish-session-startup!/apply-prompt-lines", _65_)
  else
    return nil
  end
end
local function schedule_project_startup_refresh_21(session, startup_live_3f)
  if session["project-mode"] then
    local function _67_()
      if startup_live_3f() then
        return emit_session_ready_21(session, true, nil, nil)
      else
        return nil
      end
    end
    return vim.defer_fn(_67_, (session["startup-ui-delay-ms"] or 350))
  else
    return nil
  end
end
local function schedule_startup_finalize_21(project_source, session, startup_live_3f)
  local function _70_()
    if startup_live_3f() then
      session["startup-initializing"] = false
      if not session["project-mode"] then
        session["project-mode-starting?"] = false
      else
      end
      emit_session_ready_21(session, false, nil, nil)
      local function _72_()
        if startup_live_3f() then
          session["animate-enter?"] = false
          restore_startup_cursor_21(session)
          if (session["project-mode"] and session.meta and session.meta.buf and session["lazy-stream-done"]) then
            session.meta.buf["visible-source-syntax-only"] = false
            return events.send("on-source-syntax-refresh!", {session = session, ["immediate?"] = true})
          else
            return nil
          end
        else
          return nil
        end
      end
      vim.defer_fn(_72_, (session["startup-ui-delay-ms"] or 320))
      if (session["project-mode"] and not session["project-bootstrapped"]) then
        project_source["schedule-project-bootstrap!"](session, 17)
      else
      end
    else
    end
    if not startup_live_3f() then
      return restore_startup_cursor_21(session)
    else
      return nil
    end
  end
  return vim.schedule(_70_)
end
local function finish_session_startup_21(deps, curr, session, initial_query_active)
  local project_source = deps["project-source"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local active_by_prompt = deps.router["active-by-prompt"]
  local instances = deps.router.instances
  local startup_layout_unsettled_3f = clj.boolean(session["prompt-animating?"])
  local function startup_live_3f()
    return ((active_by_prompt[session["prompt-buf"]] == session) and not session["ui-hidden"] and not session.closing)
  end
  local function schedule_single_file_info_phases_21()
    if not session["project-mode"] then
      local function _78_()
        if startup_live_3f() then
          session["single-file-info-fetch-ready"] = true
          session["single-file-info-ready"] = true
          return events.send("on-session-ready!", {session = session, ["refresh-lines"] = true})
        else
          return nil
        end
      end
      return vim.defer_fn(_78_, (session["startup-ui-delay-ms"] or 320))
    else
      return nil
    end
  end
  local _81_
  if session["project-mode"] then
    _81_ = "finish-session-startup!/apply-minimal-source-set"
  else
    _81_ = "finish-session-startup!/apply-source-set"
  end
  local function _83_()
    if session["project-mode"] then
      return project_source["apply-minimal-source-set!"](session)
    else
      return project_source["apply-source-set!"](session)
    end
  end
  run_step_21(_81_, _83_)
  curr["status-win"] = curr.win
  local function _85_()
    return events.send("on-win-create!", {win = curr.win.window, role = "main"})
  end
  run_step_21("finish-session-startup!/disable-airline", _85_)
  local function _86_()
    return curr["on-init"]()
  end
  run_step_21("finish-session-startup!/on-init", _86_)
  maybe_apply_start_query_21(apply_prompt_lines, session, initial_query_active)
  local function _87_()
    return emit_session_ready_21(session, true, not startup_layout_unsettled_3f, true)
  end
  run_step_21("finish-session-startup!/emit-session-ready", _87_)
  schedule_project_startup_refresh_21(session, startup_live_3f)
  schedule_single_file_info_phases_21()
  schedule_startup_finalize_21(project_source, session, startup_live_3f)
  instances[session["instance-id"]] = session
  return nil
end
local function expand_history_query(history_api, start_query)
  local latest_history = history_api["history-latest"](nil)
  if (start_query == "!!") then
    return latest_history
  elseif (start_query == "!$") then
    return history_api["history-entry-token"](latest_history)
  elseif (start_query == "!^!") then
    return history_api["history-entry-tail"](latest_history)
  else
    return start_query
  end
end
local function start_option_value(parsed_query, query_mod, settings, parsed_key, settings_key)
  local val_113_auto = parsed_query[parsed_key]
  if (nil ~= val_113_auto) then
    local v = val_113_auto
    return v
  else
    return query_mod["truthy?"](settings[settings_key])
  end
end
local function prompt_query_text(parsed_query, expanded_query)
  local query0 = parsed_query.query
  local prompt_query0
  if (parsed_query["include-files"] ~= nil) then
    prompt_query0 = expanded_query
  else
    prompt_query0 = query0
  end
  local _91_
  if ((type(prompt_query0) == "string") and (prompt_query0 ~= "") and not vim.endswith(prompt_query0, " ") and not vim.endswith(prompt_query0, "\n")) then
    _91_ = (prompt_query0 .. " ")
  else
    _91_ = prompt_query0
  end
  return {query = query0, ["prompt-query"] = _91_}
end
local function resolve_start_query_state(query, history_api, query_mod, settings)
  local start_query = (query or "")
  local expanded_query = expand_history_query(history_api, start_query)
  local parsed_query = query_mod["apply-default-source"](query_mod["parse-query-text"](expanded_query), query_mod["truthy?"](settings["default-include-lgrep"]))
  local _let_93_ = prompt_query_text(parsed_query, expanded_query)
  local query0 = _let_93_.query
  local prompt_query = _let_93_["prompt-query"]
  local start_transforms = transform_mod["enabled-map"](parsed_query, nil, settings)
  return {["parsed-query"] = parsed_query, query = query0, ["prompt-query"] = prompt_query, ["start-hidden"] = start_option_value(parsed_query, query_mod, settings, "include-hidden", "default-include-hidden"), ["start-ignored"] = start_option_value(parsed_query, query_mod, settings, "include-ignored", "default-include-ignored"), ["start-deps"] = start_option_value(parsed_query, query_mod, settings, "include-deps", "default-include-deps"), ["start-binary"] = start_option_value(parsed_query, query_mod, settings, "include-binary", "default-include-binary"), ["start-files"] = start_option_value(parsed_query, query_mod, settings, "include-files", "default-include-files"), ["start-prefilter"] = start_option_value(parsed_query, query_mod, settings, "prefilter", "project-lazy-prefilter-enabled"), ["start-lazy"] = start_option_value(parsed_query, query_mod, settings, "lazy", "project-lazy-enabled"), ["start-expansion"] = (parsed_query.expansion or "none"), ["start-transforms"] = start_transforms}
end
local function build_animation_settings(ui_animation, ui_animation_prompt, ui_animation_preview, ui_animation_info, ui_animation_loading, ui_animation_scroll, fast_test_startup_3f)
  return {enabled = (not fast_test_startup_3f and not (false == ui_animation.enabled)), backend = (ui_animation.backend or "native"), ["time-scale"] = (ui_animation["time-scale"] or 1), prompt = {enabled = not (false == ui_animation_prompt.enabled), ms = ui_animation_prompt.ms, ["time-scale"] = (ui_animation_prompt["time-scale"] or 1), backend = (ui_animation_prompt.backend or "native")}, preview = {enabled = not (false == ui_animation_preview.enabled), ms = ui_animation_preview.ms, ["time-scale"] = (ui_animation_preview["time-scale"] or 1)}, info = {enabled = not (false == ui_animation_info.enabled), ms = ui_animation_info.ms, ["time-scale"] = (ui_animation_info["time-scale"] or 1), backend = (ui_animation_info.backend or "native")}, loading = {enabled = not (false == ui_animation_loading.enabled), ms = ui_animation_loading.ms, ["time-scale"] = (ui_animation_loading["time-scale"] or 1)}, scroll = {enabled = not (false == ui_animation_scroll.enabled), ms = ui_animation_scroll.ms, ["time-scale"] = (ui_animation_scroll["time-scale"] or 1), backend = (ui_animation_scroll.backend or "native")}}
end
local function prompt_animates_3f(ui_animation, ui_animation_prompt, fast_test_startup_3f)
  return (not fast_test_startup_3f and ui_animation.enabled and not (false == ui_animation_prompt.enabled))
end
local function prompt_start_height(router_util_mod, prompt_animates_3f0)
  if prompt_animates_3f0 then
    return 1
  else
    return router_util_mod["prompt-height"]()
  end
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
    local _let_95_ = resolve_start_query_state(query, history_api, query_mod, settings)
    local parsed_query = _let_95_["parsed-query"]
    local query0 = _let_95_.query
    local prompt_query = _let_95_["prompt-query"]
    local start_hidden = _let_95_["start-hidden"]
    local start_ignored = _let_95_["start-ignored"]
    local start_deps = _let_95_["start-deps"]
    local start_binary = _let_95_["start-binary"]
    local start_files = _let_95_["start-files"]
    local start_prefilter = _let_95_["start-prefilter"]
    local start_lazy = _let_95_["start-lazy"]
    local start_expansion = _let_95_["start-expansion"]
    local start_transforms = _let_95_["start-transforms"]
    local source_buf = vim.api.nvim_get_current_buf()
    local existing = active_by_source[source_buf]
    if (launching_by_source[source_buf] and existing and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode))) then
      return (existing or existing_visible_meta(existing))
    else
      if (existing and existing["ui-hidden"] and maybe_restore_hidden_ui_21 and existing.meta and existing.meta.buf and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode)) and (source_buf == existing.meta.buf.buffer)) then
        router_util_mod["clear-file-caches!"](router, existing)
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
        local condition = session_view["setup-state"](query0, mode, source_view)
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
        if (prompt_query and (prompt_query ~= "")) then
          initial_lines = vim.split(prompt_query, "\n", {plain = true})
        else
          initial_lines = {""}
        end
        local prompt_animates_3f0 = prompt_animates_3f(ui_animation, ui_animation_prompt, fast_test_startup_3f)
        local animation_settings = build_animation_settings(ui_animation, ui_animation_prompt, ui_animation_preview, ui_animation_info, ui_animation_loading, ui_animation_scroll, fast_test_startup_3f)
        local prompt_win = prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"](), ["start-height"] = prompt_start_height(router_util_mod, prompt_animates_3f0), ["floating?"] = prompt_animates_3f0, ["window-local-layout"] = settings["window-local-layout"], ["origin-win"] = origin_win})
        local prompt_buf = prompt_win.buffer
        local session
        local _98_
        if query_mod["query-lines-has-active?"](parsed_query.lines) then
          _98_ = settings["project-bootstrap-delay-ms"]
        else
          _98_ = settings["project-bootstrap-idle-delay-ms"]
        end
        session = {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["prompt-window"] = prompt_win, ["prompt-win"] = prompt_win.window, ["prompt-target-height"] = router_util_mod["prompt-height"](), ["prompt-buf"] = prompt_buf, ["prompt-floating?"] = prompt_win["floating?"], ["window-local-layout"] = settings["window-local-layout"], ["prompt-keymaps"] = settings["prompt-keymaps"], ["main-keymaps"] = settings["main-keymaps"], ["prompt-fallback-keymaps"] = settings["prompt-fallback-keymaps"], ["info-file-entry-view"] = (settings["info-file-entry-view"] or "meta"), ["initial-prompt-text"] = table.concat(initial_lines, "\n"), ["last-prompt-text"] = table.concat(initial_lines, "\n"), ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = table.concat(initial_lines, "\n"), ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["animate-enter?"] = (not fast_test_startup_3f and clj.boolean(ui_animation.enabled)), ["startup-ui-delay-ms"] = startup_ui_delay_ms(clj.boolean(ui_animation.enabled), animation_settings), ["loading-indicator?"] = clj.boolean(ui["loading-indicator"]), ["animation-settings"] = animation_settings, ["project-mode"] = (project_mode or false), ["project-mode-starting?"] = clj.boolean(project_mode), ["read-file-lines-cached"] = read_file_lines_cached, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["default-include-lgrep"] = query_mod["truthy?"](settings["default-include-lgrep"]), ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["effective-include-binary"] = start_binary, ["effective-include-files"] = start_files, ["transform-flags"] = vim.deepcopy(start_transforms), ["effective-transforms"] = vim.deepcopy(start_transforms), ["active-source-key"] = source_mod["query-source-key"](parsed_query), ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _98_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["expansion-mode"] = start_expansion, ["project-source-syntax-chunk-lines"] = settings["project-source-syntax-chunk-lines"], ["project-lazy-refresh-min-ms"] = settings["project-lazy-refresh-min-ms"], ["project-lazy-refresh-debounce-ms"] = settings["project-lazy-refresh-debounce-ms"], ["last-parsed-query"] = vim.tbl_extend("force", {lines = (parsed_query.lines or {""}), ["lgrep-lines"] = (parsed_query["lgrep-lines"] or {}), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["file-lines"] = (parsed_query["file-lines"] or {}), prefilter = start_prefilter, lazy = start_lazy, expansion = start_expansion}, transform_mod["compat-view"](start_transforms)), ["file-query-lines"] = (parsed_query["file-lines"] or {}), ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), ["instance-id"] = next_instance_id_21(), meta = curr, ["project-bootstrap-pending"] = false, ["prompt-animating?"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
        session["refresh-hooks"] = build_refresh_hooks(deps)
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
          router_util_mod["silent-win-set-buf!"](origin_win, curr.buf.buffer)
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
