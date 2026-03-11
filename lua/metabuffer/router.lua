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
local prompt_hooks_mod = require("metabuffer.prompt.hooks")
local router_util_mod = require("metabuffer.router.util")
local router_history_mod = require("metabuffer.router.history")
local router_prompt_mod = require("metabuffer.router.prompt")
local router_query_flow_mod = require("metabuffer.router.query_flow")
local router_actions_mod = require("metabuffer.router.actions")
local M = {}
local function sync_prompt_buffer_name_21(session)
  if (session and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and session.meta and session.meta.buf and (type(session.meta.buf.name) == "string") and (session.meta.buf.name ~= "")) then
    return pcall(vim.api.nvim_buf_set_name, session["prompt-buf"], (session.meta.buf.name .. " [Prompt]"))
  else
    return nil
  end
end
M.instances = {}
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
  if (info_window and info_window["update!"]) then
    return info_window["update!"](session, refresh_lines)
  else
    return nil
  end
end
update_info_window = _10_
local project_source
local function _12_(rel, include_hidden, include_deps)
  return router_util_mod["allow-project-path?"](M, rel, include_hidden, include_deps)
end
local function _13_(root, include_hidden, include_ignored, include_deps)
  return router_util_mod["project-file-list"](M, root, include_hidden, include_ignored, include_deps)
end
local function _14_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _15_(session)
  return router_util_mod["session-active?"](M["active-by-prompt"], session)
end
local function _16_(session)
  return router_util_mod["lazy-streaming-allowed?"](M, query_mod, session)
end
local function _17_(prompt_buf, force)
  return M["on-prompt-changed"](prompt_buf, force)
end
local function _18_(session)
  return router_prompt_mod["prompt-has-active-query?"](query_mod, router_util_mod["prompt-lines"], session)
end
local function _19_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
local function _20_(session, wait_ms)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, wait_ms)
end
project_source = project_source_mod.new({settings = M, ["truthy?"] = query_mod["truthy?"], ["selected-ref"] = router_util_mod["selected-ref"], ["canonical-path"] = router_util_mod["canonical-path"], ["current-buffer-path"] = router_util_mod["current-buffer-path"], ["path-under-root?"] = router_util_mod["path-under-root?"], ["allow-project-path?"] = _12_, ["project-file-list"] = _13_, ["read-file-lines-cached"] = _14_, ["session-active?"] = _15_, ["lazy-streaming-allowed?"] = _16_, ["on-prompt-changed"] = _17_, ["prompt-has-active-query?"] = _18_, ["now-ms"] = router_prompt_mod["now-ms"], ["prompt-update-delay-ms"] = _19_, ["schedule-prompt-update!"] = _20_, ["restore-meta-view!"] = session_view["restore-meta-view!"], ["update-info-window"] = update_info_window})
local function _21_(session)
  return history_api["open-history-browser!"](session, "saved")
end
local function _22_(session)
  return apply_prompt_lines(session)
end
query_flow_deps = {["active-by-prompt"] = M["active-by-prompt"], ["query-mod"] = query_mod, ["project-source"] = project_source, ["update-info-window"] = update_info_window, settings = M, ["prompt-scheduler-ctx"] = prompt_scheduler_ctx, ["merge-history-into-session!"] = history_api["merge-history-into-session!"], ["save-current-prompt-tag!"] = history_api["save-current-prompt-tag!"], ["restore-saved-prompt-tag!"] = history_api["restore-saved-prompt-tag!"], ["open-saved-browser!"] = _21_, ["apply-prompt-lines"] = _22_}
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
local function _23_(session)
  return router_query_flow_mod["apply-prompt-lines!"](query_flow_deps, session)
end
apply_prompt_lines = _23_
actions_deps = {["active-by-source"] = M["active-by-source"], ["active-by-prompt"] = M["active-by-prompt"], ["history-api"] = history_api, ["history-store"] = history_store, ["router-util-mod"] = router_util_mod, ["router-prompt-mod"] = router_prompt_mod, ["session-view"] = session_view, ["base-buffer"] = base_buffer, ["info-window"] = info_window, ["preview-window"] = preview_window, ["project-source"] = project_source, ["update-info-window"] = update_info_window, ["sync-prompt-buffer-name!"] = sync_prompt_buffer_name_21, ["apply-prompt-lines"] = apply_prompt_lines, wrapup = M._wrapup}
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
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    local runner
    local function _25_()
      local meta = session.meta
      local max = #meta.buf.indices
      if (max > 0) then
        meta.selected_index = math.max(0, math.min((meta.selected_index + delta), (max - 1)))
        do
          local row = (meta.selected_index + 1)
          if vim.api.nvim_win_is_valid(meta.win.window) then
            pcall(vim.api.nvim_win_set_cursor, meta.win.window, {row, 0})
          else
          end
        end
        pcall(meta.refresh_statusline)
        return pcall(update_info_window, session, false)
      else
        return nil
      end
    end
    runner = _25_
    local mode = vim.api.nvim_get_mode().mode
    if ((type(mode) == "string") and vim.startswith(mode, "i")) then
      return vim.schedule(runner)
    else
      return runner()
    end
  else
    return nil
  end
end
local function can_refresh_source_syntax_3f(session)
  local buf = (session and session.meta and session.meta.buf)
  return (session and session["project-mode"] and buf and buf["show-source-separators"] and (buf["syntax-type"] == "buffer"))
end
local function schedule_source_syntax_refresh_21(session)
  if can_refresh_source_syntax_3f(session) then
    session["syntax-refresh-dirty"] = true
    if not session["syntax-refresh-pending"] then
      session["syntax-refresh-pending"] = true
      local function _30_()
        session["syntax-refresh-pending"] = false
        if (session and session["prompt-buf"] and (M["active-by-prompt"][session["prompt-buf"]] == session)) then
          if session["syntax-refresh-dirty"] then
            session["syntax-refresh-dirty"] = false
            pcall(session.meta.buf["apply-source-syntax-regions"])
          else
          end
          if session["syntax-refresh-dirty"] then
            return schedule_source_syntax_refresh_21(session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_30_, (M["source-syntax-refresh-debounce-ms"] or 80))
    else
      return nil
    end
  else
    return nil
  end
end
M["scroll-main"] = function(prompt_buf, action)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and vim.api.nvim_win_is_valid(session.meta.win.window)) then
    local runner
    local function _36_()
      local function _37_()
        local line_count = vim.api.nvim_buf_line_count(session.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(session.meta.win.window))
        local half_step = math.max(1, math.floor((win_height / 2)))
        local page_step = math.max(1, (win_height - 2))
        local step
        if ((action == "line-down") or (action == "line-up")) then
          step = 1
        elseif ((action == "half-down") or (action == "half-up")) then
          step = half_step
        else
          step = page_step
        end
        local dir
        if ((action == "line-down") or (action == "half-down") or (action == "page-down")) then
          dir = 1
        else
          dir = -1
        end
        local max_top = math.max(1, ((line_count - win_height) + 1))
        local view = vim.fn.winsaveview()
        local old_top = view.topline
        local old_lnum = view.lnum
        local old_col = (view.col or 0)
        local row_off = math.max(0, (old_lnum - old_top))
        local new_top = math.max(1, math.min((old_top + (dir * step)), max_top))
        local new_lnum = math.max(1, math.min((new_top + row_off), line_count))
        view["topline"] = new_top
        view["lnum"] = new_lnum
        view["col"] = old_col
        return vim.fn.winrestview(view)
      end
      vim.api.nvim_win_call(session.meta.win.window, _37_)
      session_view["sync-selected-from-main-cursor!"](session)
      pcall(session.meta.refresh_statusline)
      return pcall(update_info_window, session, false)
    end
    runner = _36_
    local mode = vim.api.nvim_get_mode().mode
    if ((type(mode) == "string") and vim.startswith(mode, "i")) then
      return vim.schedule(runner)
    else
      return runner()
    end
  else
    return nil
  end
end
local function maybe_sync_from_main_21(session, force_refresh)
  return session_view["maybe-sync-from-main!"](session, force_refresh, {["active-by-prompt"] = M["active-by-prompt"], ["schedule-source-syntax-refresh!"] = schedule_source_syntax_refresh_21, ["update-info-window"] = update_info_window})
end
local function schedule_scroll_sync_21(session)
  return session_view["schedule-scroll-sync!"](session, {["scroll-sync-debounce-ms"] = M["scroll-sync-debounce-ms"], ["maybe-sync-from-main!"] = maybe_sync_from_main_21})
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
M["accept-main"] = function(prompt_buf)
  return router_actions_mod["accept-main!"](actions_deps, prompt_buf)
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
local function register_prompt_hooks(session)
  local hooks = prompt_hooks_mod.new({["mark-prompt-buffer!"] = router_util_mod["mark-prompt-buffer!"], ["default-prompt-keymaps"] = M["prompt-keymaps"], ["default-main-keymaps"] = M["main-keymaps"], ["active-by-prompt"] = M["active-by-prompt"], ["on-prompt-changed"] = M["on-prompt-changed"], ["update-info-window"] = update_info_window, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21})
  return hooks["register!"](M, session)
end
M.start = function(query, mode, _meta, project_mode)
  pcall(vim.cmd, "silent! nohlsearch")
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
  local parsed_query = query_mod["parse-query-text"](expanded_query)
  local query0 = parsed_query.query
  local start_hidden
  do
    local val_113_auto = parsed_query["include-hidden"]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_hidden = v
    else
      start_hidden = query_mod["truthy?"](M["default-include-hidden"])
    end
  end
  local start_ignored
  do
    local val_113_auto = parsed_query["include-ignored"]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_ignored = v
    else
      start_ignored = query_mod["truthy?"](M["default-include-ignored"])
    end
  end
  local start_deps
  do
    local val_113_auto = parsed_query["include-deps"]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_deps = v
    else
      start_deps = query_mod["truthy?"](M["default-include-deps"])
    end
  end
  local start_files
  do
    local val_113_auto = parsed_query["include-files"]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_files = v
    else
      start_files = query_mod["truthy?"](M["default-include-files"])
    end
  end
  local start_prefilter
  do
    local val_113_auto = parsed_query.prefilter
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_prefilter = v
    else
      start_prefilter = query_mod["truthy?"](M["project-lazy-prefilter-enabled"])
    end
  end
  local start_lazy
  do
    local val_113_auto = parsed_query.lazy
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_lazy = v
    else
      start_lazy = query_mod["truthy?"](M["project-lazy-enabled"])
    end
  end
  local query1 = query0
  local source_buf = vim.api.nvim_get_current_buf()
  if M["active-by-source"][source_buf] then
    remove_session(M["active-by-source"][source_buf])
  else
  end
  local origin_win = vim.api.nvim_get_current_win()
  local origin_buf = source_buf
  local source_view = vim.fn.winsaveview()
  local _
  source_view["_meta_win_height"] = vim.api.nvim_win_get_height(origin_win)
  _ = nil
  local condition = session_view["setup-state"](query1, mode, source_view)
  local curr = meta_mod.new(vim, condition)
  curr["project-mode"] = (project_mode or false)
  base_buffer["switch-buf"](curr.buf.buffer)
  router_util_mod["ensure-source-refs!"](curr)
  local initial_lines
  if (query1 and (query1 ~= "")) then
    initial_lines = vim.split(query1, "\n", {plain = true})
  else
    initial_lines = {""}
  end
  local prompt_win = prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"](), ["window-local-layout"] = M["window-local-layout"], ["origin-win"] = origin_win})
  local prompt_buf = prompt_win.buffer
  local session
  local _51_
  if query_mod["query-lines-has-active?"](parsed_query.lines) then
    _51_ = M["project-bootstrap-delay-ms"]
  else
    _51_ = M["project-bootstrap-idle-delay-ms"]
  end
  local _53_
  if (query1 and (query1 ~= "")) then
    _53_ = vim.split(query1, "\n", {plain = true})
  else
    _53_ = {""}
  end
  session = {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["prompt-win"] = prompt_win.window, ["prompt-buf"] = prompt_buf, ["window-local-layout"] = M["window-local-layout"], ["prompt-keymaps"] = M["prompt-keymaps"], ["main-keymaps"] = M["main-keymaps"], ["prompt-fallback-keymaps"] = M["prompt-fallback-keymaps"], ["info-file-entry-view"] = (M["info-file-entry-view"] or "meta"), ["initial-prompt-text"] = table.concat(initial_lines, "\n"), ["last-prompt-text"] = table.concat(initial_lines, "\n"), ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = table.concat(initial_lines, "\n"), ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["project-mode"] = (project_mode or false), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-files"] = start_files, ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["effective-include-files"] = start_files, ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _51_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["last-parsed-query"] = {lines = _53_, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-files"] = start_files, ["file-lines"] = (parsed_query["file-lines"] or {}), prefilter = start_prefilter, lazy = start_lazy}, ["file-query-lines"] = (parsed_query["file-lines"] or {}), ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), meta = curr, ["project-bootstrap-pending"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
  local initial_query_active = session["initial-query-active"]
  if session["project-mode"] then
    project_source["apply-minimal-source-set!"](session)
  else
    project_source["apply-source-set!"](session)
  end
  curr["status-win"] = meta_window_mod.new(vim, prompt_win.window)
  curr.win["set-statusline"]("")
  curr["on-init"]()
  sync_prompt_buffer_name_21(session)
  if session["project-mode"] then
    session_view["restore-meta-view!"](curr, session["source-view"])
  else
  end
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, initial_lines)
  router_util_mod["mark-prompt-buffer!"](prompt_buf)
  register_prompt_hooks(session)
  M["active-by-source"][source_buf] = session
  M["active-by-prompt"][prompt_buf] = session
  if not (session["project-mode"] and not initial_query_active) then
    apply_prompt_lines(session)
  else
  end
  vim.api.nvim_set_current_win(prompt_win.window)
  do
    local row = math.max(1, #initial_lines)
    local line = (initial_lines[row] or "")
    local col = #line
    pcall(vim.api.nvim_win_set_cursor, prompt_win.window, {row, col})
  end
  vim.cmd("startinsert")
  local function _58_()
    session["startup-initializing"] = false
    if (session["project-mode"] and not session["project-bootstrapped"]) then
      return project_source["schedule-project-bootstrap!"](session, 0)
    else
      return nil
    end
  end
  vim.schedule(_58_)
  if (session["project-mode"] and not initial_query_active) then
    local function _60_()
      if (M["active-by-prompt"][session["prompt-buf"]] == session) then
        pcall(curr.refresh_statusline)
        return pcall(update_info_window, session)
      else
        return nil
      end
    end
    vim.schedule(_60_)
  else
  end
  M.instances[source_buf] = curr
  return curr
end
M.sync = function(meta, query)
  if not meta then
    vim.notify("No Meta instance", vim.log.levels.WARN)
  else
  end
  if meta then
    local function _64_()
      if (query and (query ~= "")) then
        return {query}
      else
        return {}
      end
    end
    meta["set-query-lines"](_64_())
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
  return M.sync(M.instances[key], query)
end
M.entry_push = function()
  local key = vim.api.nvim_get_current_buf()
  return M.push(M.instances[key])
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
