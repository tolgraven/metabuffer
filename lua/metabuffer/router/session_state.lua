-- [nfnl] fnl/metabuffer/router/session_state.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local M = {}
M.new = function(opts)
  local _let_1_ = (opts or {})
  local history_api = _let_1_["history-api"]
  local history_store = _let_1_["history-store"]
  local query_mod = _let_1_["query-mod"]
  local router = _let_1_.router
  local router_util_mod = _let_1_["router-util-mod"]
  local session_view = _let_1_["session-view"]
  local prompt_window_mod = _let_1_["prompt-window-mod"]
  local function expand_history_query(start_query)
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
  local function start_option_value(parsed_query, settings, parsed_key, settings_key)
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
    local _5_
    if ((type(prompt_query0) == "string") and (prompt_query0 ~= "") and not vim.endswith(prompt_query0, " ") and not vim.endswith(prompt_query0, "\n")) then
      _5_ = (prompt_query0 .. " ")
    else
      _5_ = prompt_query0
    end
    return {query = query0, ["prompt-query"] = _5_}
  end
  local function resolve_start_query_state(query, settings)
    local start_query = (query or "")
    local expanded_query = expand_history_query(start_query)
    local parsed_query = query_mod["apply-default-source"](query_mod["parse-query-text"](expanded_query), query_mod["truthy?"](settings["default-include-lgrep"]))
    local _let_7_ = prompt_query_text(parsed_query, expanded_query)
    local query0 = _let_7_.query
    local prompt_query = _let_7_["prompt-query"]
    local start_transforms = transform_mod["enabled-map"](parsed_query, nil, settings)
    return {["parsed-query"] = parsed_query, query = query0, ["prompt-query"] = prompt_query, ["start-hidden"] = start_option_value(parsed_query, settings, "include-hidden", "default-include-hidden"), ["start-ignored"] = start_option_value(parsed_query, settings, "include-ignored", "default-include-ignored"), ["start-deps"] = start_option_value(parsed_query, settings, "include-deps", "default-include-deps"), ["start-binary"] = start_option_value(parsed_query, settings, "include-binary", "default-include-binary"), ["start-files"] = start_option_value(parsed_query, settings, "include-files", "default-include-files"), ["start-prefilter"] = start_option_value(parsed_query, settings, "prefilter", "project-lazy-prefilter-enabled"), ["start-lazy"] = start_option_value(parsed_query, settings, "lazy", "project-lazy-enabled"), ["start-expansion"] = (parsed_query.expansion or "none"), ["start-transforms"] = start_transforms}
  end
  local function build_animation_settings(ui_animation, fast_test_startup_3f)
    local ui_animation_prompt = ui_animation.prompt
    local ui_animation_preview = ui_animation.preview
    local ui_animation_info = ui_animation.info
    local ui_animation_loading = ui_animation.loading
    local ui_animation_scroll = ui_animation.scroll
    return {enabled = (not fast_test_startup_3f and not (false == ui_animation.enabled)), backend = (ui_animation.backend or "native"), ["time-scale"] = (ui_animation["time-scale"] or 1), prompt = {enabled = not (false == ui_animation_prompt.enabled), ms = ui_animation_prompt.ms, ["time-scale"] = (ui_animation_prompt["time-scale"] or 1), backend = (ui_animation_prompt.backend or "native")}, preview = {enabled = not (false == ui_animation_preview.enabled), ms = ui_animation_preview.ms, ["time-scale"] = (ui_animation_preview["time-scale"] or 1)}, info = {enabled = not (false == ui_animation_info.enabled), ms = ui_animation_info.ms, ["time-scale"] = (ui_animation_info["time-scale"] or 1), backend = (ui_animation_info.backend or "native")}, loading = {enabled = not (false == ui_animation_loading.enabled), ms = ui_animation_loading.ms, ["time-scale"] = (ui_animation_loading["time-scale"] or 1)}, scroll = {enabled = not (false == ui_animation_scroll.enabled), ms = ui_animation_scroll.ms, ["time-scale"] = (ui_animation_scroll["time-scale"] or 1), backend = (ui_animation_scroll.backend or "native")}}
  end
  local function prompt_animates_3f(ui_animation, fast_test_startup_3f)
    return (not fast_test_startup_3f and ui_animation.enabled and not (false == ui_animation.prompt.enabled))
  end
  local function prompt_start_height(prompt_animates_3f0)
    if prompt_animates_3f0 then
      return 1
    else
      return router_util_mod["prompt-height"]()
    end
  end
  local function restored_hidden_session(router_state, maybe_restore_hidden_ui_21, source_buf, existing, project_mode)
    if (existing and existing["ui-hidden"] and maybe_restore_hidden_ui_21 and existing.meta and existing.meta.buf and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode)) and (source_buf == existing.meta.buf.buffer)) then
      router_util_mod["clear-file-caches!"](router_state, existing)
      maybe_restore_hidden_ui_21(existing, true)
      return existing.meta
    else
      return nil
    end
  end
  local function build_session_condition(query, mode, source_view, project_mode)
    local condition = session_view["setup-state"](query, mode, source_view)
    if (project_mode and (mode == "start")) then
      condition["selected-index"] = math.max(0, ((source_view.lnum or ((condition["selected-index"] or 0) + 1)) - 1))
    else
      condition["selected-index"] = (condition["selected-index"] or 0)
    end
    return condition
  end
  local function build_prompt_window(settings, origin_win, prompt_animates_3f0)
    return prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"](), ["start-height"] = prompt_start_height(prompt_animates_3f0), ["floating?"] = prompt_animates_3f0, ["window-local-layout"] = settings["window-local-layout"], ["origin-win"] = origin_win})
  end
  local function build_last_parsed_query(parsed_query, start_hidden, start_ignored, start_deps, start_binary, start_files, start_prefilter, start_lazy, start_expansion, start_transforms)
    return vim.tbl_extend("force", {lines = (parsed_query.lines or {""}), ["lgrep-lines"] = (parsed_query["lgrep-lines"] or {}), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["file-lines"] = (parsed_query["file-lines"] or {}), prefilter = start_prefilter, lazy = start_lazy, expansion = start_expansion}, transform_mod["compat-view"](start_transforms))
  end
  local function build_prompt_session_state(settings, prompt_win, prompt_buf, initial_lines, parsed_query, animation_settings, ui_animation, ui, fast_test_startup_3f)
    local prompt_text = table.concat(initial_lines, "\n")
    local _11_
    do
      local settings0 = (animation_settings or {})
      local global_enabled_3f = (ui_animation.enabled and not (false == settings0.enabled))
      local global_scale = (settings0["time-scale"] or 1)
      local prompt_settings = (settings0.prompt or {})
      local info_settings = (settings0.info or {})
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
      _11_ = math.max(prompt_ms, info_ms)
    end
    return {["prompt-window"] = prompt_win, ["prompt-win"] = prompt_win.window, ["prompt-target-height"] = router_util_mod["prompt-height"](), ["prompt-buf"] = prompt_buf, ["prompt-floating?"] = prompt_win["floating?"], ["window-local-layout"] = settings["window-local-layout"], ["prompt-keymaps"] = settings["prompt-keymaps"], ["main-keymaps"] = settings["main-keymaps"], ["prompt-fallback-keymaps"] = settings["prompt-fallback-keymaps"], ["info-file-entry-view"] = (settings["info-file-entry-view"] or "meta"), ["initial-prompt-text"] = prompt_text, ["last-prompt-text"] = prompt_text, ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = prompt_text, ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["animate-enter?"] = (not fast_test_startup_3f and clj.boolean(ui_animation.enabled)), ["startup-ui-delay-ms"] = _11_, ["loading-indicator?"] = clj.boolean(ui["loading-indicator"]), ["animation-settings"] = animation_settings, ["prompt-animating?"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
  end
  local function build_project_session_state(settings, parsed_query, project_mode, start_hidden, start_ignored, start_deps, start_binary, start_files, start_prefilter, start_lazy, start_expansion, start_transforms)
    local _14_
    if query_mod["query-lines-has-active?"](parsed_query.lines) then
      _14_ = settings["project-bootstrap-delay-ms"]
    else
      _14_ = settings["project-bootstrap-idle-delay-ms"]
    end
    return {["project-mode"] = (project_mode or false), ["project-mode-starting?"] = clj.boolean(project_mode), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-files"] = start_files, ["default-include-lgrep"] = query_mod["truthy?"](settings["default-include-lgrep"]), ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["effective-include-binary"] = start_binary, ["effective-include-files"] = start_files, ["transform-flags"] = vim.deepcopy(start_transforms), ["effective-transforms"] = vim.deepcopy(start_transforms), ["active-source-key"] = source_mod["query-source-key"](parsed_query), ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _14_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["expansion-mode"] = start_expansion, ["project-source-syntax-chunk-lines"] = settings["project-source-syntax-chunk-lines"], ["project-lazy-refresh-min-ms"] = settings["project-lazy-refresh-min-ms"], ["project-lazy-refresh-debounce-ms"] = settings["project-lazy-refresh-debounce-ms"], ["last-parsed-query"] = build_last_parsed_query(parsed_query, start_hidden, start_ignored, start_deps, start_binary, start_files, start_prefilter, start_lazy, start_expansion, start_transforms), ["file-query-lines"] = (parsed_query["file-lines"] or {}), ["project-bootstrap-pending"] = false}
  end
  local function build_session_state(deps, curr, source_buf, origin_win, origin_buf, source_view, condition, prompt_win, prompt_buf, initial_lines, parsed_query, project_mode, start_hidden, start_ignored, start_deps, start_binary, start_files, start_prefilter, start_lazy, start_expansion, start_transforms, fast_test_startup_3f)
    local ui = deps.ui
    local ui_animation = ui.animation
    local next_instance_id_21 = deps["next-instance-id!"]
    local animation_settings = build_animation_settings(ui_animation, fast_test_startup_3f)
    local settings = router
    return vim.tbl_extend("force", {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["read-file-lines-cached"] = deps["read-file-lines-cached"], ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), ["instance-id"] = next_instance_id_21(), meta = curr}, build_prompt_session_state(settings, prompt_win, prompt_buf, initial_lines, parsed_query, animation_settings, ui_animation, ui, fast_test_startup_3f), build_project_session_state(settings, parsed_query, project_mode, start_hidden, start_ignored, start_deps, start_binary, start_files, start_prefilter, start_lazy, start_expansion, start_transforms))
  end
  return {["resolve-start-query-state"] = resolve_start_query_state, ["prompt-animates?"] = prompt_animates_3f, ["restored-hidden-session"] = restored_hidden_session, ["build-session-condition"] = build_session_condition, ["build-prompt-window"] = build_prompt_window, ["build-session-state"] = build_session_state}
end
return M
