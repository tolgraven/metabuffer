-- [nfnl] fnl/metabuffer/router/session.fnl
local M = {}
local function register_prompt_hooks_21(deps, session)
  local prompt_hooks_mod = deps["prompt-hooks-mod"]
  local router_util_mod = deps["router-util-mod"]
  local default_prompt_keymaps = deps["default-prompt-keymaps"]
  local default_main_keymaps = deps["default-main-keymaps"]
  local active_by_prompt = deps["active-by-prompt"]
  local on_prompt_changed = deps["on-prompt-changed"]
  local update_info_window = deps["update-info-window"]
  local maybe_sync_from_main_21 = deps["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = deps["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = deps["maybe-restore-hidden-ui!"]
  local preview_window = deps["preview-window"]
  local context_window = deps["context-window"]
  local sign_mod = deps["sign-mod"]
  local router_api = deps["router-api"]
  local hooks
  local function _1_(s)
    if (preview_window and preview_window["refresh-statusline!"]) then
      return preview_window["refresh-statusline!"](s)
    else
      return nil
    end
  end
  local function _3_(s)
    if (context_window and context_window["update!"]) then
      return context_window["update!"](s)
    else
      return nil
    end
  end
  hooks = prompt_hooks_mod.new({["mark-prompt-buffer!"] = router_util_mod["mark-prompt-buffer!"], ["default-prompt-keymaps"] = default_prompt_keymaps, ["default-main-keymaps"] = default_main_keymaps, ["active-by-prompt"] = active_by_prompt, ["on-prompt-changed"] = on_prompt_changed, ["update-info-window"] = update_info_window, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21, ["maybe-restore-hidden-ui!"] = maybe_restore_hidden_ui_21, ["maybe-refresh-preview-statusline!"] = _1_, ["update-context-window!"] = _3_, ["sign-mod"] = sign_mod})
  return hooks["register!"](router_api, session)
end
M["start!"] = function(deps, query, mode, _meta, project_mode)
  local history_api = deps["history-api"]
  local query_mod = deps["query-mod"]
  local remove_session_21 = deps["remove-session!"]
  local active_by_source = deps["active-by-source"]
  local active_by_prompt = deps["active-by-prompt"]
  local instances = deps.instances
  local session_view = deps["session-view"]
  local meta_mod = deps["meta-mod"]
  local base_buffer = deps["base-buffer"]
  local router_util_mod = deps["router-util-mod"]
  local prompt_window_mod = deps["prompt-window-mod"]
  local project_source = deps["project-source"]
  local meta_window_mod = deps["meta-window-mod"]
  local history_store = deps["history-store"]
  local sign_mod = deps["sign-mod"]
  local read_file_lines_cached = deps["read-file-lines-cached"]
  local settings = deps.settings
  local next_instance_id_21 = deps["next-instance-id!"]
  local sync_prompt_buffer_name_21 = deps["sync-prompt-buffer-name!"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local update_info_window = deps["update-info-window"]
  local context_window = deps["context-window"]
  local maybe_restore_hidden_ui_21 = deps["maybe-restore-hidden-ui!"]
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
  local start_hex
  do
    local val_113_auto = parsed_query["include-hex"]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      start_hex = v
    else
      start_hex = query_mod["truthy?"](settings["default-include-hex"])
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
  local query1 = query0
  local source_buf = vim.api.nvim_get_current_buf()
  local existing = active_by_source[source_buf]
  if (existing and existing["ui-hidden"] and maybe_restore_hidden_ui_21 and existing.meta and existing.meta.buf and (source_buf == existing.meta.buf.buffer)) then
    maybe_restore_hidden_ui_21(existing, true)
    return existing.meta
  else
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
    local curr = meta_mod.new(vim, condition)
    curr["project-mode"] = (project_mode or false)
    base_buffer["switch-buf"](curr.buf.buffer)
    router_util_mod["ensure-source-refs!"](curr)
    curr.buf["keep-modifiable"] = true
    do
      local bo = vim.bo[curr.buf.buffer]
      bo["buftype"] = "acwrite"
      bo["modifiable"] = true
      bo["readonly"] = false
      bo["bufhidden"] = "hide"
    end
    pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, "meta_manual_edit_active", false)
    pcall(vim.api.nvim_buf_set_var, curr.buf.buffer, "meta_internal_render", false)
    local initial_lines
    if (prompt_query0 and (prompt_query0 ~= "")) then
      initial_lines = vim.split(prompt_query0, "\n", {plain = true})
    else
      initial_lines = {""}
    end
    local prompt_win = prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"](), ["window-local-layout"] = settings["window-local-layout"], ["origin-win"] = origin_win})
    local prompt_buf = prompt_win.buffer
    local session
    local _18_
    if query_mod["query-lines-has-active?"](parsed_query.lines) then
      _18_ = settings["project-bootstrap-delay-ms"]
    else
      _18_ = settings["project-bootstrap-idle-delay-ms"]
    end
    local _20_
    if (query1 and (query1 ~= "")) then
      _20_ = vim.split(query1, "\n", {plain = true})
    else
      _20_ = {""}
    end
    session = {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["prompt-win"] = prompt_win.window, ["prompt-buf"] = prompt_buf, ["window-local-layout"] = settings["window-local-layout"], ["prompt-keymaps"] = settings["prompt-keymaps"], ["main-keymaps"] = settings["main-keymaps"], ["prompt-fallback-keymaps"] = settings["prompt-fallback-keymaps"], ["info-file-entry-view"] = (settings["info-file-entry-view"] or "meta"), ["initial-prompt-text"] = table.concat(initial_lines, "\n"), ["last-prompt-text"] = table.concat(initial_lines, "\n"), ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = table.concat(initial_lines, "\n"), ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["project-mode"] = (project_mode or false), ["read-file-lines-cached"] = read_file_lines_cached, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-hex"] = start_hex, ["include-files"] = start_files, ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["effective-include-binary"] = start_binary, ["effective-include-hex"] = start_hex, ["effective-include-files"] = start_files, ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _18_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["expansion-mode"] = start_expansion, ["last-parsed-query"] = {lines = _20_, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["include-binary"] = start_binary, ["include-hex"] = start_hex, ["include-files"] = start_files, ["file-lines"] = (parsed_query["file-lines"] or {}), prefilter = start_prefilter, lazy = start_lazy, expansion = start_expansion}, ["file-query-lines"] = (parsed_query["file-lines"] or {}), ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), ["instance-id"] = next_instance_id_21(), meta = curr, ["project-bootstrap-pending"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
    local initial_query_active = session["initial-query-active"]
    curr.session = session
    if session["project-mode"] then
      project_source["apply-minimal-source-set!"](session)
    else
      project_source["apply-source-set!"](session)
    end
    curr["status-win"] = meta_window_mod.new(vim, prompt_win.window)
    curr.win["set-statusline"]("")
    curr["on-init"]()
    if sign_mod then
      pcall(sign_mod["capture-baseline!"], session)
    else
    end
    sync_prompt_buffer_name_21(session)
    if session["project-mode"] then
      session_view["restore-meta-view!"](curr, session["source-view"])
    else
    end
    vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, initial_lines)
    router_util_mod["mark-prompt-buffer!"](prompt_buf)
    register_prompt_hooks_21(deps, session)
    active_by_source[source_buf] = session
    active_by_prompt[prompt_buf] = session
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
    local function _26_()
      session["startup-initializing"] = false
      if (session["project-mode"] and not session["project-bootstrapped"]) then
        return project_source["schedule-project-bootstrap!"](session, 0)
      else
        return nil
      end
    end
    vim.schedule(_26_)
    if (session["project-mode"] and not initial_query_active) then
      local function _28_()
        if (active_by_prompt[session["prompt-buf"]] == session) then
          pcall(curr.refresh_statusline)
          pcall(update_info_window, session)
          if (context_window and context_window["update!"]) then
            return pcall(context_window["update!"], session)
          else
            return nil
          end
        else
          return nil
        end
      end
      vim.schedule(_28_)
    else
    end
    if (context_window and context_window["update!"]) then
      local function _32_()
        return pcall(context_window["update!"], session)
      end
      vim.schedule(_32_)
    else
    end
    instances[session["instance-id"]] = session
    return curr
  end
end
return M
