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
local router_prompt_mod = require("metabuffer.router.prompt")
local router_query_flow_mod = require("metabuffer.router.query_flow")
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
local query_flow_deps = nil
config["apply-router-defaults"](M, vim)
local push_history_21
local function _2_(text)
  return history_store["push!"](text, M["history-max"])
end
push_history_21 = _2_
local function debug_log(msg)
  return debug.log("router", msg)
end
local prompt_scheduler_ctx
local function _3_(session)
  return apply_prompt_lines(session)
end
local function _4_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
prompt_scheduler_ctx = {["active-by-prompt"] = M["active-by-prompt"], ["apply-prompt-lines"] = _3_, ["prompt-update-delay-ms"] = _4_, ["now-ms"] = router_prompt_mod["now-ms"], ["cancel-prompt-update!"] = router_prompt_mod["cancel-prompt-update!"]}
local function _5_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _6_(session)
  return (session and session["prompt-buf"] and (M["active-by-prompt"][session["prompt-buf"]] == session))
end
preview_window = preview_window_mod.new({["floating-window-mod"] = floating_window_mod, ["selected-ref"] = router_util_mod["selected-ref"], ["read-file-lines-cached"] = _5_, ["is-active-session"] = _6_, ["debug-log"] = debug_log, ["source-switch-debounce-ms"] = M["preview-source-switch-debounce-ms"]})
local function _7_(session)
  return preview_window["maybe-update-for-selection!"](session)
end
info_window = info_window_mod.new({["floating-window-mod"] = floating_window_mod, ["info-min-width"] = M["info-min-width"], ["info-max-width"] = M["info-max-width"], ["info-max-lines"] = M["info-max-lines"], ["info-height"] = router_util_mod["info-height"], ["debug-log"] = debug_log, ["update-preview"] = _7_})
history_browser_window = history_browser_window_mod.new({["floating-window-mod"] = floating_window_mod})
local function _8_(session, refresh_lines)
  return info_window["update!"](session, refresh_lines)
end
update_info_window = _8_
local project_source
local function _9_(rel, include_hidden, include_deps)
  return router_util_mod["allow-project-path?"](M, rel, include_hidden, include_deps)
end
local function _10_(root, include_hidden, include_ignored, include_deps)
  return router_util_mod["project-file-list"](M, root, include_hidden, include_ignored, include_deps)
end
local function _11_(path)
  return router_util_mod["read-file-lines-cached"](M, path)
end
local function _12_(session)
  return router_util_mod["session-active?"](M["active-by-prompt"], session)
end
local function _13_(session)
  return router_util_mod["lazy-streaming-allowed?"](M, query_mod, session)
end
local function _14_(prompt_buf, force)
  return M["on-prompt-changed"](prompt_buf, force)
end
local function _15_(session)
  return router_prompt_mod["prompt-has-active-query?"](query_mod, router_util_mod["prompt-lines"], session)
end
local function _16_(session)
  return router_prompt_mod["prompt-update-delay-ms"](M, query_mod, router_util_mod["prompt-lines"], session)
end
local function _17_(session, wait_ms)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, wait_ms)
end
project_source = project_source_mod.new({settings = M, ["truthy?"] = query_mod["truthy?"], ["selected-ref"] = router_util_mod["selected-ref"], ["canonical-path"] = router_util_mod["canonical-path"], ["current-buffer-path"] = router_util_mod["current-buffer-path"], ["path-under-root?"] = router_util_mod["path-under-root?"], ["allow-project-path?"] = _9_, ["project-file-list"] = _10_, ["read-file-lines-cached"] = _11_, ["session-active?"] = _12_, ["lazy-streaming-allowed?"] = _13_, ["on-prompt-changed"] = _14_, ["prompt-has-active-query?"] = _15_, ["now-ms"] = router_prompt_mod["now-ms"], ["prompt-update-delay-ms"] = _16_, ["schedule-prompt-update!"] = _17_, ["restore-meta-view!"] = session_view["restore-meta-view!"], ["update-info-window"] = update_info_window})
local function merge_history_into_session_21(session)
  local local0 = (session["history-cache"] or {})
  local merged = vim.deepcopy(local0)
  local incoming = history_store.list()
  local seen = {}
  for _, item in ipairs(merged) do
    if (type(item) == "string") then
      seen[item] = true
    else
    end
  end
  for _, item in ipairs(incoming) do
    if ((type(item) == "string") and (vim.trim(item) ~= "") and not seen[item]) then
      table.insert(merged, item)
      seen[item] = true
    else
    end
  end
  while (#merged > M["history-max"]) do
    table.remove(merged, 1)
  end
  session["history-cache"] = merged
  return nil
end
local function save_current_prompt_tag_21(session, tag, prompt)
  if ((type(tag) == "string") and (vim.trim(tag) ~= "") and (type(prompt) == "string") and (vim.trim(prompt) ~= "")) then
    return history_store["save-tag!"](tag, prompt)
  else
    return nil
  end
end
local function restore_saved_prompt_tag_21(session, tag)
  if (session and (type(tag) == "string") and (vim.trim(tag) ~= "")) then
    local val_110_auto = history_store["saved-entry"](tag)
    if val_110_auto then
      local saved = val_110_auto
      router_util_mod["set-prompt-text!"](session, saved)
      return true
    else
      return nil
    end
  else
    return nil
  end
end
local function history_browser_filter(session)
  return vim.trim((router_util_mod["prompt-text"](session) or ""))
end
local function history_browser_items(session)
  local mode = (session["history-browser-mode"] or "history")
  local filter0 = string.lower(history_browser_filter(session))
  local out = {}
  if (mode == "saved") then
    for _, item in ipairs(history_store["saved-items"]()) do
      local tag = (item.tag or "")
      local prompt = (item.prompt or "")
      local hay = string.lower((tag .. " " .. prompt))
      if ((filter0 == "") or not not string.find(hay, filter0, 1, true)) then
        table.insert(out, {label = ("##" .. tag .. "  " .. prompt), prompt = prompt, tag = tag})
      else
      end
    end
  else
    local h = (session["history-cache"] or history_store.list())
    for i = #h, 1, -1 do
      local entry = (h[i] or "")
      local hay = string.lower(entry)
      if ((filter0 == "") or not not string.find(hay, filter0, 1, true)) then
        table.insert(out, {label = entry, prompt = entry})
      else
      end
    end
  end
  return out
end
local function refresh_history_browser_21(session)
  if (session and history_browser_window and session["history-browser-active"]) then
    session["history-browser-filter"] = history_browser_filter(session)
    return history_browser_window["refresh!"](session, history_browser_items(session))
  else
    return nil
  end
end
local function close_history_browser_21(session)
  if history_browser_window then
    return history_browser_window["close!"](session)
  else
    return nil
  end
end
local function open_history_browser_21(session, mode)
  if history_browser_window then
    history_browser_window["open!"](session, (mode or "history"))
    return refresh_history_browser_21(session)
  else
    return nil
  end
end
local function apply_history_browser_selection_21(session)
  if (history_browser_window and session["history-browser-active"]) then
    do
      local val_110_auto = history_browser_window["selected!"](session)
      if val_110_auto then
        local selected = val_110_auto
        local val_110_auto0 = selected.prompt
        if val_110_auto0 then
          local prompt = val_110_auto0
          router_util_mod["set-prompt-text!"](session, prompt)
        else
        end
      else
      end
    end
    return close_history_browser_21(session)
  else
    return nil
  end
end
local function _32_(session)
  return open_history_browser_21(session, "saved")
end
local function _33_(session)
  return apply_prompt_lines(session)
end
query_flow_deps = {["active-by-prompt"] = M["active-by-prompt"], ["query-mod"] = query_mod, ["project-source"] = project_source, ["update-info-window"] = update_info_window, settings = M, ["prompt-scheduler-ctx"] = prompt_scheduler_ctx, ["merge-history-into-session!"] = merge_history_into_session_21, ["save-current-prompt-tag!"] = save_current_prompt_tag_21, ["restore-saved-prompt-tag!"] = restore_saved_prompt_tag_21, ["open-saved-browser!"] = _32_, ["apply-prompt-lines"] = _33_}
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
  if session then
    local or_34_ = session["last-prompt-text"]
    if not or_34_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_34_ = router_util_mod["prompt-text"](session)
      else
        or_34_ = ""
      end
    end
    push_history_21(or_34_)
    router_util_mod["persist-prompt-height!"](session)
    if session.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
    else
    end
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
      pcall(vim.api.nvim_win_close, session["prompt-win"], true)
    else
    end
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      pcall(vim.api.nvim_buf_delete, session["prompt-buf"], {force = true})
    else
    end
    info_window["close-window!"](session)
    preview_window["close-window!"](session)
    close_history_browser_21(session)
    if session["source-buf"] then
      M["active-by-source"][session["source-buf"]] = nil
    else
    end
    if session["prompt-buf"] then
      M["active-by-prompt"][session["prompt-buf"]] = nil
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function _42_(session)
  return router_query_flow_mod["apply-prompt-lines!"](query_flow_deps, session)
end
apply_prompt_lines = _42_
M["on-prompt-changed"] = function(prompt_buf, force, event_tick)
  router_query_flow_mod["on-prompt-changed!"](query_flow_deps, prompt_buf, force, event_tick)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["history-browser-active"]) then
    return refresh_history_browser_21(session)
  else
    return nil
  end
end
M.accept = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["history-browser-active"]) then
    return apply_history_browser_selection_21(session)
  else
    return M.finish("accept", prompt_buf)
  end
end
M.cancel = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["history-browser-active"]) then
    return close_history_browser_21(session)
  else
    return M.finish("cancel", prompt_buf)
  end
end
local function finish_accept(session)
  local curr = session.meta
  session["last-prompt-text"] = router_util_mod["prompt-text"](session)
  push_history_21(session["last-prompt-text"])
  apply_prompt_lines(session)
  router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
  pcall(vim.cmd, "stopinsert")
  do
    local matcher = curr.matcher()
    if matcher then
      pcall(matcher["remove-highlight"], matcher)
    else
    end
  end
  pcall(vim.cmd, ("sign unplace * buffer=" .. curr.buf.buffer))
  if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
    pcall(vim.api.nvim_set_current_win, session["origin-win"])
    pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
  else
  end
  if session["project-mode"] then
    local ref = router_util_mod["selected-ref"](curr)
    if (ref and ref.path) then
      vim.cmd(("edit " .. vim.fn.fnameescape(ref.path)))
      vim.api.nvim_win_set_cursor(0, {math.max(1, (ref.lnum or 1)), 0})
    else
    end
  else
    base_buffer["switch-buf"](curr.buf.model)
    local row = curr.selected_line()
    curr.win["set-row"](row, true)
    local vq = curr.vim_query()
    if (vq ~= "") then
      vim.api.nvim_win_set_cursor(0, {row, 0})
      local pos = vim.fn.searchpos(vq, "cnW", row)
      local hit_row = pos[1]
      local hit_col = pos[2]
      if ((hit_row == row) and (hit_col > 0)) then
        vim.api.nvim_win_set_cursor(0, {row, hit_col})
      else
      end
    else
    end
  end
  vim.cmd("normal! zv")
  do
    local vq = curr.vim_query()
    if (vq ~= "") then
      vim.fn.setreg("/", vq)
      vim.o.hlsearch = true
    else
    end
  end
  session_view["wipe-temp-buffers"](curr)
  remove_session(session)
  M._wrapup(curr)
  return curr
end
local function finish_cancel(session)
  local curr = session.meta
  router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
  session["last-prompt-text"] = router_util_mod["prompt-text"](session)
  push_history_21(session["last-prompt-text"])
  pcall(vim.cmd, "stopinsert")
  do
    local matcher = curr.matcher()
    if matcher then
      pcall(matcher["remove-highlight"], matcher)
    else
    end
  end
  pcall(vim.cmd, ("sign unplace * buffer=" .. curr.buf.buffer))
  vim.cmd("silent! nohlsearch")
  if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
    pcall(vim.api.nvim_set_current_win, session["origin-win"])
    pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
  else
  end
  base_buffer["switch-buf"](curr.buf.model)
  session_view["wipe-temp-buffers"](curr)
  remove_session(session)
  M._wrapup(curr)
  return curr
end
M.finish = function(kind, prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    if (kind == "accept") then
      return finish_accept(session)
    else
      return finish_cancel(session)
    end
  else
    return nil
  end
end
M["move-selection"] = function(prompt_buf, delta)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    local runner
    local function _57_()
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
    runner = _57_
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
      local function _62_()
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
      return vim.defer_fn(_62_, (M["source-syntax-refresh-debounce-ms"] or 80))
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
    local function _68_()
      local function _69_()
        local line_count = vim.api.nvim_buf_line_count(session.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(session.meta.win.window))
        local half_step = math.max(1, math.floor((win_height / 2)))
        local page_step = math.max(1, (win_height - 2))
        local step
        if ((action == "half-down") or (action == "half-up")) then
          step = half_step
        else
          step = page_step
        end
        local dir
        if ((action == "half-down") or (action == "page-down")) then
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
      vim.api.nvim_win_call(session.meta.win.window, _69_)
      session_view["sync-selected-from-main-cursor!"](session)
      pcall(session.meta.refresh_statusline)
      return pcall(update_info_window, session, false)
    end
    runner = _68_
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
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    if session["history-browser-active"] then
      return history_browser_window["move!"](session, delta)
    else
      local txt = router_util_mod["prompt-text"](session)
      local can_history = ((txt == "") or (txt == session["initial-prompt-text"]) or (txt == session["last-history-text"]))
      if can_history then
        local h = (session["history-cache"] or history_store.list())
        local n = #h
        if (n > 0) then
          session["history-index"] = math.max(0, math.min((session["history-index"] + delta), n))
          if (session["history-index"] == 0) then
            session["last-history-text"] = ""
            return router_util_mod["set-prompt-text!"](session, session["initial-prompt-text"])
          else
            local entry = h[((n - session["history-index"]) + 1)]
            if entry then
              session["last-history-text"] = entry
              return router_util_mod["set-prompt-text!"](session, entry)
            else
              return nil
            end
          end
        else
          return nil
        end
      else
        return M["move-selection"](prompt_buf, delta)
      end
    end
  else
    return nil
  end
end
local function history_latest(session)
  local h = ((session and session["history-cache"]) or history_store.list())
  local n = #h
  if (n > 0) then
    return h[n]
  else
    return ""
  end
end
local function history_latest_token(session)
  local entry = history_latest(session)
  local parts = vim.split((entry or ""), "%s+", {trimempty = true})
  if (#parts > 0) then
    return parts[#parts]
  else
    return ""
  end
end
local function history_latest_tail(session)
  local entry = history_latest(session)
  local parts = vim.split((entry or ""), "%s+", {trimempty = true})
  if (#parts > 1) then
    return table.concat(vim.list_slice(parts, 2), " ")
  else
    return ""
  end
end
M["last-prompt-entry"] = function(prompt_buf)
  return history_latest(M["active-by-prompt"][prompt_buf])
end
M["last-prompt-token"] = function(prompt_buf)
  return history_latest_token(M["active-by-prompt"][prompt_buf])
end
M["last-prompt-tail"] = function(prompt_buf)
  return history_latest_tail(M["active-by-prompt"][prompt_buf])
end
M["saved-prompt-entry"] = function(tag)
  return history_store["saved-entry"](tag)
end
local function prompt_insert_at_cursor_21(session, text)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"]) and (type(text) == "string") and (text ~= "")) then
    local _let_83_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_83_[1]
    local col = _let_83_[2]
    local row0 = math.max(0, (row - 1))
    local chunks = vim.split(text, "\n", {plain = true})
    local last_line = chunks[#chunks]
    local next_row = (row0 + #chunks)
    local next_col
    if (#chunks == 1) then
      next_col = (col + #last_line)
    else
      next_col = #last_line
    end
    vim.api.nvim_buf_set_text(session["prompt-buf"], row0, col, row0, col, chunks)
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {next_row, next_col})
  else
    return nil
  end
end
local function prompt_row_col(session)
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_86_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_86_[1]
    local col = _let_86_[2]
    return {row = math.max(1, row), row0 = math.max(0, (row - 1)), col = math.max(0, col)}
  else
    return {row = 1, row0 = 0, col = 0}
  end
end
local function prompt_line_text(session, row0)
  local lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)
  return (lines[1] or "")
end
M["prompt-home"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_88_ = prompt_row_col(session)
    local row = _let_88_.row
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, 0})
  else
    return nil
  end
end
M["prompt-end"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_90_ = prompt_row_col(session)
    local row = _let_90_.row
    local row0 = _let_90_.row0
    local line = prompt_line_text(session, row0)
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, #line})
  else
    return nil
  end
end
M["prompt-kill-backward"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_92_ = prompt_row_col(session)
    local row = _let_92_.row
    local row0 = _let_92_.row0
    local col = _let_92_.col
    if (col > 0) then
      local line = prompt_line_text(session, row0)
      local killed = string.sub(line, 1, col)
      session["prompt-yank-register"] = (killed or "")
      vim.api.nvim_buf_set_text(session["prompt-buf"], row0, 0, row0, col, {""})
      return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, 0})
    else
      return nil
    end
  else
    return nil
  end
end
M["prompt-kill-forward"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_95_ = prompt_row_col(session)
    local row = _let_95_.row
    local row0 = _let_95_.row0
    local col = _let_95_.col
    local line = prompt_line_text(session, row0)
    local len = #line
    if (col < len) then
      local killed = string.sub(line, (col + 1))
      session["prompt-yank-register"] = (killed or "")
      vim.api.nvim_buf_set_text(session["prompt-buf"], row0, col, row0, len, {""})
      return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, col})
    else
      return nil
    end
  else
    return nil
  end
end
M["prompt-yank"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  local text = ((session and session["prompt-yank-register"]) or "")
  if (text ~= "") then
    return prompt_insert_at_cursor_21(session, text)
  else
    return nil
  end
end
M["prompt-insert-text"] = function(prompt_buf, text)
  local session = M["active-by-prompt"][prompt_buf]
  return prompt_insert_at_cursor_21(session, text)
end
M["insert-last-prompt"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  local entry = history_latest(session)
  prompt_insert_at_cursor_21(session, entry)
  if (session and (entry ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
M["insert-last-token"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  local token = history_latest_token(session)
  local entry = history_latest(session)
  prompt_insert_at_cursor_21(session, token)
  if (session and (token ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
M["insert-last-tail"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  local tail = history_latest_tail(session)
  local entry = history_latest(session)
  prompt_insert_at_cursor_21(session, tail)
  if (session and (tail ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
local function find_token_span(line, col)
  local pos = 1
  local before = nil
  while (pos <= #line) do
    local s,e = string.find(line, "%S+", pos)
    if (s and e) then
      local s0 = (s - 1)
      local token = string.sub(line, s, e)
      if ((s0 <= col) and (col <= e)) then
        before = {s = s, e = e, token = token}
        pos = (#line + 1)
      else
        if (not before and (col < s0)) then
          before = {s = s, e = e, token = token}
          pos = (#line + 1)
        else
        end
        if (pos <= #line) then
          pos = (e + 1)
        else
        end
      end
    else
      pos = (#line + 1)
    end
  end
  return before
end
M["negate-current-token"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_106_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_106_[1]
    local col = _let_106_[2]
    local row0 = math.max(0, (row - 1))
    local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)[1] or "")
    local val_110_auto = find_token_span(line, col)
    if val_110_auto then
      local span = val_110_auto
      local s = span.s
      local e = span.e
      local token = span.token
      local negated = ((#token > 1) and (string.sub(token, 1, 1) == "!"))
      local next_token
      if negated then
        next_token = string.sub(token, 2)
      else
        next_token = ("!" .. token)
      end
      local delta = (#next_token - #token)
      local s0 = (s - 1)
      vim.api.nvim_buf_set_text(session["prompt-buf"], row0, s0, row0, e, {next_token})
      local _108_
      if (col >= s0) then
        _108_ = delta
      else
        _108_ = 0
      end
      return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, math.max(0, (col + _108_))})
    else
      return nil
    end
  else
    return nil
  end
end
M["open-history-searchback"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    if not session["history-cache"] then
      session["history-cache"] = vim.deepcopy(history_store.list())
    else
    end
    return open_history_browser_21(session, "history")
  else
    return nil
  end
end
M["merge-history-cache"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    merge_history_into_session_21(session)
    return refresh_history_browser_21(session)
  else
    return nil
  end
end
M["exclude-symbol-under-cursor"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    local word
    local function _115_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _115_)
    local token
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      token = ("!" .. word)
    else
      token = ""
    end
    if (token ~= "") then
      local current = router_util_mod["prompt-text"](session)
      local sep
      if ((current == "") or vim.endswith(current, " ") or vim.endswith(current, "\n")) then
        sep = ""
      else
        sep = " "
      end
      local next = (current .. sep .. token)
      return router_util_mod["set-prompt-text!"](session, next)
    else
      return nil
    end
  else
    return nil
  end
end
M["toggle-scan-option"] = function(prompt_buf, which)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    if (which == "ignored") then
      session["include-ignored"] = not session["include-ignored"]
    elseif (which == "deps") then
      session["include-deps"] = not session["include-deps"]
    elseif (which == "hidden") then
      session["include-hidden"] = not session["include-hidden"]
    else
    end
    session["effective-include-hidden"] = session["include-hidden"]
    session["effective-include-ignored"] = session["include-ignored"]
    session["effective-include-deps"] = session["include-deps"]
    if session["project-mode"] then
      project_source["apply-source-set!"](session)
    else
    end
    return apply_prompt_lines(session)
  else
    return nil
  end
end
M["toggle-project-mode"] = function(prompt_buf)
  local session = M["active-by-prompt"][prompt_buf]
  if session then
    session["project-mode"] = not session["project-mode"]
    session.meta["project-mode"] = session["project-mode"]
    session.meta.buf["set-name"](router_util_mod["meta-buffer-name"](session))
    sync_prompt_buffer_name_21(session)
    project_source["apply-source-set!"](session)
    return apply_prompt_lines(session)
  else
    return nil
  end
end
local function register_prompt_hooks(session)
  local hooks = prompt_hooks_mod.new({["mark-prompt-buffer!"] = router_util_mod["mark-prompt-buffer!"], ["default-prompt-keymaps"] = M["default-prompt-keymaps"], ["active-by-prompt"] = M["active-by-prompt"], ["on-prompt-changed"] = M["on-prompt-changed"], ["update-info-window"] = update_info_window, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21})
  return hooks["register!"](M, session)
end
M.start = function(query, mode, _meta, project_mode)
  pcall(vim.cmd, "silent! nohlsearch")
  local parsed_query = query_mod["parse-query-text"](query)
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
  local prompt_win = prompt_window_mod.new(vim, {height = router_util_mod["prompt-height"]()})
  local prompt_buf = prompt_win.buffer
  local session
  local _131_
  if query_mod["query-lines-has-active?"](parsed_query.lines) then
    _131_ = M["project-bootstrap-delay-ms"]
  else
    _131_ = M["project-bootstrap-idle-delay-ms"]
  end
  local _133_
  if (query1 and (query1 ~= "")) then
    _133_ = vim.split(query1, "\n", {plain = true})
  else
    _133_ = {""}
  end
  session = {["source-buf"] = source_buf, ["origin-win"] = origin_win, ["origin-buf"] = origin_buf, ["source-view"] = source_view, ["initial-source-line"] = math.max(1, (source_view.lnum or ((condition["selected-index"] or 0) + 1))), ["prompt-win"] = prompt_win.window, ["prompt-buf"] = prompt_buf, ["initial-prompt-text"] = table.concat(initial_lines, "\n"), ["last-prompt-text"] = table.concat(initial_lines, "\n"), ["last-history-text"] = "", ["history-index"] = 0, ["history-cache"] = vim.deepcopy(history_store.list()), ["prompt-change-seq"] = 0, ["prompt-last-apply-ms"] = 0, ["prompt-last-event-text"] = table.concat(initial_lines, "\n"), ["initial-query-active"] = query_mod["query-lines-has-active?"](parsed_query.lines), ["startup-initializing"] = true, ["project-mode"] = (project_mode or false), ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, ["effective-include-hidden"] = start_hidden, ["effective-include-ignored"] = start_ignored, ["effective-include-deps"] = start_deps, ["project-bootstrap-token"] = 0, ["project-bootstrap-delay-ms"] = _131_, ["project-bootstrapped"] = not (project_mode or false), ["prefilter-mode"] = start_prefilter, ["lazy-mode"] = start_lazy, ["last-parsed-query"] = {lines = _133_, ["include-hidden"] = start_hidden, ["include-ignored"] = start_ignored, ["include-deps"] = start_deps, prefilter = start_prefilter, lazy = start_lazy}, ["single-content"] = vim.deepcopy(curr.buf.content), ["single-refs"] = vim.deepcopy((curr.buf["source-refs"] or {})), meta = curr, ["project-bootstrap-pending"] = false, ["prompt-update-dirty"] = false, ["prompt-update-pending"] = false}
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
  vim.cmd("startinsert")
  local function _138_()
    session["startup-initializing"] = false
    return nil
  end
  vim.schedule(_138_)
  if (session["project-mode"] and not initial_query_active) then
    local function _139_()
      if (M["active-by-prompt"][session["prompt-buf"]] == session) then
        pcall(curr.refresh_statusline)
        return pcall(update_info_window, session)
      else
        return nil
      end
    end
    vim.schedule(_139_)
  else
  end
  if (session["project-mode"] and not session["project-bootstrapped"]) then
    project_source["schedule-project-bootstrap!"](session, session["project-bootstrap-delay-ms"])
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
    local function _144_()
      if (query and (query ~= "")) then
        return {query}
      else
        return {}
      end
    end
    meta["set-query-lines"](_144_())
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
