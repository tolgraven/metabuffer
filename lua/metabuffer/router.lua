-- [nfnl] fnl/metabuffer/router.fnl
local meta_mod = require("metabuffer.meta")
local prompt_window_mod = require("metabuffer.window.prompt")
local meta_window_mod = require("metabuffer.window.metawindow")
local floating_window_mod = require("metabuffer.window.floating")
local animation_mod = require("metabuffer.window.animation")
local preview_window_mod = require("metabuffer.window.preview")
local context_window_mod = require("metabuffer.window.context")
local info_window_mod = require("metabuffer.window.info")
local history_browser_window_mod = require("metabuffer.window.history_browser")
local project_source_mod = require("metabuffer.project.source")
local base_buffer = require("metabuffer.buffer.base")
local prompt_buffer_mod = require("metabuffer.buffer.prompt")
local session_view = require("metabuffer.session.view")
local debug = require("metabuffer.debug")
local config = require("metabuffer.config")
local query_mod = require("metabuffer.query")
local history_store = require("metabuffer.history_store")
local sign_mod = require("metabuffer.sign")
local prompt_hooks_mod = require("metabuffer.prompt.hooks")
local router_util_mod = require("metabuffer.router.util")
local router_history_mod = require("metabuffer.router.history")
local router_prompt_mod = require("metabuffer.router.prompt")
local router_query_flow_mod = require("metabuffer.router.query_flow")
local router_actions_mod = require("metabuffer.router.actions")
local router_navigation_mod = require("metabuffer.router.navigation")
local router_session_mod = require("metabuffer.router.session")
local M = {}
local function sync_prompt_buffer_name_21(session)
  return prompt_buffer_mod["sync-name!"](session)
end
M.instances = {}
M["_instance-seq"] = 0
M["active-by-source"] = {}
M["active-by-prompt"] = {}
M["launching-by-source"] = {}
local update_info_window = nil
local apply_prompt_lines = nil
local preview_window = nil
local context_window = nil
local info_window = nil
local history_browser_window = nil
local history_api = nil
local query_flow_deps = nil
local actions_deps = nil
local navigation_deps = nil
local session_deps = nil
M.configure = function(opts)
  return config["apply-router-defaults"](M, vim, opts)
end
M.configure(nil)
local function debug_log(msg)
  return debug.log("router", msg)
end
local prompt_scheduler_ctx
local function _1_(session)
  return apply_prompt_lines(session)
end
local function _2_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
prompt_scheduler_ctx = {["active-by-prompt"] = M["active-by-prompt"], ["apply-prompt-lines"] = _1_, ["prompt-update-delay-ms"] = _2_, ["now-ms"] = router_prompt_mod["now-ms"], ["cancel-prompt-update!"] = router_prompt_mod["cancel-prompt-update!"]}
local function _3_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _4_(path, opts)
  return router_util_mod["read-file-view-cached"](M, path, opts)
end
local function _5_(session)
  return (session and session["prompt-buf"] and (M["active-by-prompt"][session["prompt-buf"]] == session))
end
local function _6_(session)
  return (session and session["animate-enter?"])
end
preview_window = preview_window_mod.new({["floating-window-mod"] = floating_window_mod, ["selected-ref"] = router_util_mod["selected-ref"], ["read-file-lines-cached"] = _3_, ["read-file-view-cached"] = _4_, ["is-active-session"] = _5_, ["debug-log"] = debug_log, ["source-switch-debounce-ms"] = M["preview-source-switch-debounce-ms"], ["animation-mod"] = animation_mod, ["animate-enter?"] = _6_, ["preview-slide-ms"] = M["ui-animation-preview-ms"]})
do
  local candidate
  local function _7_(session)
    return (session and session["animate-enter?"])
  end
  local function _8_(path)
    return router_util_mod["read-file-lines-cached"](M, path)
  end
  local function _9_(path, opts)
    return router_util_mod["read-file-view-cached"](M, path, opts)
  end
  candidate = info_window_mod.new({["floating-window-mod"] = floating_window_mod, ["info-min-width"] = M["info-min-width"], ["info-max-width"] = M["info-max-width"], ["info-max-lines"] = M["info-max-lines"], ["info-height"] = router_util_mod["info-height"], ["debug-log"] = debug_log, ["animation-mod"] = animation_mod, ["animate-enter?"] = _7_, ["info-fade-ms"] = M["ui-animation-info-ms"], ["read-file-lines-cached"] = _8_, ["read-file-view-cached"] = _9_})
  if (type(candidate) == "function") then
    local function _10_(_)
      return nil
    end
    info_window = {["update!"] = candidate, ["close-window!"] = _10_}
  else
    info_window = candidate
  end
end
local update_preview_window
local function _12_(session)
  if (session and (type(preview_window) == "table") and preview_window["maybe-update-for-selection!"]) then
    return preview_window["maybe-update-for-selection!"](session)
  else
    return nil
  end
end
update_preview_window = _12_
history_browser_window = history_browser_window_mod.new({["floating-window-mod"] = floating_window_mod})
history_api = router_history_mod.new({["history-store"] = history_store, ["router-util-mod"] = router_util_mod, ["query-mod"] = query_mod, ["history-browser-window"] = history_browser_window, settings = M})
local function _14_(session, refresh_lines)
  if session then
    if session["ui-hidden"] then
      if ((type(info_window) == "table") and info_window["close-window!"]) then
        return info_window["close-window!"](session)
      else
        return nil
      end
    else
      if ((type(info_window) == "table") and info_window["update!"]) then
        return info_window["update!"](session, refresh_lines)
      else
        return nil
      end
    end
  else
    return nil
  end
end
update_info_window = _14_
local function _19_(path, opts)
  return router_util_mod["read-file-lines-cached"](M, path, opts)
end
local function _20_(path, opts)
  return router_util_mod["read-file-view-cached"](M, path, opts)
end
local function _21_(_session)
  return (M["context-height"] or 14)
end
context_window = context_window_mod.new({["read-file-lines-cached"] = _19_, ["read-file-view-cached"] = _20_, ["height-fn"] = _21_, ["around-lines"] = M["context-around-lines"], ["max-blocks"] = M["context-max-blocks"]})
local project_source
local function _22_(rel, include_hidden, include_deps)
  return router_util_mod["allow-project-path?"](M, rel, include_hidden, include_deps)
end
local function _23_(root, include_hidden, include_ignored, include_deps)
  return router_util_mod["project-file-list"](M, root, include_hidden, include_ignored, include_deps)
end
local function _24_(path)
  return router_util_mod["binary-file?"](M, path)
end
local function _25_(path, opts)
  return router_util_mod["read-file-lines-cached"](M, path, opts)
end
local function _26_(path, opts)
  return router_util_mod["read-file-view-cached"](M, path, opts)
end
local function _27_(session)
  return router_util_mod["session-active?"](M["active-by-prompt"], session)
end
local function _28_(session)
  return router_util_mod["lazy-streaming-allowed?"](M, query_mod, session)
end
local function _29_(prompt_buf, force)
  return M["on-prompt-changed"](prompt_buf, force)
end
local function _30_(session)
  return apply_prompt_lines(session)
end
local function _31_(session)
  return router_prompt_mod["prompt-has-active-query?"](query_mod, router_util_mod["prompt-lines"], session)
end
local function _32_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
local function _33_(session, wait_ms)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, wait_ms)
end
project_source = project_source_mod.new({settings = M, ["truthy?"] = query_mod["truthy?"], ["selected-ref"] = router_util_mod["selected-ref"], ["canonical-path"] = router_util_mod["canonical-path"], ["current-buffer-path"] = router_util_mod["current-buffer-path"], ["path-under-root?"] = router_util_mod["path-under-root?"], ["allow-project-path?"] = _22_, ["project-file-list"] = _23_, ["binary-file?"] = _24_, ["read-file-lines-cached"] = _25_, ["read-file-view-cached"] = _26_, ["session-active?"] = _27_, ["lazy-streaming-allowed?"] = _28_, ["on-prompt-changed"] = _29_, ["apply-prompt-lines-now!"] = _30_, ["prompt-has-active-query?"] = _31_, ["now-ms"] = router_prompt_mod["now-ms"], ["prompt-update-delay-ms"] = _32_, ["schedule-prompt-update!"] = _33_, ["restore-meta-view!"] = session_view["restore-meta-view!"], ["update-info-window"] = update_info_window})
local function _34_(session)
  return history_api["open-history-browser!"](session, "saved")
end
local function _35_(session)
  return apply_prompt_lines(session)
end
query_flow_deps = {router = M, mods = {query = query_mod}, project = {source = project_source}, windows = {context = context_window}, history = {["merge-into-session!"] = history_api["merge-history-into-session!"], ["save-current-prompt-tag!"] = history_api["save-current-prompt-tag!"], ["restore-saved-prompt-tag!"] = history_api["restore-saved-prompt-tag!"], ["open-saved-browser!"] = _34_}, refresh = {["preview!"] = update_preview_window, ["info!"] = update_info_window, ["change-signs!"] = sign_mod["refresh-change-signs!"], ["capture-sign-baseline!"] = sign_mod["capture-baseline!"]}, state = {["prompt-scheduler-ctx"] = prompt_scheduler_ctx}, ["apply-prompt-lines"] = _35_}
M._store_vars = function(meta)
  vim.b._meta_context = meta.store()
  vim.b._meta_indexes = meta.buf.indices
  vim.b._meta_updates = meta.updates
  vim.b._meta_source_bufnr = meta.buf.model
  return meta
end
M._wrapup = function(meta)
  vim.cmd("redraw|redrawstatus")
  return M._store_vars(meta)
end
local function remove_session(session)
  return router_actions_mod["remove-session!"](actions_deps, session)
end
local function _36_(session)
  return router_query_flow_mod["apply-prompt-lines!"](query_flow_deps, session)
end
apply_prompt_lines = _36_
actions_deps = {router = M, mods = {sign = sign_mod, ["prompt-window"] = prompt_window_mod, ["meta-window"] = meta_window_mod, ["router-util"] = router_util_mod, ["router-prompt"] = router_prompt_mod, ["session-view"] = session_view, ["base-buffer"] = base_buffer}, windows = {info = info_window, preview = preview_window, context = context_window}, history = {api = history_api, store = history_store}, project = {source = project_source}, refresh = {["preview!"] = update_preview_window, ["info!"] = update_info_window, ["sync-prompt-buffer-name!"] = sync_prompt_buffer_name_21, ["apply-prompt-lines!"] = apply_prompt_lines, wrapup = M._wrapup}}
local next_instance_id_21
local function _37_()
  M["_instance-seq"] = ((M["_instance-seq"] or 0) + 1)
  return M["_instance-seq"]
end
next_instance_id_21 = _37_
navigation_deps = {router = M, mods = {["session-view"] = session_view, animation = animation_mod}, windows = {context = context_window}, refresh = {["preview!"] = update_preview_window, ["info!"] = update_info_window}, timing = {["scroll-sync-debounce-ms"] = M["scroll-sync-debounce-ms"], ["source-syntax-refresh-debounce-ms"] = M["source-syntax-refresh-debounce-ms"]}}
M["on-prompt-changed"] = function(prompt_buf, force, event_tick)
  router_query_flow_mod["on-prompt-changed!"](query_flow_deps, prompt_buf, force, event_tick)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["history-browser-active"]) then
    return history_api["refresh-history-browser!"](session)
  else
    return nil
  end
end
M.accept = function(prompt_buf)
  return router_actions_mod["accept!"](actions_deps, prompt_buf)
end
M.cancel = function(prompt_buf)
  return router_actions_mod["cancel!"](actions_deps, prompt_buf)
end
M.finish = function(kind, prompt_buf)
  return router_actions_mod["finish!"](actions_deps, kind, prompt_buf)
end
M["move-selection"] = function(prompt_buf, delta)
  return router_navigation_mod["move-selection!"](navigation_deps, prompt_buf, delta)
end
M["scroll-main"] = function(prompt_buf, action)
  return router_navigation_mod["scroll-main!"](navigation_deps, prompt_buf, action)
end
local function maybe_sync_from_main_21(session, force_refresh)
  return router_navigation_mod["maybe-sync-from-main!"](navigation_deps, session, force_refresh)
end
local function schedule_scroll_sync_21(session)
  return router_navigation_mod["schedule-scroll-sync!"](navigation_deps, session)
end
local function refresh_source_syntax_21(session, immediate_3f)
  return router_navigation_mod["refresh-source-syntax!"](navigation_deps, session, immediate_3f)
end
M["history-or-move"] = function(prompt_buf, delta)
  return history_api["history-or-move"](prompt_buf, delta, M["active-by-prompt"], M["move-selection"])
end
M["last-prompt-entry"] = function(prompt_buf)
  return history_api["last-prompt-entry"](prompt_buf, M["active-by-prompt"])
end
M["last-prompt-token"] = function(prompt_buf)
  return history_api["last-prompt-token"](prompt_buf, M["active-by-prompt"])
end
M["last-prompt-tail"] = function(prompt_buf)
  return history_api["last-prompt-tail"](prompt_buf, M["active-by-prompt"])
end
M["saved-prompt-entry"] = function(tag)
  return history_api["saved-prompt-entry"](tag)
end
M["prompt-home"] = function(prompt_buf)
  return router_prompt_mod["prompt-home!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-end"] = function(prompt_buf)
  return router_prompt_mod["prompt-end!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-kill-backward"] = function(prompt_buf)
  return router_prompt_mod["prompt-kill-backward!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-kill-forward"] = function(prompt_buf)
  return router_prompt_mod["prompt-kill-forward!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-yank"] = function(prompt_buf)
  return router_prompt_mod["prompt-yank!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-newline"] = function(prompt_buf)
  return router_prompt_mod["prompt-newline!"](M["active-by-prompt"], prompt_buf)
end
M["prompt-insert-text"] = function(prompt_buf, text)
  return router_prompt_mod["prompt-insert-text!"](M["active-by-prompt"], prompt_buf, text)
end
M["insert-last-prompt"] = function(prompt_buf)
  return router_prompt_mod["insert-last-prompt!"](M["active-by-prompt"], history_api, prompt_buf)
end
M["insert-last-token"] = function(prompt_buf)
  return router_prompt_mod["insert-last-token!"](M["active-by-prompt"], history_api, prompt_buf)
end
M["insert-last-tail"] = function(prompt_buf)
  return router_prompt_mod["insert-last-tail!"](M["active-by-prompt"], history_api, prompt_buf)
end
M["negate-current-token"] = function(prompt_buf)
  return router_prompt_mod["negate-current-token!"](M["active-by-prompt"], prompt_buf)
end
M["open-history-searchback"] = function(prompt_buf)
  return router_actions_mod["open-history-searchback!"](actions_deps, prompt_buf)
end
M["merge-history-cache"] = function(prompt_buf)
  return router_actions_mod["merge-history-cache!"](actions_deps, prompt_buf)
end
M["exclude-symbol-under-cursor"] = function(prompt_buf)
  return router_actions_mod["exclude-symbol-under-cursor!"](actions_deps, prompt_buf)
end
M["insert-symbol-under-cursor"] = function(prompt_buf)
  return router_actions_mod["insert-symbol-under-cursor!"](actions_deps, prompt_buf)
end
M["insert-symbol-under-cursor-newline"] = function(prompt_buf)
  return router_actions_mod["insert-symbol-under-cursor-newline!"](actions_deps, prompt_buf)
end
M["toggle-prompt-results-focus"] = function(prompt_buf)
  return router_actions_mod["toggle-prompt-results-focus!"](actions_deps, prompt_buf)
end
M["accept-main"] = function(prompt_buf)
  return router_actions_mod["accept-main!"](actions_deps, prompt_buf)
end
M["enter-edit-mode"] = function(prompt_buf)
  return router_actions_mod["enter-edit-mode!"](actions_deps, prompt_buf)
end
M["write-results"] = function(prompt_buf)
  return router_actions_mod["write-results!"](actions_deps, prompt_buf)
end
M["sync-live-edits"] = function(prompt_buf)
  return router_actions_mod["sync-live-edits!"](actions_deps, prompt_buf)
end
M["results-buffer-wiped"] = function(results_buf)
  return router_actions_mod["on-results-buffer-wipe!"](actions_deps, results_buf)
end
M["remove-session"] = function(session)
  return remove_session(session)
end
M["maybe-restore-hidden-ui"] = function(prompt_buf, force)
  local function _39_()
    if (force == nil) then
      return false
    else
      return force
    end
  end
  return router_actions_mod["maybe-restore-ui!"](actions_deps, prompt_buf, _39_())
end
M["hide-visible-ui"] = function(prompt_buf)
  return router_actions_mod["hide-visible-ui!"](actions_deps, prompt_buf)
end
local function _40_(prompt_buf, force, event_tick)
  return M["on-prompt-changed"](prompt_buf, force, event_tick)
end
local function _41_(session_or_prompt_buf, force)
  local prompt_buf
  if (type(session_or_prompt_buf) == "table") then
    prompt_buf = session_or_prompt_buf["prompt-buf"]
  else
    prompt_buf = session_or_prompt_buf
  end
  return M["maybe-restore-hidden-ui"](prompt_buf, force)
end
local function _43_(session_or_prompt_buf)
  local prompt_buf
  if (type(session_or_prompt_buf) == "table") then
    prompt_buf = session_or_prompt_buf["prompt-buf"]
  else
    prompt_buf = session_or_prompt_buf
  end
  return M["hide-visible-ui"](prompt_buf)
end
session_deps = {router = M, ["history-api"] = history_api, ["query-mod"] = query_mod, ["remove-session!"] = remove_session, ["session-view"] = session_view, ["base-buffer"] = base_buffer, ["project-source"] = project_source, ["history-store"] = history_store, ["next-instance-id!"] = next_instance_id_21, ["sync-prompt-buffer-name!"] = sync_prompt_buffer_name_21, ["apply-prompt-lines"] = apply_prompt_lines, ["update-preview-window"] = update_preview_window, ["update-info-window"] = update_info_window, ["on-prompt-changed"] = _40_, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21, ["refresh-source-syntax!"] = refresh_source_syntax_21, ["maybe-restore-hidden-ui!"] = _41_, ["hide-visible-ui!"] = _43_, mods = {meta = meta_mod, ["router-util"] = router_util_mod, ["prompt-window"] = prompt_window_mod, ["meta-window"] = meta_window_mod, ["prompt-hooks"] = prompt_hooks_mod, animation = animation_mod}, windows = {preview = preview_window, info = info_window, context = context_window}, ui = {["loading-indicator"] = M["ui-loading-indicator"], animation = {enabled = M["ui-animations-enabled"], backend = M["ui-animation-backend"], ["time-scale"] = M["ui-animations-time-scale"], prompt = {enabled = M["ui-animation-prompt-enabled"], ms = M["ui-animation-prompt-ms"], ["time-scale"] = M["ui-animation-prompt-time-scale"], backend = M["ui-animation-prompt-backend"]}, preview = {enabled = M["ui-animation-preview-enabled"], ms = M["ui-animation-preview-ms"], ["time-scale"] = M["ui-animation-preview-time-scale"]}, info = {enabled = M["ui-animation-info-enabled"], ms = M["ui-animation-info-ms"], ["time-scale"] = M["ui-animation-info-time-scale"], backend = M["ui-animation-info-backend"]}, loading = {enabled = M["ui-animation-loading-enabled"], ms = M["ui-animation-loading-ms"], ["time-scale"] = M["ui-animation-loading-time-scale"]}, scroll = {enabled = M["ui-animation-scroll-enabled"], ms = M["ui-animation-scroll-ms"], ["time-scale"] = M["ui-animation-scroll-time-scale"], backend = M["ui-animation-scroll-backend"]}}}}
M["toggle-scan-option"] = function(prompt_buf, which)
  return router_actions_mod["toggle-scan-option!"](actions_deps, prompt_buf, which)
end
M["toggle-project-mode"] = function(prompt_buf)
  return router_actions_mod["toggle-project-mode!"](actions_deps, prompt_buf)
end
M["toggle-info-file-entry-view"] = function(prompt_buf)
  return router_actions_mod["toggle-info-file-entry-view!"](actions_deps, prompt_buf)
end
M["refresh-files"] = function(prompt_buf)
  return router_actions_mod["refresh-files!"](actions_deps, prompt_buf)
end
M.start = function(query, mode, _meta, project_mode)
  if (vim.fn.getcmdwintype() ~= "") then
    return nil
  else
  end
  return router_session_mod["start!"](session_deps, query, mode, _meta, project_mode)
end
M.sync = function(meta, query)
  if not meta then
    vim.notify("No Meta instance", vim.log.levels.WARN)
  else
  end
  if meta then
    local function _47_()
      if (query and (query ~= "")) then
        return {query}
      else
        return {}
      end
    end
    meta["set-query-lines"](_47_())
    meta["on-update"](0)
    M._store_vars(meta)
    return meta
  else
    return nil
  end
end
M.push = function(meta)
  if not meta then
    vim.notify("No Meta instance", vim.log.levels.WARN)
  else
  end
  if meta then
    local lines = vim.api.nvim_buf_get_lines(meta.buf.buffer, 0, -1, false)
    return meta.buf["push-visible-lines"](lines)
  else
    return nil
  end
end
M.entry_start = function(query, _bang)
  return M.start(query, "start", nil, _bang)
end
M.entry_resume = function(query)
  return M.start(query, "resume", nil)
end
M.entry_sync = function(query)
  local key = vim.api.nvim_get_current_buf()
  local session = M["active-by-source"][key]
  local inst = M.instances[key]
  local meta = ((session and session.meta) or (inst and inst.meta) or inst)
  return M.sync(meta, query)
end
M.entry_push = function()
  local key = vim.api.nvim_get_current_buf()
  local session = M["active-by-source"][key]
  if (session and session["prompt-buf"] and session.meta and session.meta.buf and (key == session.meta.buf.buffer)) then
    return M["write-results"](session["prompt-buf"])
  else
    local inst = M.instances[key]
    local meta = ((session and session.meta) or (inst and inst.meta) or inst)
    return M.push(meta)
  end
end
M.entry_cursor_word = function(resume)
  local w = vim.fn.expand("<cword>")
  if resume then
    return M.entry_resume(w)
  else
    return M.entry_start(w, false)
  end
end
local function clear_table_21(tbl)
  for k, _ in pairs((tbl or {})) do
    tbl[k] = nil
  end
  return nil
end
local function add_session_21(seen, sessions, session)
  if (session and (type(session) == "table") and not seen[session]) then
    seen[session] = true
    return table.insert(sessions, session)
  else
    return nil
  end
end
local function maybe_close_win_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_close, win, true)
  else
    return nil
  end
end
local function maybe_delete_buf_21(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    base_buffer["clear-modified!"](buf)
    return pcall(vim.api.nvim_buf_delete, buf, {force = true})
  else
    return nil
  end
end
M["fail-safe-teardown!"] = function(where, err)
  M["_last-failsafe"] = {where = where, error = tostring(err)}
  if not M["_teardown-in-progress"] then
    M["_teardown-in-progress"] = true
    do
      local seen = {}
      local sessions = {}
      for _, session in pairs((M.instances or {})) do
        add_session_21(seen, sessions, session)
      end
      for _, session in pairs((M["active-by-prompt"] or {})) do
        add_session_21(seen, sessions, session)
      end
      for _, session in pairs((M["active-by-source"] or {})) do
        add_session_21(seen, sessions, session)
      end
      for _, session in ipairs(sessions) do
        pcall(router_actions_mod["remove-session!"], actions_deps, session)
        maybe_close_win_21(session["prompt-win"])
        maybe_delete_buf_21(session["prompt-buf"])
        if (session.meta and session.meta.win) then
          maybe_close_win_21(session.meta.win.window)
        else
        end
        if (session.meta and session.meta.buf) then
          maybe_delete_buf_21(session.meta.buf.buffer)
        else
        end
        if ((type(info_window) == "table") and info_window["close-window!"]) then
          pcall(info_window["close-window!"], session)
        else
        end
        if ((type(preview_window) == "table") and preview_window["close-window!"]) then
          pcall(preview_window["close-window!"], session)
        else
        end
        if ((type(context_window) == "table") and context_window["close-window!"]) then
          pcall(context_window["close-window!"], session)
        else
        end
        if history_api then
          pcall(history_api["close-history-browser!"], session)
        else
        end
      end
    end
    clear_table_21(M.instances)
    clear_table_21(M["active-by-prompt"])
    clear_table_21(M["active-by-source"])
    clear_table_21(M["launching-by-source"])
    M["_teardown-in-progress"] = false
  else
  end
  local function _63_()
    return vim.notify(("metabuffer: torn down after error in " .. tostring(where) .. "\n" .. tostring(err)), vim.log.levels.ERROR)
  end
  return vim.schedule(_63_)
end
local function wrap_public_api_with_failsafe_21()
  if not M["_failsafe-wrapped"] then
    for k, v in pairs(M) do
      if ((type(k) == "string") and (type(v) == "function") and not vim.startswith(k, "_") and (k ~= "configure") and (k ~= "fail-safe-teardown!")) then
        local function _64_(...)
          local res = {pcall(v, ...)}
          local ok = res[1]
          local result = res[2]
          if ok then
            return unpack(res, 2)
          else
            M["fail-safe-teardown!"](k, result)
            return error(result)
          end
        end
        M[k] = _64_
      else
      end
    end
    M["_failsafe-wrapped"] = true
    return nil
  else
    return nil
  end
end
wrap_public_api_with_failsafe_21()
return M
