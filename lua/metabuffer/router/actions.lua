-- [nfnl] fnl/metabuffer/router/actions.fnl
local M = {}
local base_buffer_mod = require("metabuffer.buffer.base")
local events = require("metabuffer.events")
local util = require("metabuffer.util")
local actions_edit_mod = require("metabuffer.router.actions_edit")
local edit_actions = nil
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
  return base_buffer_mod["clear-modified!"](buf)
end
local function clear_managed_buffer_modified_21(buf_wrapper)
  if (buf_wrapper and buf_wrapper["clear-modified!"]) then
    return pcall(buf_wrapper["clear-modified!"], buf_wrapper)
  else
    return nil
  end
end
local function with_valid_window_wrapper_21(wrapper)
  if (wrapper and wrapper.window and vim.api.nvim_win_is_valid(wrapper.window)) then
    return wrapper
  else
    return nil
  end
end
local function destroy_window_wrapper_21(wrapper)
  local val_110_auto = with_valid_window_wrapper_21(wrapper)
  if val_110_auto then
    local target = val_110_auto
    if target.destroy then
      return pcall(target.destroy)
    else
      return nil
    end
  else
    return nil
  end
end
local function restore_window_wrapper_opts_21(wrapper)
  local val_110_auto = with_valid_window_wrapper_21(wrapper)
  if val_110_auto then
    local target = val_110_auto
    if target["restore-opts"] then
      return pcall(target["restore-opts"])
    else
      return nil
    end
  else
    return nil
  end
end
local function apply_window_wrapper_opts_21(wrapper, opts)
  local val_110_auto = with_valid_window_wrapper_21(wrapper)
  if val_110_auto then
    local target = val_110_auto
    if target["apply-opts"] then
      return pcall(target["apply-opts"], opts)
    else
      return nil
    end
  else
    return nil
  end
end
local function session_main_wrappers(session)
  local main_win = (session and session.meta and session.meta.win)
  local status_win = (session and session.meta and session.meta["status-win"])
  if (status_win == main_win) then
    return {main_win}
  else
    return {main_win, status_win}
  end
end
local function each_session_main_wrapper_21(session, f)
  for _, wrapper in ipairs(session_main_wrappers(session)) do
    if wrapper then
      f(wrapper)
    else
    end
  end
  return nil
end
local function each_session_main_window_21(session, f)
  local function _13_(wrapper)
    local win = wrapper.window
    if (win and vim.api.nvim_win_is_valid(win)) then
      return f(win)
    else
      return nil
    end
  end
  return each_session_main_wrapper_21(session, _13_)
end
local function restore_main_window_opts_21(session)
  return each_session_main_wrapper_21(session, destroy_window_wrapper_21)
end
local function suspend_main_window_opts_21(session)
  each_session_main_wrapper_21(session, restore_window_wrapper_opts_21)
  local function _15_(win)
    return events.send("on-win-teardown!", {win = win, role = "main"})
  end
  return each_session_main_window_21(session, _15_)
end
local function resume_main_window_opts_21(deps, session)
  local meta_window_mod = deps.mods["meta-window"]
  local opts = ((meta_window_mod and meta_window_mod["default-opts"]) or {})
  local function _16_(wrapper)
    return apply_window_wrapper_opts_21(wrapper, opts)
  end
  each_session_main_wrapper_21(session, _16_)
  local function _17_(win)
    return events.send("on-win-create!", {win = win, role = "main"})
  end
  return each_session_main_window_21(session, _17_)
end
local function restore_managed_buffer_effects_21(session)
  if session then
    for _, _18_ in ipairs({{(session.meta and session.meta.buf and session.meta.buf.buffer), "meta"}, {session["prompt-buf"], "prompt"}, {session["info-buf"], "info"}, {session["preview-buf"], "preview"}, {session["history-browser-buf"], "history-browser"}}) do
      local buf = _18_[1]
      local role = _18_[2]
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
  return util["restore-global-cursor!"](session, "startup-cursor-hidden?", "startup-saved-guicursor")
end
local function session_prompt_text(router_util_mod, session)
  local or_20_ = session["last-prompt-text"]
  if not or_20_ then
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      or_20_ = router_util_mod["prompt-text"](session)
    else
      or_20_ = ""
    end
  end
  return or_20_
end
local function persist_session_ui_state_21(history_api, router_util_mod, session)
  history_api["push-history-entry!"](session, session_prompt_text(router_util_mod, session))
  router_util_mod["persist-prompt-height!"](session)
  return router_util_mod["persist-results-wrap!"](session)
end
local function close_session_prompt_21(session)
  if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    pcall(vim.api.nvim_win_close, session["prompt-win"], true)
  else
  end
  if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
    clear_buffer_modified_21(session["prompt-buf"])
    return pcall(vim.api.nvim_buf_delete, session["prompt-buf"], {force = true})
  else
    return nil
  end
end
local function close_session_side_windows_21(history_api, info_window, preview_window, context_window, session)
  info_window["close-window!"](session)
  preview_window["close-window!"](session)
  if (context_window and context_window["close-window!"]) then
    context_window["close-window!"](session)
  else
  end
  return history_api["close-history-browser!"](session)
end
local function clear_session_registry_entries_21(active_by_source, active_by_prompt, instances, session)
  clear_map_entry_21(active_by_source, session["source-buf"], session)
  if (session.meta and session.meta.buf and session.meta.buf.buffer) then
    clear_map_entry_21(active_by_source, session.meta.buf.buffer, session)
  else
  end
  clear_map_entry_21(active_by_prompt, session["prompt-buf"], session)
  if session["instance-id"] then
    return clear_map_entry_21(instances, session["instance-id"], session)
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
    persist_session_ui_state_21(history_api, router_util_mod, session)
    if session.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
    else
    end
    close_session_prompt_21(session)
    if (session.meta and session.meta.buf and session.meta.buf.buffer) then
      clear_buffer_modified_21(session.meta.buf.buffer)
    else
    end
    close_session_side_windows_21(history_api, info_window, preview_window, context_window, session)
    if (sign_mod and session.meta and session.meta.buf and session.meta.buf.buffer) then
      sign_mod["clear-change-signs!"](session.meta.buf.buffer)
    else
    end
    clear_session_registry_entries_21(active_by_source, active_by_prompt, instances, session)
    if (session["origin-win"] and vim.api.nvim_win_is_valid(session["origin-win"])) then
      return events.send("on-win-teardown!", {win = session["origin-win"], role = "origin"})
    else
      return nil
    end
  else
    return nil
  end
end
local function handoff_host_window_21(win, buf)
  if (win and buf and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    local function _34_()
      pcall(vim.api.nvim_exec_autocmds, "BufWinEnter", {buffer = buf, modeline = false})
      pcall(vim.api.nvim_exec_autocmds, "BufEnter", {buffer = buf, modeline = false})
      pcall(vim.api.nvim_exec_autocmds, "WinEnter", {modeline = false})
      return pcall(vim.cmd, "redraw!")
    end
    return pcall(vim.api.nvim_win_call, win, _34_)
  else
    return nil
  end
end
local function close_session_windows_21(deps, session)
  local info_window = deps.windows.info
  local preview_window = deps.windows.preview
  local context_window = deps.windows.context
  local history_api = deps.history.api
  info_window["close-window!"](session)
  preview_window["close-window!"](session)
  if (context_window and context_window["close-window!"]) then
    context_window["close-window!"](session)
  else
  end
  return history_api["close-history-browser!"](session)
end
local function restore_prompt_window_21(deps, session)
  local mods = deps.mods
  local prompt_window_mod = mods["prompt-window"]
  local router_util_mod = mods["router-util"]
  local height = (session["hidden-prompt-height"] or router_util_mod["prompt-height"]())
  local prompt_window = prompt_window_mod["restore-hidden!"](vim, session["prompt-buf"], {["origin-win"] = (session.meta and session.meta.win and session.meta.win.window), ["window-local-layout"] = session["window-local-layout"], height = height})
  session["prompt-window"] = prompt_window
  session["prompt-win"] = prompt_window.window
  return prompt_window
end
local function restore_results_buffer_21(session)
  local curr = session.meta
  if (curr and curr.buf and curr.buf["prepare-visible-edit!"]) then
    pcall(curr.buf["prepare-visible-edit!"], curr.buf)
  else
  end
  if curr then
    return pcall(curr.buf.render)
  else
    return nil
  end
end
local function capture_hidden_ui_state_21(prompt_window_mod, router_util_mod, session)
  local function _39_()
    router_util_mod["persist-prompt-height!"](session)
    return router_util_mod["persist-results-wrap!"](session)
  end
  local function _40_()
    if (session["directive-help-win"] and vim.api.nvim_win_is_valid(session["directive-help-win"])) then
      pcall(vim.api.nvim_win_close, session["directive-help-win"], true)
    else
    end
    session["directive-help-win"] = nil
    return nil
  end
  return prompt_window_mod["capture-hidden-state!"](session, {["persist-state!"] = _39_, ["close-directive-help!"] = _40_})
end
local function finish_session_ui_restore_21(deps, session, preserve_focus_3f)
  local mods = deps.mods
  local refresh = deps.refresh
  local sync_prompt_buffer_name_21 = refresh["sync-prompt-buffer-name!"]
  local session_view_mod = mods["session-view"]
  local prompt_window_mod = mods["prompt-window"]
  local curr = session.meta
  local _prompt_window = restore_prompt_window_21(deps, session)
  sync_prompt_buffer_name_21(session)
  session["_last-prompt-statusline"] = nil
  curr["status-win"] = curr.win
  session["ui-hidden"] = false
  resume_main_window_opts_21(deps, session)
  restore_results_buffer_21(session)
  events.send("on-restore-ui!", {session = session, ["restore-view?"] = (session_view_mod and session["source-view"]), ["refresh-lines"] = true})
  return prompt_window_mod["restore-focus!"](session, preserve_focus_3f)
end
local function hide_session_ui_21(deps, session)
  local router = deps.router
  local mods = deps.mods
  local animation_mod = mods.animation
  local prompt_window_mod = mods["prompt-window"]
  local router_util_mod = mods["router-util"]
  local active_by_source = router["active-by-source"]
  session["ui-hidden"] = true
  session["_last-prompt-statusline"] = nil
  if (animation_mod and animation_mod["cancel-session!"]) then
    animation_mod["cancel-session!"](session)
  else
  end
  restore_startup_cursor_21(session)
  session["ui-last-insert-mode"] = vim.startswith(vim.api.nvim_get_mode().mode, "i")
  capture_hidden_ui_state_21(prompt_window_mod, router_util_mod, session)
  prompt_window_mod["close!"](session)
  clear_managed_buffer_modified_21((session.meta and session.meta.buf))
  suspend_main_window_opts_21(session)
  close_session_windows_21(deps, session)
  if (session.meta and session.meta.buf and session.meta.buf.buffer) then
    active_by_source[session.meta.buf.buffer] = session
    return nil
  else
    return nil
  end
end
local function restore_session_ui_21(deps, session, opts)
  local preserve_focus_3f = (opts and opts["preserve-focus"])
  local curr = session.meta
  if (not session["restoring-ui?"] and session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and curr and curr.win and vim.api.nvim_win_is_valid(curr.win.window)) then
    session["restoring-ui?"] = true
    local function _44_()
      return finish_session_ui_restore_21(deps, session, preserve_focus_3f)
    end
    local ok,err = xpcall(_44_, debug.traceback)
    session["restoring-ui?"] = false
    if not ok then
      return error(err)
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
      vim.cmd("normal! ^")
    else
    end
  else
    local row = curr.selected_line()
    local vq = curr.vim_query()
    local target_buf = curr.buf.model
    local target_win = session["origin-win"]
    if (target_win and vim.api.nvim_win_is_valid(target_win) and target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
      router_util_mod["silent-win-set-buf!"](target_win, target_buf)
      local function _50_()
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
      vim.api.nvim_win_call(target_win, _50_)
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
  handoff_host_window_21(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
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
      local function _57_()
        return pcall(vim.fn.winrestview, session["source-view"])
      end
      vim.api.nvim_win_call(session["origin-win"], _57_)
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
    local function _60_()
      if vim.api.nvim_win_is_valid(win) then
        local function _61_()
          return pcall(vim.fn.winrestview, view)
        end
        return vim.api.nvim_win_call(win, _61_)
      else
        return nil
      end
    end
    vim.schedule(_60_)
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
    local function _71_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _71_)
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
  local function _77_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return ("!" .. word)
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _77_)
end
M["insert-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _79_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _79_)
end
M["insert-symbol-under-cursor-newline!"] = function(deps, prompt_buf)
  local function _81_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _81_, {newline = true})
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
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    if ((session["info-file-entry-view"] or "meta") == "content") then
      session["info-file-entry-view"] = "meta"
    else
      session["info-file-entry-view"] = "content"
    end
    session["info-render-sig"] = nil
    return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
  else
    return nil
  end
end
M["refresh-files!"] = function(deps, prompt_buf)
  local router = deps.router
  local mods = deps.mods
  local refresh = deps.refresh
  local project = deps.project
  local router_util_mod = mods["router-util"]
  local project_source = project.source
  local apply_prompt_lines = refresh["apply-prompt-lines!"]
  local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
  if session then
    router_util_mod["clear-file-caches!"](router, session)
    if session["project-mode"] then
      project_source["apply-source-set!"](session)
    else
    end
    apply_prompt_lines(session)
    events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
    return vim.notify("metabuffer: refreshed cached file views", vim.log.levels.INFO)
  else
    return nil
  end
end
M["remove-session!"] = function(deps, session)
  return remove_session_21(deps, session)
end
M["on-results-buffer-wipe!"] = function(deps, results_buf)
  return edit_actions["on-results-buffer-wipe!"](deps, results_buf)
end
edit_actions = actions_edit_mod.new({["session-by-prompt"] = session_by_prompt, ["clear-map-entry!"] = clear_map_entry_21, ["restore-main-window-opts!"] = restore_main_window_opts_21, ["hide-session-ui!"] = hide_session_ui_21, ["restore-session-ui!"] = restore_session_ui_21})
M["write-results!"] = function(deps, prompt_buf)
  return edit_actions["write-results!"](deps, prompt_buf)
end
M["enter-edit-mode!"] = function(deps, prompt_buf)
  return edit_actions["enter-edit-mode!"](deps, prompt_buf)
end
M["hide-visible-ui!"] = function(deps, prompt_buf)
  return edit_actions["hide-visible-ui!"](deps, prompt_buf)
end
M["sync-live-edits!"] = function(deps, prompt_buf)
  return edit_actions["sync-live-edits!"](deps, prompt_buf)
end
M["maybe-restore-ui!"] = function(deps, prompt_buf, force)
  return edit_actions["maybe-restore-ui!"](deps, prompt_buf, force)
end
return M
