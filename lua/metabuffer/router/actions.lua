-- [nfnl] fnl/metabuffer/router/actions.fnl
local M = {}
local function session_by_prompt(active_by_prompt, prompt_buf)
  return active_by_prompt[prompt_buf]
end
local function clear_map_entry_21(tbl, key, expected)
  if (tbl and key and (tbl[key] == expected)) then
    tbl[key] = nil
    return nil
  else
    return nil
  end
end
local function clear_hit_highlight_21(curr)
  local matcher = curr.matcher()
  if matcher then
    return pcall(matcher["remove-highlight"], matcher)
  else
    return nil
  end
end
local function clear_buffer_modified_21(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    return pcall(vim.api.nvim_set_option_value, "modified", false, {buf = buf})
  else
    return nil
  end
end
local function restore_main_window_opts_21(session)
  local win = (session and session.meta and session.meta.win)
  if (win and win.window and vim.api.nvim_win_is_valid(win.window) and win.destroy) then
    return pcall(win.destroy)
  else
    return nil
  end
end
local function remove_session_21(deps, session)
  local router = deps.router
  local mods = deps.mods
  local windows = deps.windows
  local history = deps.history
  local history_api = history.api
  local sign_mod = mods.sign
  local router_util_mod = mods["router-util"]
  local info_window = windows.info
  local preview_window = windows.preview
  local context_window = windows.context
  local active_by_source = router["active-by-source"]
  local active_by_prompt = router["active-by-prompt"]
  local instances = router.instances
  if session then
    session.closing = true
    restore_main_window_opts_21(session)
    local or_5_ = session["last-prompt-text"]
    if not or_5_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_5_ = router_util_mod["prompt-text"](session)
      else
        or_5_ = ""
      end
    end
    history_api["push-history-entry!"](session, or_5_)
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
      clear_buffer_modified_21(session["prompt-buf"])
      pcall(vim.api.nvim_buf_delete, session["prompt-buf"], {force = true})
    else
    end
    if (session.meta and session.meta.buf and session.meta.buf.buffer) then
      clear_buffer_modified_21(session.meta.buf.buffer)
    else
    end
    info_window["close-window!"](session)
    preview_window["close-window!"](session)
    if (context_window and context_window["close-window!"]) then
      context_window["close-window!"](session)
    else
    end
    history_api["close-history-browser!"](session)
    if (sign_mod and session.meta and session.meta.buf and session.meta.buf.buffer) then
      sign_mod["clear-change-signs!"](session.meta.buf.buffer)
    else
    end
    clear_map_entry_21(active_by_source, session["source-buf"], session)
    if (session.meta and session.meta.buf and session.meta.buf.buffer) then
      clear_map_entry_21(active_by_source, session.meta.buf.buffer, session)
    else
    end
    clear_map_entry_21(active_by_prompt, session["prompt-buf"], session)
    if session["instance-id"] then
      clear_map_entry_21(instances, session["instance-id"], session)
    else
    end
    if (session["origin-win"] and vim.api.nvim_win_is_valid(session["origin-win"])) then
      return pcall(vim.api.nvim_win_del_var, session["origin-win"], "airline_disable_statusline")
    else
      return nil
    end
  else
    return nil
  end
end
local function apply_prompt_window_opts_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    pcall(vim.api.nvim_win_set_var, win, "airline_disable_statusline", 1)
    local wo = vim.wo[win]
    wo["winfixwidth"] = true
    wo["winfixheight"] = true
    wo["number"] = false
    wo["relativenumber"] = false
    wo["signcolumn"] = "no"
    wo["foldcolumn"] = "0"
    wo["statusline"] = " "
    wo["spell"] = false
    wo["wrap"] = true
    wo["linebreak"] = true
    return nil
  else
    return nil
  end
end
local function hide_session_ui_21(deps, session)
  local router = deps.router
  local mods = deps.mods
  local windows = deps.windows
  local history = deps.history
  local router_util_mod = mods["router-util"]
  local info_window = windows.info
  local preview_window = windows.preview
  local context_window = windows.context
  local history_api = history.api
  local active_by_source = router["active-by-source"]
  session["ui-hidden"] = true
  session["ui-last-insert-mode"] = vim.startswith(vim.api.nvim_get_mode().mode, "i")
  if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    do
      local ok,cur = pcall(vim.api.nvim_win_get_cursor, session["prompt-win"])
      if (ok and (type(cur) == "table")) then
        session["hidden-prompt-cursor"] = {(cur[1] or 1), (cur[2] or 0)}
      else
      end
    end
    router_util_mod["persist-prompt-height!"](session)
    session["hidden-prompt-height"] = vim.api.nvim_win_get_height(session["prompt-win"])
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local bo = vim.bo[session["prompt-buf"]]
      bo["bufhidden"] = "hide"
    else
    end
    clear_buffer_modified_21(session["prompt-buf"])
    pcall(vim.api.nvim_win_close, session["prompt-win"], true)
  else
  end
  session["prompt-win"] = nil
  if (session.meta and session.meta.buf and session.meta.buf.buffer) then
    clear_buffer_modified_21(session.meta.buf.buffer)
  else
  end
  info_window["close-window!"](session)
  preview_window["close-window!"](session)
  if (context_window and context_window["close-window!"]) then
    context_window["close-window!"](session)
  else
  end
  history_api["close-history-browser!"](session)
  if (session.meta and session.meta.buf and session.meta.buf.buffer) then
    active_by_source[session.meta.buf.buffer] = session
    return nil
  else
    return nil
  end
end
local function restore_session_ui_21(deps, session, opts)
  local mods = deps.mods
  local windows = deps.windows
  local refresh = deps.refresh
  local meta_window_mod = mods["meta-window"]
  local update_preview_window = refresh["preview!"]
  local sync_prompt_buffer_name_21 = refresh["sync-prompt-buffer-name!"]
  local router_util_mod = mods["router-util"]
  local update_info_window = refresh["info!"]
  local context_window = windows.context
  local preserve_focus_3f = (opts and opts["preserve-focus"])
  local curr = session.meta
  if (session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and curr and curr.win and vim.api.nvim_win_is_valid(curr.win.window)) then
    local height = (session["hidden-prompt-height"] or router_util_mod["prompt-height"]())
    local local_layout_3f
    if (session["window-local-layout"] == nil) then
      local_layout_3f = true
    else
      local_layout_3f = session["window-local-layout"]
    end
    local prompt_win
    if (local_layout_3f and vim.api.nvim_win_is_valid(curr.win.window)) then
      local function _25_()
        vim.cmd(("belowright " .. tostring(height) .. "new"))
        return vim.api.nvim_get_current_win()
      end
      prompt_win = vim.api.nvim_win_call(curr.win.window, _25_)
    else
      vim.cmd(("botright " .. tostring(height) .. "new"))
      prompt_win = vim.api.nvim_get_current_win()
    end
    session["prompt-win"] = prompt_win
    pcall(vim.api.nvim_win_set_height, prompt_win, height)
    pcall(vim.api.nvim_win_set_buf, prompt_win, session["prompt-buf"])
    do
      local bo = vim.bo[session["prompt-buf"]]
      bo["buftype"] = "nofile"
      bo["bufhidden"] = "hide"
      bo["swapfile"] = false
      bo["modifiable"] = true
      bo["filetype"] = "metabufferprompt"
    end
    apply_prompt_window_opts_21(prompt_win)
    sync_prompt_buffer_name_21(session)
    curr["status-win"] = meta_window_mod.new(vim, prompt_win)
    session["ui-hidden"] = false
    if (curr and curr.buf and curr.buf.buffer and vim.api.nvim_buf_is_valid(curr.buf.buffer)) then
      do
        local bo = vim.bo[curr.buf.buffer]
        curr.buf["keep-modifiable"] = true
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      end
      pcall(curr.buf.render)
    else
    end
    vim.cmd("silent! nohlsearch")
    do
      local cursor = (session["hidden-prompt-cursor"] or {1, 0})
      local row = math.max(1, (cursor[1] or 1))
      local col = math.max(0, (cursor[2] or 0))
      local line_count = math.max(1, vim.api.nvim_buf_line_count(session["prompt-buf"]))
      local row_2a = math.min(row, line_count)
      local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], (row_2a - 1), row_2a, false)[1] or "")
      local col_2a = math.min(col, #line)
      pcall(vim.api.nvim_win_set_cursor, prompt_win, {row_2a, col_2a})
    end
    pcall(curr.refresh_statusline)
    if update_preview_window then
      pcall(update_preview_window, session)
    else
    end
    pcall(update_info_window, session, true)
    if (context_window and context_window["update!"]) then
      pcall(context_window["update!"], session)
    else
    end
    if not preserve_focus_3f then
      vim.api.nvim_set_current_win(prompt_win)
      if session["ui-last-insert-mode"] then
        return vim.cmd("startinsert")
      else
        return vim.cmd("stopinsert")
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function finish_accept(deps, session)
  local router = deps.router
  local mods = deps.mods
  local history = deps.history
  local refresh = deps.refresh
  local active_by_prompt = router["active-by-prompt"]
  local router_prompt_mod = mods["router-prompt"]
  local sign_mod = mods.sign
  local router_util_mod = mods["router-util"]
  local session_view = mods["session-view"]
  local base_buffer = mods["base-buffer"]
  local history_api = history.api
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
  local wrapup = refresh.wrapup
  local curr = session.meta
  session["last-prompt-text"] = router_util_mod["prompt-text"](session)
  history_api["push-history-entry!"](session, session["last-prompt-text"])
  apply_prompt_lines(session)
  if session["project-mode"] then
    local _
    if vim.api.nvim_win_is_valid(curr.win.window) then
      _ = pcall(vim.api.nvim_set_current_win, curr.win.window)
    else
      _ = nil
    end
    local ref = router_util_mod["selected-ref"](curr)
    if (ref and ref.path) then
      do
        local path = (ref.path or "")
        local rel = vim.fn.fnamemodify(path, ":.")
        local target
        if ((type(rel) == "string") and (rel ~= "")) then
          target = rel
        else
          target = path
        end
        vim.cmd(("edit " .. vim.fn.fnameescape(target)))
      end
      vim.api.nvim_win_set_cursor(0, {math.max(1, (ref["open-lnum"] or ref.lnum or 1)), 0})
    else
    end
  else
    if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
      pcall(vim.api.nvim_set_current_win, session["origin-win"])
      pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
    else
    end
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
  if session["project-mode"] then
    pcall(vim.cmd, "stopinsert")
    clear_hit_highlight_21(curr)
    session["results-edit-mode"] = false
    hide_session_ui_21(deps, session)
  else
    local function _41_()
      if (active_by_prompt[session["prompt-buf"]] == session) then
        router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
        pcall(vim.cmd, "stopinsert")
        clear_hit_highlight_21(curr)
        if sign_mod then
          sign_mod["clear-change-signs!"](curr.buf.buffer)
        else
        end
        session_view["wipe-temp-buffers"](curr)
        remove_session_21(deps, session)
        return wrapup(curr)
      else
        return nil
      end
    end
    vim.schedule(_41_)
  end
  return curr
end
local function finish_cancel(deps, session)
  local mods = deps.mods
  local history = deps.history
  local refresh = deps.refresh
  local router_prompt_mod = mods["router-prompt"]
  local router_util_mod = mods["router-util"]
  local sign_mod = mods.sign
  local session_view = mods["session-view"]
  local base_buffer = mods["base-buffer"]
  local history_api = history.api
  local wrapup = refresh.wrapup
  local curr = session.meta
  router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
  session["last-prompt-text"] = router_util_mod["prompt-text"](session)
  history_api["push-history-entry!"](session, session["last-prompt-text"])
  pcall(vim.cmd, "stopinsert")
  clear_hit_highlight_21(curr)
  if sign_mod then
    sign_mod["clear-change-signs!"](curr.buf.buffer)
  else
  end
  vim.cmd("silent! nohlsearch")
  if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
    pcall(vim.api.nvim_set_current_win, session["origin-win"])
    pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
    if session["source-view"] then
      local function _46_()
        return pcall(vim.fn.winrestview, session["source-view"])
      end
      vim.api.nvim_win_call(session["origin-win"], _46_)
    else
    end
  else
  end
  base_buffer["switch-buf"](curr.buf.model)
  session_view["wipe-temp-buffers"](curr)
  remove_session_21(deps, session)
  wrapup(curr)
  return curr
end
M["finish!"] = function(deps, kind, prompt_buf)
  local router = deps.router
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    if (kind == "accept") then
      return finish_accept(deps, session)
    else
      return finish_cancel(deps, session)
    end
  else
    return nil
  end
end
M["accept!"] = function(deps, prompt_buf)
  local router = deps.router
  local history = deps.history
  local history_api = history.api
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if (session and session["history-browser-active"]) then
    return history_api["apply-history-browser-selection!"](session)
  else
    return M["finish!"](deps, "accept", prompt_buf)
  end
end
M["cancel!"] = function(deps, prompt_buf)
  local router = deps.router
  local history = deps.history
  local history_api = history.api
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if (session and session["history-browser-active"]) then
    return history_api["close-history-browser!"](session)
  else
    return M["finish!"](deps, "cancel", prompt_buf)
  end
end
M["accept-main!"] = function(deps, prompt_buf)
  return M["accept!"](deps, prompt_buf)
end
M["open-history-searchback!"] = function(deps, prompt_buf)
  local router = deps.router
  local history = deps.history
  local active_by_prompt = router["active-by-prompt"]
  local history_store = history.store
  local history_api = history.api
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if session then
    if not session["history-cache"] then
      session["history-cache"] = vim.deepcopy(history_store.list())
    else
    end
    return history_api["open-history-browser!"](session, "history")
  else
    return nil
  end
end
M["merge-history-cache!"] = function(deps, prompt_buf)
  local router = deps.router
  local history = deps.history
  local history_api = history.api
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    history_api["merge-history-into-session!"](session)
    return history_api["refresh-history-browser!"](session)
  else
    return nil
  end
end
local function append_current_symbol_21(deps, prompt_buf, f, opts)
  local router = deps.router
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local router_util_mod = mods["router-util"]
  local on_newline_3f = (opts and opts.newline)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if session then
    local word
    local function _56_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _56_)
    local token = f(word)
    if (token ~= "") then
      local current = router_util_mod["prompt-text"](session)
      local sep
      if on_newline_3f then
        if ((current == "") or vim.endswith(current, "\n")) then
          sep = ""
        else
          sep = "\n"
        end
      else
        if ((current == "") or vim.endswith(current, " ") or vim.endswith(current, "\n")) then
          sep = ""
        else
          sep = " "
        end
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
M["exclude-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _62_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return ("!" .. word)
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _62_)
end
M["insert-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _64_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _64_)
end
M["insert-symbol-under-cursor-newline!"] = function(deps, prompt_buf)
  local function _66_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _66_, {newline = true})
end
M["toggle-prompt-results-focus!"] = function(deps, prompt_buf)
  local router = deps.router
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    local meta_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local cur_win = vim.api.nvim_get_current_win()
    if (session["ui-hidden"] and session.meta and session.meta.buf and (vim.api.nvim_get_current_buf() == session.meta.buf.buffer)) then
      restore_session_ui_21(deps, session, {["preserve-focus"] = false})
      if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        pcall(vim.api.nvim_set_current_win, session["prompt-win"])
        return pcall(vim.cmd, "startinsert")
      else
        return nil
      end
    else
      if (prompt_win and vim.api.nvim_win_is_valid(prompt_win) and (cur_win == prompt_win)) then
        if (meta_win and vim.api.nvim_win_is_valid(meta_win)) then
          pcall(vim.api.nvim_set_current_win, meta_win)
        else
        end
        return pcall(vim.cmd, "stopinsert")
      else
        if (prompt_win and vim.api.nvim_win_is_valid(prompt_win)) then
          pcall(vim.api.nvim_set_current_win, prompt_win)
          return pcall(vim.cmd, "startinsert")
        else
          return nil
        end
      end
    end
  else
    return nil
  end
end
M["toggle-scan-option!"] = function(deps, prompt_buf, which)
  local router = deps.router
  local project = deps.project
  local refresh = deps.refresh
  local project_source = project.source
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
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
M["toggle-project-mode!"] = function(deps, prompt_buf)
  local router = deps.router
  local mods = deps.mods
  local refresh = deps.refresh
  local project = deps.project
  local router_util_mod = mods["router-util"]
  local sync_prompt_buffer_name_21 = refresh["sync-prompt-buffer-name!"]
  local project_source = project.source
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
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
M["toggle-info-file-entry-view!"] = function(deps, prompt_buf)
  local router = deps.router
  local refresh = deps.refresh
  local update_info_window = refresh["info!"]
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    if ((session["info-file-entry-view"] or "meta") == "content") then
      session["info-file-entry-view"] = "meta"
    else
      session["info-file-entry-view"] = "content"
    end
    session["info-render-sig"] = nil
    return pcall(update_info_window, session, true)
  else
    return nil
  end
end
M["remove-session!"] = function(deps, session)
  return remove_session_21(deps, session)
end
M["on-results-buffer-wipe!"] = function(deps, results_buf)
  local router = deps.router
  local history = deps.history
  local mods = deps.mods
  local windows = deps.windows
  local active_by_source = router["active-by-source"]
  local history_api = history.api
  local router_util_mod = mods["router-util"]
  local info_window = windows.info
  local preview_window = windows.preview
  local instances = router.instances
  local active_by_prompt = router["active-by-prompt"]
  local session = active_by_source[results_buf]
  if (session and not session._results_wiped) then
    session._results_wiped = true
    session.closing = true
    restore_main_window_opts_21(session)
    local or_80_ = session["last-prompt-text"]
    if not or_80_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_80_ = router_util_mod["prompt-text"](session)
      else
        or_80_ = ""
      end
    end
    history_api["push-history-entry!"](session, or_80_)
    router_util_mod["persist-prompt-height!"](session)
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
    history_api["close-history-browser!"](session)
    clear_map_entry_21(active_by_source, session["source-buf"], session)
    clear_map_entry_21(active_by_source, results_buf, session)
    clear_map_entry_21(active_by_prompt, session["prompt-buf"], session)
    if session["instance-id"] then
      return clear_map_entry_21(instances, session["instance-id"], session)
    else
      return nil
    end
  else
    return nil
  end
end
local function set_results_edit_buffer_21(session)
  local buf = session.meta.buf.buffer
  local bo = vim.bo[buf]
  bo["buftype"] = "acwrite"
  bo["bufhidden"] = "hide"
  bo["modifiable"] = true
  bo["readonly"] = false
  return pcall(vim.api.nvim_set_option_value, "modified", false, {buf = buf})
end
local function ensure_session_for_results_buf_21(deps, session)
  local router = deps.router
  local active_by_source = router["active-by-source"]
  local buf = session.meta.buf.buffer
  active_by_source[buf] = session
  return nil
end
local function diff_hunks(old_lines, new_lines)
  local old_text = table.concat((old_lines or {}), "\n")
  local new_text = table.concat((new_lines or {}), "\n")
  local ok,out = pcall(vim.diff, old_text, new_text, {result_type = "indices", algorithm = "histogram"})
  if (ok and (type(out) == "table")) then
    return out
  else
    return {}
  end
end
local function hunk_indices(h)
  return {(h[1] or 1), (h[2] or 0), (h[3] or 1), (h[4] or 0)}
end
local function slice_lines(lines, start, count)
  local out = {}
  for i = start, (start + count + -1) do
    if ((i >= 1) and (i <= #lines)) then
      table.insert(out, lines[i])
    else
    end
  end
  return out
end
local function clone_row_with_text(row, text)
  local r = vim.deepcopy((row or {}))
  r["text"] = (text or "")
  r["line"] = (text or "")
  return r
end
local function inserted_row(prev_row, next_row, text, rel_index)
  local base = (prev_row or next_row or {})
  local out = vim.deepcopy(base)
  local prev_lnum = ((prev_row and prev_row.lnum) or base.lnum or 1)
  local next_lnum = ((next_row and next_row.lnum) or base.lnum or (prev_lnum + 1))
  local lnum
  if prev_row then
    lnum = (prev_lnum + rel_index)
  else
    lnum = math.max(1, (next_lnum - 1))
  end
  out["lnum"] = math.max(1, (lnum or 1))
  out["text"] = (text or "")
  out["line"] = (text or "")
  return out
end
local function projected_rows_from_edits(baseline_rows, baseline_lines, current_lines)
  local hunks = diff_hunks(baseline_lines, current_lines)
  local out = {}
  local idx = {old = 1, new = 1}
  for _, h in ipairs(hunks) do
    local _let_89_ = hunk_indices(h)
    local a_start = _let_89_[1]
    local a_count = _let_89_[2]
    local b_start = _let_89_[3]
    local b_count = _let_89_[4]
    local common = math.min(a_count, b_count)
    while (idx.old < a_start) do
      local txt = (current_lines[idx.new] or "")
      table.insert(out, clone_row_with_text(baseline_rows[idx.old], txt))
      idx["old"] = (idx.old + 1)
      idx["new"] = (idx.new + 1)
    end
    for k = 1, common do
      local txt = (current_lines[(b_start + k + -1)] or "")
      table.insert(out, clone_row_with_text(baseline_rows[(a_start + k + -1)], txt))
    end
    if (b_count > a_count) then
      local extra = (b_count - common)
      local prev_row
      if ((a_start + common + -1) > 0) then
        prev_row = baseline_rows[(a_start + common + -1)]
      else
        prev_row = nil
      end
      local next_row = baseline_rows[(a_start + common)]
      for k = 1, extra do
        local txt = (current_lines[(b_start + common + k + -1)] or "")
        table.insert(out, inserted_row(prev_row, next_row, txt, k))
      end
    else
    end
    idx["old"] = (a_start + a_count)
    idx["new"] = (b_start + b_count)
  end
  while (idx.old <= #baseline_rows) do
    local txt = (current_lines[idx.new] or "")
    table.insert(out, clone_row_with_text(baseline_rows[idx.old], txt))
    idx["old"] = (idx.old + 1)
    idx["new"] = (idx.new + 1)
  end
  return out
end
local function apply_live_edits_to_meta_21(session, current_lines)
  local meta = session.meta
  local baseline_lines = (session["edit-baseline-lines"] or {})
  local baseline_rows = (session["edit-baseline-rows"] or {})
  local rows = projected_rows_from_edits(baseline_rows, baseline_lines, current_lines)
  local refs = {}
  local content = {}
  local idxs = {}
  for i = 1, #rows do
    local row = (rows[i] or {})
    refs[i] = {kind = (row.kind or ""), path = (row.path or ""), lnum = (row.lnum or 1), ["open-lnum"] = (row["open-lnum"] or row.lnum or 1), line = (row.text or row.line or "")}
    content[i] = (row.text or row.line or "")
    idxs[i] = i
  end
  meta.buf["source-refs"] = refs
  meta.buf.content = content
  meta.buf.indices = idxs
  local max = math.max(1, #idxs)
  meta.selected_index = math.max(0, math.min((meta.selected_index or 0), (max - 1)))
  return nil
end
local function valid_row_3f(row)
  return (row and (type(row.path) == "string") and (row.path ~= "") and (type(row.lnum) == "number") and (row.lnum > 0) and (row.kind ~= "file-entry"))
end
local function append_op_21(ops, path, op)
  local per_file = (ops[path] or {})
  table.insert(per_file, op)
  ops[path] = per_file
  return nil
end
local function collect_file_ops(session)
  local meta = session.meta
  local buf = meta.buf.buffer
  local baseline_lines = (session["edit-baseline-lines"] or vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  local baseline_rows = (session["edit-baseline-rows"] or {})
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = diff_hunks(baseline_lines, current_lines)
  local ops = {}
  for _, h in ipairs(hunks) do
    local _let_92_ = hunk_indices(h)
    local a_start = _let_92_[1]
    local a_count = _let_92_[2]
    local b_start = _let_92_[3]
    local b_count = _let_92_[4]
    local common = math.min(a_count, b_count)
    local old_rows = slice_lines(baseline_rows, a_start, a_count)
    local new_lines = slice_lines(current_lines, b_start, b_count)
    if (a_count > 0) then
      for i = 1, common do
        local row = old_rows[i]
        local text = (new_lines[i] or "")
        if (valid_row_3f(row) and ((row.text or "") ~= text)) then
          append_op_21(ops, row.path, {kind = "replace", lnum = row.lnum, text = text})
        else
        end
      end
      if (a_count > b_count) then
        for i = (common + 1), a_count do
          local row = old_rows[i]
          if valid_row_3f(row) then
            append_op_21(ops, row.path, {kind = "delete", lnum = row.lnum})
          else
          end
        end
      else
      end
      if (b_count > a_count) then
        local extra = slice_lines(new_lines, (common + 1), (b_count - common))
        local anchor_row = old_rows[a_count]
        if (valid_row_3f(anchor_row) and (#extra > 0)) then
          append_op_21(ops, anchor_row.path, {kind = "insert-after", lnum = anchor_row.lnum, lines = extra})
        else
        end
      else
      end
    else
      local extra = slice_lines(new_lines, 1, b_count)
      local prev_row = baseline_rows[(a_start - 1)]
      local next_row = baseline_rows[a_start]
      if (#extra > 0) then
        if valid_row_3f(prev_row) then
          append_op_21(ops, prev_row.path, {kind = "insert-after", lnum = prev_row.lnum, lines = extra})
        else
          if valid_row_3f(next_row) then
            append_op_21(ops, next_row.path, {kind = "insert-before", lnum = next_row.lnum, lines = extra})
          else
          end
        end
      else
      end
    end
  end
  return {ops = ops, ["current-lines"] = current_lines}
end
local function apply_file_ops_21(ops)
  local post_lines = {}
  local touched_paths = {}
  local total = 0
  local any_write = false
  local function apply_op_to_loaded_buffer_21(buf, op, delta)
    if (op.kind == "replace") then
      local lnum = (op.lnum + delta)
      local line_count = vim.api.nvim_buf_line_count(buf)
      if ((lnum >= 1) and (lnum <= line_count)) then
        local old = (vim.api.nvim_buf_get_lines(buf, (lnum - 1), lnum, false)[1] or "")
        local new = (op.text or "")
        if (old ~= new) then
          vim.api.nvim_buf_set_lines(buf, (lnum - 1), lnum, false, {new})
          return {delta, 1}
        else
          return {delta, 0}
        end
      else
        return {delta, 0}
      end
    elseif (op.kind == "delete") then
      local lnum = (op.lnum + delta)
      local line_count = vim.api.nvim_buf_line_count(buf)
      if ((lnum >= 1) and (lnum <= line_count)) then
        vim.api.nvim_buf_set_lines(buf, (lnum - 1), lnum, false, {})
        return {(delta - 1), 1}
      else
        return {delta, 0}
      end
    elseif (op.kind == "insert-before") then
      local ins = (op.lines or {})
      local lnum = (op.lnum + delta)
      local pos = math.max(1, math.min((vim.api.nvim_buf_line_count(buf) + 1), lnum))
      if (#ins > 0) then
        vim.api.nvim_buf_set_lines(buf, (pos - 1), (pos - 1), false, ins)
        return {(delta + #ins), #ins}
      else
        return {delta, 0}
      end
    else
      local ins = (op.lines or {})
      local lnum = (op.lnum + delta)
      local pos = math.max(0, math.min(vim.api.nvim_buf_line_count(buf), lnum))
      if (#ins > 0) then
        vim.api.nvim_buf_set_lines(buf, pos, pos, false, ins)
        return {(delta + #ins), #ins}
      else
        return {delta, 0}
      end
    end
  end
  local function apply_op_to_lines_21(lines, op, delta)
    if (op.kind == "replace") then
      local lnum = (op.lnum + delta)
      if ((lnum >= 1) and (lnum <= #lines) and (lines[lnum] ~= op.text)) then
        lines[lnum] = op.text
        return {delta, 1}
      else
        return {delta, 0}
      end
    elseif (op.kind == "delete") then
      local lnum = (op.lnum + delta)
      if ((lnum >= 1) and (lnum <= #lines)) then
        table.remove(lines, lnum)
        return {(delta - 1), 1}
      else
        return {delta, 0}
      end
    elseif (op.kind == "insert-before") then
      local ins = (op.lines or {})
      local lnum = (op.lnum + delta)
      local pos = math.max(1, math.min((#lines + 1), lnum))
      if (#ins > 0) then
        for i = 1, #ins do
          table.insert(lines, (pos + i + -1), ins[i])
        end
        return {(delta + #ins), #ins}
      else
        return {delta, 0}
      end
    else
      local ins = (op.lines or {})
      local lnum = (op.lnum + delta)
      local pos = math.max(0, math.min(#lines, lnum))
      if (#ins > 0) then
        for i = 1, #ins do
          table.insert(lines, (pos + i), ins[i])
        end
        return {(delta + #ins), #ins}
      else
        return {delta, 0}
      end
    end
  end
  for path, per_file in pairs((ops or {})) do
    local bufnr = vim.fn.bufnr(path)
    if (bufnr and (bufnr > 0) and vim.api.nvim_buf_is_loaded(bufnr)) then
      local bo = vim.bo[bufnr]
      local old_mod = bo.modifiable
      local old_ro = bo.readonly
      bo["modifiable"] = true
      bo["readonly"] = false
      local delta = 0
      local changed = 0
      for _, op in ipairs((per_file or {})) do
        local _let_113_ = apply_op_to_loaded_buffer_21(bufnr, op, delta)
        local next_delta = _let_113_[1]
        local bump = _let_113_[2]
        delta = next_delta
        changed = (changed + bump)
      end
      bo["modifiable"] = old_mod
      bo["readonly"] = old_ro
      if (changed > 0) then
        local function _114_()
          return vim.cmd("silent keepalt noautocmd write")
        end
        local ok_write = pcall(vim.api.nvim_buf_call, bufnr, _114_)
        if ok_write then
          any_write = true
          total = (total + changed)
          touched_paths[path] = true
          post_lines[path] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        else
          local ok_read,lines0 = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
          if (ok_read and (type(lines0) == "table")) then
            local ok_fallback = pcall(vim.fn.writefile, lines0, path)
            if ok_fallback then
              any_write = true
              total = (total + changed)
              touched_paths[path] = true
              post_lines[path] = lines0
            else
            end
          else
          end
        end
      else
      end
    else
      local ok_read,lines0 = pcall(vim.fn.readfile, path)
      if (ok_read and (type(lines0) == "table")) then
        local lines = vim.deepcopy(lines0)
        local delta = 0
        local changed = 0
        for _, op in ipairs((per_file or {})) do
          local _let_119_ = apply_op_to_lines_21(lines, op, delta)
          local next_delta = _let_119_[1]
          local bump = _let_119_[2]
          delta = next_delta
          changed = (changed + bump)
        end
        if (changed > 0) then
          local ok_write = pcall(vim.fn.writefile, lines, path)
          if ok_write then
            any_write = true
            total = (total + changed)
            touched_paths[path] = true
            post_lines[path] = lines
          else
          end
        else
        end
      else
      end
    end
  end
  return {wrote = any_write, changed = total, ["post-lines"] = post_lines, paths = touched_paths}
end
local function update_session_refs_after_ops_21(session, ops, post_lines)
  local meta = session.meta
  local refs = (meta.buf["source-refs"] or {})
  local content = (meta.buf.content or {})
  for src_idx, ref in ipairs(refs) do
    if (ref and (type(ref.path) == "string") and (ref.path ~= "")) then
      local path = ref.path
      local per_file = ops[path]
      if per_file then
        local lnum0
        if ((type(ref.lnum) == "number") and (ref.lnum > 0)) then
          lnum0 = ref.lnum
        else
          lnum0 = 1
        end
        local lnum = lnum0
        for _, op in ipairs(per_file) do
          if (op.kind == "insert-before") then
            if (lnum >= op.lnum) then
              lnum = (lnum + #(op.lines or {}))
            else
            end
          elseif (op.kind == "insert-after") then
            if (lnum > op.lnum) then
              lnum = (lnum + #(op.lines or {}))
            else
            end
          elseif (op.kind == "delete") then
            if (lnum > op.lnum) then
              lnum = (lnum - 1)
            else
            end
          else
          end
        end
        if (lnum < 1) then
          lnum = 1
        else
        end
        ref["lnum"] = lnum
        local lines = post_lines[path]
        local line = ((lines and (lnum >= 1) and (lnum <= #lines) and lines[lnum]) or ref.line or "")
        ref["line"] = line
        if src_idx then
          content[src_idx] = line
        else
        end
      else
      end
    else
    end
  end
  meta.buf.content = content
  return nil
end
local function invalidate_caches_for_paths_21(deps, session, updates)
  local router = deps.router
  local project_file_cache = (router and router["project-file-cache"])
  local preview_file_cache = (session["preview-file-cache"] or {})
  local info_file_head_cache = (session["info-file-head-cache"] or {})
  local info_file_meta_cache = (session["info-file-meta-cache"] or {})
  session["preview-file-cache"] = preview_file_cache
  session["info-file-head-cache"] = info_file_head_cache
  session["info-file-meta-cache"] = info_file_meta_cache
  for path, _ in pairs((updates or {})) do
    if project_file_cache then
      project_file_cache[path] = nil
    else
    end
    preview_file_cache[path] = nil
    info_file_head_cache[path] = nil
    info_file_meta_cache[path] = nil
  end
  return nil
end
M["write-results!"] = function(deps, prompt_buf)
  local router = deps.router
  local mods = deps.mods
  local refresh = deps.refresh
  local windows = deps.windows
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  local sign_mod = mods.sign
  local update_info_window = refresh["info!"]
  local preview_window = windows.preview
  local context_window = windows.context
  if session then
    local collected = collect_file_ops(session)
    local ops = collected.ops
    local result = apply_file_ops_21(ops)
    local buf = session.meta.buf.buffer
    update_session_refs_after_ops_21(session, ops, result["post-lines"])
    invalidate_caches_for_paths_21(deps, session, result.paths)
    if (result.changed > 0) then
      pcall(session.meta["on-update"], 0)
    else
    end
    pcall(vim.api.nvim_set_option_value, "modified", false, {buf = buf})
    pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", false)
    pcall(session.meta.refresh_statusline)
    pcall(update_info_window, session, true)
    pcall(preview_window["maybe-update-for-selection!"], session)
    if (context_window and context_window["update!"]) then
      pcall(context_window["update!"], session)
    else
    end
    if sign_mod then
      pcall(sign_mod["capture-baseline!"], session)
      pcall(sign_mod["refresh-change-signs!"], session)
    else
    end
    local _137_
    if (result.changed > 0) then
      _137_ = ("metabuffer: wrote " .. tostring(result.changed) .. " change(s)")
    else
      _137_ = "metabuffer: no changes"
    end
    return vim.notify(_137_, vim.log.levels.INFO)
  else
    return nil
  end
end
M["enter-edit-mode!"] = function(deps, prompt_buf)
  local router = deps.router
  local mods = deps.mods
  local history = deps.history
  local refresh = deps.refresh
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  local router_util_mod = mods["router-util"]
  local history_api = history.api
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
  if session then
    session["last-prompt-text"] = router_util_mod["prompt-text"](session)
    history_api["push-history-entry!"](session, session["last-prompt-text"])
    apply_prompt_lines(session)
    session["results-edit-mode"] = true
    hide_session_ui_21(deps, session)
    ensure_session_for_results_buf_21(deps, session)
    set_results_edit_buffer_21(session)
    if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      pcall(vim.api.nvim_set_current_win, session.meta.win.window)
      pcall(vim.api.nvim_win_set_buf, session.meta.win.window, session.meta.buf.buffer)
    else
    end
    return pcall(vim.cmd, "stopinsert")
  else
    return nil
  end
end
M["hide-visible-ui!"] = function(deps, prompt_buf)
  local router = deps.router
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if (session and not session["ui-hidden"] and not session.closing) then
    session["results-edit-mode"] = false
    hide_session_ui_21(deps, session)
    return pcall(vim.cmd, "stopinsert")
  else
    return nil
  end
end
M["sync-live-edits!"] = function(deps, prompt_buf)
  local router = deps.router
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if (session and session.meta and session.meta.buf) then
    local buf = session.meta.buf.buffer
    local manual_3f
    do
      local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_manual_edit_active")
      manual_3f = (ok and v)
    end
    if (manual_3f and vim.api.nvim_buf_is_valid(buf)) then
      local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      return apply_live_edits_to_meta_21(session, current_lines)
    else
      return nil
    end
  else
    return nil
  end
end
M["maybe-restore-ui!"] = function(deps, prompt_buf, force)
  local router = deps.router
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if (session and session["ui-hidden"] and (force or not session["results-edit-mode"]) and session.meta and session.meta.buf and (vim.api.nvim_get_current_buf() == session.meta.buf.buffer)) then
    session.meta.win.window = vim.api.nvim_get_current_win()
    return restore_session_ui_21(deps, session, {["preserve-focus"] = not force})
  else
    return nil
  end
end
return M
