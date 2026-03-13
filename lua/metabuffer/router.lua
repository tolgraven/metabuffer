-- [nfnl] fnl/metabuffer/router.fnl
local meta_mod = require("metabuffer.meta")
local prompt_window_mod = require("metabuffer.window.prompt")
local meta_window_mod = require("metabuffer.window.metawindow")
local floating_window_mod = require("metabuffer.window.floating")
local preview_window_mod = require("metabuffer.window.preview")
local info_window_mod = require("metabuffer.window.info")
local history_browser_window_mod = require("metabuffer.window.history_browser")
local project_source_mod = require("metabuffer.project.source")
local base_buffer = require("metabuffer.buffer.base")
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
  if (session and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and session.meta and session.meta.buf and (type(session.meta.buf.name) == "string") and (session.meta.buf.name ~= "")) then
    return pcall(vim.api.nvim_buf_set_name, session["prompt-buf"], (session.meta.buf.name .. " [Prompt]"))
  else
    return nil
  end
end
M.instances = {}
M["_instance-seq"] = 0
M["active-by-source"] = {}
M["active-by-prompt"] = {}
local update_info_window = nil
local apply_prompt_lines = nil
local preview_window = nil
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
local function _2_(session)
  return apply_prompt_lines(session)
end
local function _3_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
prompt_scheduler_ctx = {["active-by-prompt"] = M["active-by-prompt"], ["apply-prompt-lines"] = _2_, ["prompt-update-delay-ms"] = _3_, ["now-ms"] = router_prompt_mod["now-ms"], ["cancel-prompt-update!"] = router_prompt_mod["cancel-prompt-update!"]}
local function _4_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _5_(session)
  return (session and session["prompt-buf"] and (M["active-by-prompt"][session["prompt-buf"]] == session))
end
preview_window = preview_window_mod.new({["floating-window-mod"] = floating_window_mod, ["selected-ref"] = router_util_mod["selected-ref"], ["read-file-lines-cached"] = _4_, ["is-active-session"] = _5_, ["debug-log"] = debug_log, ["source-switch-debounce-ms"] = M["preview-source-switch-debounce-ms"]})
do
  local candidate
  local function _6_(path)
    return router_util_mod["read-file-lines-cached"](M, path)
  end
  local function _7_(session)
    return preview_window["maybe-update-for-selection!"](session)
  end
  candidate = info_window_mod.new({["floating-window-mod"] = floating_window_mod, ["info-min-width"] = M["info-min-width"], ["info-max-width"] = M["info-max-width"], ["info-max-lines"] = M["info-max-lines"], ["info-height"] = router_util_mod["info-height"], ["debug-log"] = debug_log, ["read-file-lines-cached"] = _6_, ["update-preview"] = _7_})
  if (type(candidate) == "function") then
    local function _8_(_)
      return nil
    end
    info_window = {["update!"] = candidate, ["close-window!"] = _8_}
  else
    info_window = candidate
  end
end
history_browser_window = history_browser_window_mod.new({["floating-window-mod"] = floating_window_mod})
history_api = router_history_mod.new({["history-store"] = history_store, ["router-util-mod"] = router_util_mod, ["query-mod"] = query_mod, ["history-browser-window"] = history_browser_window, settings = M})
local function _10_(session, refresh_lines)
  if session then
    if session["ui-hidden"] then
      if (info_window and info_window["close-window!"]) then
        return info_window["close-window!"](session)
      else
        return nil
      end
    else
      if (info_window and info_window["update!"]) then
        return info_window["update!"](session, refresh_lines)
      else
        return nil
      end
    end
  else
    return nil
  end
end
update_info_window = _10_
local project_source
local function _15_(rel, include_hidden, include_deps)
  return router_util_mod["allow-project-path?"](M, rel, include_hidden, include_deps)
end
local function _16_(root, include_hidden, include_ignored, include_deps)
  return router_util_mod["project-file-list"](M, root, include_hidden, include_ignored, include_deps)
end
local function _17_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _18_(session)
  return router_util_mod["session-active?"](M["active-by-prompt"], session)
end
local function _19_(session)
  return router_util_mod["lazy-streaming-allowed?"](M, query_mod, session)
end
local function _20_(prompt_buf, force)
  return M["on-prompt-changed"](prompt_buf, force)
end
local function _21_(session)
  return router_prompt_mod["prompt-has-active-query?"](query_mod, router_util_mod["prompt-lines"], session)
end
local function _22_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
local function _23_(session, wait_ms)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, wait_ms)
end
project_source = project_source_mod.new({settings = M, ["truthy?"] = query_mod["truthy?"], ["selected-ref"] = router_util_mod["selected-ref"], ["canonical-path"] = router_util_mod["canonical-path"], ["current-buffer-path"] = router_util_mod["current-buffer-path"], ["path-under-root?"] = router_util_mod["path-under-root?"], ["allow-project-path?"] = _15_, ["project-file-list"] = _16_, ["read-file-lines-cached"] = _17_, ["session-active?"] = _18_, ["lazy-streaming-allowed?"] = _19_, ["on-prompt-changed"] = _20_, ["prompt-has-active-query?"] = _21_, ["now-ms"] = router_prompt_mod["now-ms"], ["prompt-update-delay-ms"] = _22_, ["schedule-prompt-update!"] = _23_, ["restore-meta-view!"] = session_view["restore-meta-view!"], ["update-info-window"] = update_info_window})
local function _24_(session)
  return history_api["open-history-browser!"](session, "saved")
end
local function _25_(session)
  return apply_prompt_lines(session)
end
query_flow_deps = {["active-by-prompt"] = M["active-by-prompt"], ["query-mod"] = query_mod, ["project-source"] = project_source, ["update-info-window"] = update_info_window, settings = M, ["prompt-scheduler-ctx"] = prompt_scheduler_ctx, ["merge-history-into-session!"] = history_api["merge-history-into-session!"], ["save-current-prompt-tag!"] = history_api["save-current-prompt-tag!"], ["restore-saved-prompt-tag!"] = history_api["restore-saved-prompt-tag!"], ["open-saved-browser!"] = _24_, ["refresh-change-signs!"] = sign_mod["refresh-change-signs!"], ["capture-sign-baseline!"] = sign_mod["capture-baseline!"], ["apply-prompt-lines"] = _25_}
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
local function _26_(session)
  return router_query_flow_mod["apply-prompt-lines!"](query_flow_deps, session)
end
apply_prompt_lines = _26_
actions_deps = {["active-by-source"] = M["active-by-source"], ["active-by-prompt"] = M["active-by-prompt"], instances = M.instances, settings = M, ["history-api"] = history_api, ["history-store"] = history_store, ["sign-mod"] = sign_mod, ["prompt-window-mod"] = prompt_window_mod, ["meta-window-mod"] = meta_window_mod, ["router-util-mod"] = router_util_mod, ["router-prompt-mod"] = router_prompt_mod, ["session-view"] = session_view, ["base-buffer"] = base_buffer, ["info-window"] = info_window, ["preview-window"] = preview_window, ["project-source"] = project_source, ["update-info-window"] = update_info_window, ["sync-prompt-buffer-name!"] = sync_prompt_buffer_name_21, ["apply-prompt-lines"] = apply_prompt_lines, wrapup = M._wrapup}
navigation_deps = {["active-by-prompt"] = M["active-by-prompt"], ["update-info-window"] = update_info_window, ["session-view"] = session_view, ["scroll-sync-debounce-ms"] = M["scroll-sync-debounce-ms"], ["source-syntax-refresh-debounce-ms"] = M["source-syntax-refresh-debounce-ms"]}
local function _27_()
  M["_instance-seq"] = ((M["_instance-seq"] or 0) + 1)
  return M["_instance-seq"]
end
local function _28_(prompt_buf, force, event_tick)
  return M["on-prompt-changed"](prompt_buf, force, event_tick)
end
local function _29_(session, force_refresh)
  return router_navigation_mod["maybe-sync-from-main!"](navigation_deps, session, force_refresh)
end
local function _30_(session)
  return router_navigation_mod["schedule-scroll-sync!"](navigation_deps, session)
end
local function _31_(session, force)
  local function _32_()
    if (force == nil) then
      return false
    else
      return force
    end
  end
  return router_actions_mod["maybe-restore-ui!"](actions_deps, session["prompt-buf"], _32_())
end
session_deps = {["router-api"] = M, settings = M, ["history-api"] = history_api, ["query-mod"] = query_mod, ["remove-session!"] = remove_session, ["active-by-source"] = M["active-by-source"], ["active-by-prompt"] = M["active-by-prompt"], instances = M.instances, ["session-view"] = session_view, ["meta-mod"] = meta_mod, ["base-buffer"] = base_buffer, ["router-util-mod"] = router_util_mod, ["prompt-window-mod"] = prompt_window_mod, ["project-source"] = project_source, ["meta-window-mod"] = meta_window_mod, ["history-store"] = history_store, ["sign-mod"] = sign_mod, ["next-instance-id!"] = _27_, ["sync-prompt-buffer-name!"] = sync_prompt_buffer_name_21, ["apply-prompt-lines"] = apply_prompt_lines, ["update-info-window"] = update_info_window, ["prompt-hooks-mod"] = prompt_hooks_mod, ["default-prompt-keymaps"] = M["prompt-keymaps"], ["default-main-keymaps"] = M["main-keymaps"], ["on-prompt-changed"] = _28_, ["maybe-sync-from-main!"] = _29_, ["schedule-scroll-sync!"] = _30_, ["maybe-restore-hidden-ui!"] = _31_}
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
M["maybe-restore-hidden-ui"] = function(prompt_buf)
  return router_actions_mod["maybe-restore-ui!"](actions_deps, prompt_buf, false)
end
M["toggle-scan-option"] = function(prompt_buf, which)
  return router_actions_mod["toggle-scan-option!"](actions_deps, prompt_buf, which)
end
M["toggle-project-mode"] = function(prompt_buf)
  return router_actions_mod["toggle-project-mode!"](actions_deps, prompt_buf)
end
M["toggle-info-file-entry-view"] = function(prompt_buf)
  return router_actions_mod["toggle-info-file-entry-view!"](actions_deps, prompt_buf)
end
M.start = function(query, mode, _meta, project_mode)
  return router_session_mod["start!"](session_deps, query, mode, _meta, project_mode)
end
M.sync = function(meta, query)
  if not meta then
    vim.notify("No Meta instance", vim.log.levels.WARN)
  else
  end
  if meta then
    local function _35_()
      if (query and (query ~= "")) then
        return {query}
      else
        return {}
      end
    end
    meta["set-query-lines"](_35_())
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
  local inst = M.instances[key]
  local meta = ((session and session.meta) or (inst and inst.meta) or inst)
  return M.push(meta)
end
M.entry_cursor_word = function(resume)
  local w = vim.fn.expand("<cword>")
  if resume then
    return M.entry_resume(w)
  else
    return M.entry_start(w, false)
  end
end
return M
