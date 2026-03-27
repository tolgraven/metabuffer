-- [nfnl] fnl/metabuffer/router/actions.fnl
local M = {}
local util = require("metabuffer.util")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
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
local function silent_win_set_buf_21(win, buf)
  if (win and buf and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    local function _3_()
      return vim.cmd(("silent keepalt noautocmd buffer " .. buf))
    end
    return (pcall(vim.api.nvim_win_call, win, _3_) or pcall(vim.api.nvim_win_set_buf, win, buf))
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
local function destroy_window_wrapper_21(wrapper)
  if (wrapper and wrapper.window and vim.api.nvim_win_is_valid(wrapper.window) and wrapper.destroy) then
    return pcall(wrapper.destroy)
  else
    return nil
  end
end
local function restore_window_wrapper_opts_21(wrapper)
  if (wrapper and wrapper.window and vim.api.nvim_win_is_valid(wrapper.window) and wrapper["restore-opts"]) then
    return pcall(wrapper["restore-opts"])
  else
    return nil
  end
end
local function apply_window_wrapper_opts_21(wrapper, opts)
  if (wrapper and wrapper.window and vim.api.nvim_win_is_valid(wrapper.window) and wrapper["apply-opts"]) then
    return pcall(wrapper["apply-opts"], opts)
  else
    return nil
  end
end
local function restore_main_window_opts_21(session)
  local main_win = (session and session.meta and session.meta.win)
  local status_win = (session and session.meta and session.meta["status-win"])
  destroy_window_wrapper_21(main_win)
  if (status_win and (status_win ~= main_win)) then
    return destroy_window_wrapper_21(status_win)
  else
    return nil
  end
end
local function suspend_main_window_opts_21(session)
  local main_win = (session and session.meta and session.meta.win)
  local status_win = (session and session.meta and session.meta["status-win"])
  restore_window_wrapper_opts_21(main_win)
  if (status_win and (status_win ~= main_win)) then
    restore_window_wrapper_opts_21(status_win)
  else
  end
  for _, win in ipairs({(main_win and main_win.window), (status_win and status_win.window)}) do
    if (win and vim.api.nvim_win_is_valid(win)) then
      events.send("on-win-teardown!", {win = win, role = "main"})
    else
    end
  end
  return nil
end
local function resume_main_window_opts_21(deps, session)
  local meta_window_mod = deps.mods["meta-window"]
  local opts = ((meta_window_mod and meta_window_mod["default-opts"]) or {})
  local main_win = (session and session.meta and session.meta.win)
  local status_win = (session and session.meta and session.meta["status-win"])
  apply_window_wrapper_opts_21(main_win, opts)
  if (status_win and (status_win ~= main_win)) then
    apply_window_wrapper_opts_21(status_win, opts)
  else
  end
  for _, win in ipairs({(main_win and main_win.window), (status_win and status_win.window)}) do
    if (win and vim.api.nvim_win_is_valid(win)) then
      events.send("on-win-create!", {win = win, role = "main"})
    else
    end
  end
  return nil
end
local function restore_managed_buffer_effects_21(session)
  if session then
    for _, _14_ in ipairs({{(session.meta and session.meta.buf and session.meta.buf.buffer), "meta"}, {session["prompt-buf"], "prompt"}, {session["info-buf"], "info"}, {session["preview-buf"], "preview"}, {session["history-browser-buf"], "history-browser"}}) do
      local buf = _14_[1]
      local role = _14_[2]
      events.send("on-buf-teardown!", {buf = buf, role = role})
    end
    for _, buf in pairs((session["ts-expand-bufs"] or {})) do
      events.send("on-buf-teardown!", {buf = buf, role = "context"})
    end
    return nil
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
local function remove_session_21(deps, session)
  local router = deps.router
  local mods = deps.mods
  local windows = deps.windows
  local history = deps.history
  local history_api = history.api
  local sign_mod = mods.sign
  local animation_mod = mods.animation
  local router_util_mod = mods["router-util"]
  local info_window = windows.info
  local preview_window = windows.preview
  local context_window = windows.context
  local active_by_source = router["active-by-source"]
  local active_by_prompt = router["active-by-prompt"]
  local instances = router.instances
  if session then
    session.closing = true
    events.send("on-session-stop!", {session = session})
    if (animation_mod and animation_mod["unmark-mini-session!"]) then
      animation_mod["unmark-mini-session!"](session)
    else
    end
    if (animation_mod and animation_mod["cancel-session!"]) then
      animation_mod["cancel-session!"](session)
    else
    end
    restore_startup_cursor_21(session)
    restore_managed_buffer_effects_21(session)
    restore_main_window_opts_21(session)
    local or_19_ = session["last-prompt-text"]
    if not or_19_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_19_ = router_util_mod["prompt-text"](session)
      else
        or_19_ = ""
      end
    end
    history_api["push-history-entry!"](session, or_19_)
    router_util_mod["persist-prompt-height!"](session)
    router_util_mod["persist-results-wrap!"](session)
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
      return events.send("on-win-teardown!", {win = session["origin-win"], role = "origin"})
    else
      return nil
    end
  else
    return nil
  end
end
local prompt_window_opts = {winfixwidth = true, winfixheight = true, signcolumn = "no", foldcolumn = "0", statusline = " ", wrap = true, linebreak = true, number = false, relativenumber = false, spell = false}
local function apply_prompt_window_opts_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    events.send("on-win-create!", {win = win, role = "prompt"})
    for name, value in pairs(prompt_window_opts) do
      pcall(vim.api.nvim_set_option_value, name, value, {win = win})
    end
    return nil
  else
    return nil
  end
end
local function wipe_replaced_split_buffer_21(old_buf)
  if (old_buf and vim.api.nvim_buf_is_valid(old_buf)) then
    return util["delete-transient-unnamed-buffer!"](old_buf)
  else
    return nil
  end
end
local function handoff_host_window_21(win, buf)
  if (win and buf and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    local function _33_()
      pcall(vim.api.nvim_exec_autocmds, "BufWinEnter", {buffer = buf, modeline = false})
      pcall(vim.api.nvim_exec_autocmds, "BufEnter", {buffer = buf, modeline = false})
      pcall(vim.api.nvim_exec_autocmds, "WinEnter", {modeline = false})
      return pcall(vim.cmd, "redraw!")
    end
    return pcall(vim.api.nvim_win_call, win, _33_)
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
  local animation_mod = mods.animation
  local info_window = windows.info
  local preview_window = windows.preview
  local context_window = windows.context
  local history_api = history.api
  local active_by_source = router["active-by-source"]
  session["ui-hidden"] = true
  session["_last-prompt-statusline"] = nil
  if (animation_mod and animation_mod["cancel-session!"]) then
    animation_mod["cancel-session!"](session)
  else
  end
  restore_startup_cursor_21(session)
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
    router_util_mod["persist-results-wrap!"](session)
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
  suspend_main_window_opts_21(session)
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
  local update_preview_window = refresh["preview!"]
  local sync_prompt_buffer_name_21 = refresh["sync-prompt-buffer-name!"]
  local router_util_mod = mods["router-util"]
  local session_view_mod = mods["session-view"]
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
      local function _43_()
        vim.cmd(("belowright " .. tostring(height) .. "new"))
        return vim.api.nvim_get_current_win()
      end
      prompt_win = vim.api.nvim_win_call(curr.win.window, _43_)
    else
      vim.cmd(("botright " .. tostring(height) .. "new"))
      prompt_win = vim.api.nvim_get_current_win()
    end
    local old_buf = (prompt_win and vim.api.nvim_win_is_valid(prompt_win) and vim.api.nvim_win_get_buf(prompt_win))
    session["prompt-win"] = prompt_win
    util["mark-transient-unnamed-buffer!"](old_buf)
    pcall(vim.api.nvim_win_set_height, prompt_win, height)
    pcall(vim.api.nvim_win_set_buf, prompt_win, session["prompt-buf"])
    wipe_replaced_split_buffer_21(old_buf)
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
    session["_last-prompt-statusline"] = nil
    curr["status-win"] = curr.win
    session["ui-hidden"] = false
    resume_main_window_opts_21(deps, session)
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
    if (session_view_mod and session["source-view"]) then
      pcall(session_view_mod["restore-meta-view!"], curr, session["source-view"], session, update_info_window)
    else
    end
    events.send("on-restore-ui!", {session = session})
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
  local mods = deps.mods
  local history = deps.history
  local refresh = deps.refresh
  local router_util_mod = mods["router-util"]
  local base_buffer = mods["base-buffer"]
  local history_api = history.api
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
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
        local rel = vim.fn.fnamemodify(path, ":~:.")
        local target
        if ((type(rel) == "string") and (rel ~= "")) then
          target = rel
        else
          target = path
        end
        vim.cmd(("edit " .. vim.fn.fnameescape(target)))
      end
      vim.api.nvim_win_set_cursor(0, {math.max(1, (ref["open-lnum"] or ref.lnum or 1)), 0})
      vim.cmd("normal! ^")
    else
    end
  else
    local row = curr.selected_line()
    local vq = curr.vim_query()
    local target_buf = curr.buf.model
    local target_win = session["origin-win"]
    if (target_win and vim.api.nvim_win_is_valid(target_win) and target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
      silent_win_set_buf_21(target_win, target_buf)
      local function _55_()
        pcall(vim.api.nvim_win_set_cursor, target_win, {row, 0})
        if (vq ~= "") then
          local pos = vim.fn.searchpos(vq, "cnW", row)
          local hit_row = pos[1]
          local hit_col = pos[2]
          if ((hit_row == row) and (hit_col > 0)) then
            return pcall(vim.api.nvim_win_set_cursor, target_win, {row, hit_col})
          else
            return nil
          end
        else
          return pcall(vim.cmd, "normal! ^")
        end
      end
      vim.api.nvim_win_call(target_win, _55_)
      pcall(vim.api.nvim_set_current_win, target_win)
      base_buffer["switch-buf"](target_buf)
    else
    end
  end
  vim.cmd("normal! zv")
  do
    local vq = curr.vim_query()
    if (vq ~= "") then
      vim.fn.setreg("/", vq)
    else
    end
  end
  events.send("on-accept!", {session = session})
  pcall(vim.cmd, "stopinsert")
  clear_hit_highlight_21(curr)
  session["results-edit-mode"] = false
  hide_session_ui_21(deps, session)
  return curr
end
local function finish_cancel(deps, session)
  local mods = deps.mods
  local history = deps.history
  local router_prompt_mod = mods["router-prompt"]
  local router_util_mod = mods["router-util"]
  local sign_mod = mods.sign
  local history_api = history.api
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
  events.send("on-cancel!", {session = session})
  if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
    pcall(vim.api.nvim_set_current_win, session["origin-win"])
    pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
    if session["source-view"] then
      local function _62_()
        return pcall(vim.fn.winrestview, session["source-view"])
      end
      vim.api.nvim_win_call(session["origin-win"], _62_)
    else
    end
  else
  end
  session["results-edit-mode"] = false
  hide_session_ui_21(deps, session)
  handoff_host_window_21(session["origin-win"], session["origin-buf"])
  if session["source-view"] then
    local view = session["source-view"]
    local win = session["origin-win"]
    local function _65_()
      if vim.api.nvim_win_is_valid(win) then
        local function _66_()
          return pcall(vim.fn.winrestview, view)
        end
        return vim.api.nvim_win_call(win, _66_)
      else
        return nil
      end
    end
    vim.schedule(_65_)
  else
  end
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
    local function _76_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _76_)
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
  local function _82_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return ("!" .. word)
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _82_)
end
M["insert-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _84_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _84_)
end
M["insert-symbol-under-cursor-newline!"] = function(deps, prompt_buf)
  local function _86_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _86_, {newline = true})
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
    local or_100_ = session["last-prompt-text"]
    if not or_100_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_100_ = router_util_mod["prompt-text"](session)
      else
        or_100_ = ""
      end
    end
    history_api["push-history-entry!"](session, or_100_)
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
local function consecutive_same_source_3f(prev_row, next_row)
  return (prev_row and next_row and (type(prev_row.path) == "string") and (type(next_row.path) == "string") and (prev_row.path ~= "") and (next_row.path ~= "") and (type(prev_row.lnum) == "number") and (type(next_row.lnum) == "number") and (prev_row.path == next_row.path) and ((prev_row.lnum + 1) == next_row.lnum))
end
local function inserted_row(session, prev_row, next_row, text, rel_index)
  local base = (prev_row or next_row or {})
  local out = vim.deepcopy(base)
  local prev_lnum = ((prev_row and prev_row.lnum) or base.lnum or 1)
  local next_lnum = ((next_row and next_row.lnum) or base.lnum or (prev_lnum + 1))
  local pending = (session["pending-structural-edit"] or {})
  local pending_side = pending.side
  local pending_path = pending.path
  local pending_lnum = pending.lnum
  local lnum
  if consecutive_same_source_3f(prev_row, next_row) then
    lnum = (prev_lnum + rel_index)
  else
    if ((pending_side == "after") and prev_row and (pending_path == prev_row.path) and (pending_lnum == prev_row.lnum)) then
      lnum = (pending_lnum + rel_index)
    else
      if ((pending_side == "before") and next_row and (pending_path == next_row.path) and (pending_lnum == next_row.lnum)) then
        lnum = (pending_lnum + rel_index + -1)
      else
        if prev_row then
          lnum = (prev_lnum + rel_index)
        else
          lnum = math.max(1, (next_lnum - 1))
        end
      end
    end
  end
  out["lnum"] = math.max(1, (lnum or 1))
  out["text"] = (text or "")
  out["line"] = (text or "")
  if consecutive_same_source_3f(prev_row, next_row) then
    out["insert-path"] = prev_row.path
    out["insert-lnum"] = prev_row.lnum
    out["insert-side"] = "after"
  else
    if ((pending_side == "after") and prev_row and (type(prev_row.path) == "string") and (prev_row.path ~= "") and (type(prev_row.lnum) == "number") and (pending_path == prev_row.path) and (pending_lnum == prev_row.lnum)) then
      out["insert-path"] = prev_row.path
      out["insert-lnum"] = prev_row.lnum
      out["insert-side"] = "after"
    else
    end
    if ((pending_side == "before") and next_row and (type(next_row.path) == "string") and (next_row.path ~= "") and (type(next_row.lnum) == "number") and (pending_path == next_row.path) and (pending_lnum == next_row.lnum)) then
      out["insert-path"] = next_row.path
      out["insert-lnum"] = next_row.lnum
      out["insert-side"] = "before"
    else
    end
  end
  return out
end
local function projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
  local hunks = diff_hunks(baseline_lines, current_lines)
  local out = {}
  local idx = {old = 1, new = 1}
  for _, h in ipairs(hunks) do
    local _let_115_ = hunk_indices(h)
    local a_start = _let_115_[1]
    local a_count = _let_115_[2]
    local b_start = _let_115_[3]
    local b_count = _let_115_[4]
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
        table.insert(out, inserted_row(session, prev_row, next_row, txt, k))
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
  local rows = projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
  local refs = {}
  local content = {}
  local idxs = {}
  session["live-edit-rows"] = rows
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
  return (row and (type(row.path) == "string") and (row.path ~= "") and (type(row.lnum) == "number") and (row.lnum > 0))
end
local function special_projected_row_3f(row)
  return (row and row["source-group-id"] and ((#(row["transform-chain"] or {}) > 0) or ((row["source-group-kind"] or "") == "file")))
end
local function append_op_21(ops, path, op)
  local per_file = (ops[path] or {})
  table.insert(per_file, op)
  ops[path] = per_file
  return nil
end
local function append_group_op_21(ops, row, current_rows, processed)
  local group_id = row["source-group-id"]
  local path = row.path
  local key = (path .. "|" .. tostring(group_id))
  local group_lines = {}
  if (processed or {})[key] then
    return nil
  else
    processed[key] = true
    for _, r in ipairs((current_rows or {})) do
      if ((r.path == path) and (r["source-group-id"] == group_id)) then
        table.insert(group_lines, (r.text or r.line or ""))
      else
      end
    end
    local reversed = transform_mod["reverse-group"](row, group_lines, {path = path, lnum = row.lnum})
    if reversed.error then
      return {error = reversed.error}
    else
      if (reversed.kind == "rewrite-bytes") then
        append_op_21(ops, path, {kind = "rewrite-bytes", bytes = reversed.bytes, ["ref-kind"] = (row.kind or "")})
      else
        append_op_21(ops, path, {kind = "replace", lnum = row.lnum, text = reversed.text, ["old-text"] = (row["source-text"] or ""), ["ref-kind"] = (row.kind or "")})
      end
      return nil
    end
  end
end
local function structural_op_from_current_rows(current_rows, start, count)
  local rows = slice_lines(current_rows, start, count)
  local first_row = rows[1]
  if (first_row and first_row["insert-path"] and first_row["insert-lnum"] and first_row["insert-side"]) then
    local path = first_row["insert-path"]
    local lnum = first_row["insert-lnum"]
    local side = first_row["insert-side"]
    local ref_kind = (first_row.kind or "")
    local lines = {}
    local state = {["consistent?"] = true}
    for _, row in ipairs(rows) do
      if ((row["insert-path"] ~= path) or (row["insert-lnum"] ~= lnum) or (row["insert-side"] ~= side)) then
        state["consistent?"] = false
      else
      end
      table.insert(lines, (row.text or row.line or ""))
    end
    if state["consistent?"] then
      return {path = path, lnum = lnum, side = side, lines = lines, ["ref-kind"] = ref_kind}
    else
      return nil
    end
  else
    return nil
  end
end
local function pending_structural_op(session, start, count, current_lines, fallback_kind)
  local pending = (session["pending-structural-edit"] or {})
  local path = pending.path
  local lnum = pending.lnum
  local side = pending.side
  local ref_kind = (pending.kind or fallback_kind or "")
  if ((type(path) == "string") and (path ~= "") and (type(lnum) == "number") and (lnum > 0) and ((side == "before") or (side == "after")) and (count > 0) and (ref_kind ~= "file-entry")) then
    return {path = path, lnum = lnum, side = side, lines = slice_lines(current_lines, start, count), ["ref-kind"] = ref_kind}
  else
    return nil
  end
end
local function collect_file_ops(session)
  local meta = session.meta
  local buf = meta.buf.buffer
  local baseline_lines = (session["edit-baseline-lines"] or vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  local baseline_rows = (session["edit-baseline-rows"] or {})
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_rows = projected_rows_from_edits(session, baseline_rows, baseline_lines, current_lines)
  local hunks = diff_hunks(baseline_lines, current_lines)
  local ops = {}
  local state = {["processed-special-groups"] = {}, ["unsafe-structural?"] = false}
  session["live-edit-rows"] = current_rows
  for _, h in ipairs(hunks) do
    local _let_126_ = hunk_indices(h)
    local a_start = _let_126_[1]
    local a_count = _let_126_[2]
    local b_start = _let_126_[3]
    local b_count = _let_126_[4]
    local common = math.min(a_count, b_count)
    local old_rows = slice_lines(baseline_rows, a_start, a_count)
    local new_lines = slice_lines(current_lines, b_start, b_count)
    if (a_count > 0) then
      for i = 1, common do
        local row = old_rows[i]
        local text = (new_lines[i] or "")
        if (valid_row_3f(row) and ((row.text or "") ~= text)) then
          if special_projected_row_3f(row) then
            local err = append_group_op_21(ops, row, current_rows, state["processed-special-groups"])
            if err then
              state["unsafe-structural?"] = true
            else
            end
          else
            append_op_21(ops, row.path, {kind = "replace", lnum = row.lnum, text = text, ["old-text"] = (row.text or ""), ["ref-kind"] = (row.kind or "")})
          end
        else
        end
      end
      if (a_count > b_count) then
        for i = (common + 1), a_count do
          local row = old_rows[i]
          if (valid_row_3f(row) and not special_projected_row_3f(row)) then
            append_op_21(ops, row.path, {kind = "delete", lnum = row.lnum, ["ref-kind"] = (row.kind or "")})
          else
            state["unsafe-structural?"] = true
          end
        end
      else
      end
      if (b_count > a_count) then
        local insert_op = (structural_op_from_current_rows(current_rows, (b_start + common), (b_count - common)) or pending_structural_op(session, (b_start + common), (b_count - common), current_lines, ((old_rows[common] and old_rows[common].kind) or (old_rows[(common + 1)] and old_rows[(common + 1)].kind) or "")))
        if insert_op then
          local _132_
          if (insert_op.side == "before") then
            _132_ = "insert-before"
          else
            _132_ = "insert-after"
          end
          append_op_21(ops, insert_op.path, {kind = _132_, lnum = insert_op.lnum, lines = insert_op.lines, ["ref-kind"] = (insert_op["ref-kind"] or "")})
        else
          state["unsafe-structural?"] = true
        end
      else
      end
    else
      if (b_count > 0) then
        local insert_op = (structural_op_from_current_rows(current_rows, b_start, b_count) or pending_structural_op(session, b_start, b_count, current_lines, ""))
        if insert_op then
          local _136_
          if (insert_op.side == "before") then
            _136_ = "insert-before"
          else
            _136_ = "insert-after"
          end
          append_op_21(ops, insert_op.path, {kind = _136_, lnum = insert_op.lnum, lines = insert_op.lines, ["ref-kind"] = (insert_op["ref-kind"] or "")})
        else
          state["unsafe-structural?"] = true
        end
      else
      end
    end
  end
  return {ops = ops, ["current-lines"] = current_lines, ["current-rows"] = current_rows, ["unsafe-structural?"] = state["unsafe-structural?"]}
end
local function grouped_path_ops__3eflat_ops(ops)
  local out = {}
  for path, per_file in pairs((ops or {})) do
    for _, op in ipairs((per_file or {})) do
      local item = vim.deepcopy((op or {}))
      item["path"] = path
      table.insert(out, item)
    end
  end
  return out
end
local function apply_file_ops_21(ops)
  return source_mod["apply-write-ops!"](grouped_path_ops__3eflat_ops(ops))
end
local function update_row_after_ops(row, ops, post_lines, renames)
  local ref = vim.deepcopy((row or {}))
  local path0 = (ref.path or "")
  local path = ((renames or {})[path0] or path0)
  local lnum0
  if ((type(ref.lnum) == "number") and (ref.lnum > 0)) then
    lnum0 = ref.lnum
  else
    lnum0 = 1
  end
  local generated_path = ref["insert-path"]
  local generated_lnum = ref["insert-lnum"]
  local generated_side = ref["insert-side"]
  ref["path"] = path
  local lnum = lnum0
  for _, op in ipairs((ops[path] or {})) do
    local same_generated_3f = ((generated_path == path) and (generated_lnum == op.lnum) and (((generated_side == "before") and (op.kind == "insert-before")) or ((generated_side == "after") and (op.kind == "insert-after"))))
    if not same_generated_3f then
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
    else
    end
  end
  if (lnum < 1) then
    lnum = 1
  else
  end
  ref["lnum"] = lnum
  do
    local lines = post_lines[path]
    local line = ((lines and (lnum >= 1) and (lnum <= #lines) and lines[lnum]) or ref.text or ref.line or "")
    ref["line"] = line
    ref["text"] = line
  end
  return ref
end
local function update_session_refs_after_ops_21(session, current_rows, ops, post_lines, renames)
  local meta = session.meta
  local refs = {}
  local content = {}
  local idxs = {}
  for _, row in ipairs((current_rows or {})) do
    local ref = update_row_after_ops(row, ops, post_lines, renames)
    local idx = (#refs + 1)
    if ((ref.kind or "") == "file-entry") then
      local rel = vim.fn.fnamemodify((ref.path or ""), ":.")
      if ((type(rel) == "string") and (rel ~= "")) then
        ref["line"] = rel
      else
        ref["line"] = (ref.path or "")
      end
      ref["text"] = ref.line
    else
    end
    table.insert(refs, {kind = (ref.kind or ""), path = (ref.path or ""), lnum = (ref.lnum or 1), ["open-lnum"] = (ref["open-lnum"] or ref.lnum or 1), ["source-lnum"] = ref["source-lnum"], ["source-text"] = ref["source-text"], ["source-group-id"] = ref["source-group-id"], ["source-group-kind"] = ref["source-group-kind"], ["transform-chain"] = vim.deepcopy((ref["transform-chain"] or {})), line = (ref.line or "")})
    table.insert(content, (ref.line or ""))
    table.insert(idxs, idx)
  end
  meta.buf["source-refs"] = refs
  meta.buf.content = content
  meta.buf.indices = idxs
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
    local buf = session.meta.buf.buffer
    if collected["unsafe-structural?"] then
      vim.notify("metabuffer: only in-place line replacements are writable from results; open the real file for insert/delete edits", vim.log.levels.ERROR)
      pcall(session.meta.refresh_statusline)
      if sign_mod then
        return pcall(sign_mod["refresh-change-signs!"], session)
      else
        return nil
      end
    else
      local result = apply_file_ops_21(ops)
      session["pending-structural-edit"] = nil
      update_session_refs_after_ops_21(session, collected["current-rows"], ops, result["post-lines"], result.renames)
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
      local _155_
      if (result.changed > 0) then
        _155_ = ("metabuffer: wrote " .. tostring(result.changed) .. " change(s)")
      else
        _155_ = "metabuffer: no changes"
      end
      return vim.notify(_155_, vim.log.levels.INFO)
    end
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
  local sign_mod = mods.sign
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
    if sign_mod then
      pcall(sign_mod["capture-baseline!"], session)
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
  if (session and session["ui-hidden"] and session.meta and session.meta.buf) then
    local current_buf = vim.api.nvim_get_current_buf()
    local results_buf = session.meta.buf.buffer
    if (force or (current_buf == results_buf)) then
      session.meta.win.window = vim.api.nvim_get_current_win()
      return restore_session_ui_21(deps, session, {["preserve-focus"] = not force})
    else
      return nil
    end
  else
    return nil
  end
end
return M
