-- [nfnl] fnl/metabuffer/router/actions.fnl
local M = {}
local function session_by_prompt(active_by_prompt, prompt_buf)
  return active_by_prompt[prompt_buf]
end
local function remove_session_21(deps, session)
  local history_api = deps["history-api"]
  local router_util_mod = deps["router-util-mod"]
  local info_window = deps["info-window"]
  local preview_window = deps["preview-window"]
  local active_by_source = deps["active-by-source"]
  local active_by_prompt = deps["active-by-prompt"]
  if session then
    local or_1_ = session["last-prompt-text"]
    if not or_1_ then
      if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
        or_1_ = router_util_mod["prompt-text"](session)
      else
        or_1_ = ""
      end
    end
    history_api["push-history-entry!"](session, or_1_)
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
    history_api["close-history-browser!"](session)
    if session["source-buf"] then
      active_by_source[session["source-buf"]] = nil
    else
    end
    if session["prompt-buf"] then
      active_by_prompt[session["prompt-buf"]] = nil
      return nil
    else
      return nil
    end
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
local function finish_accept(deps, session)
  local active_by_prompt = deps["active-by-prompt"]
  local router_prompt_mod = deps["router-prompt-mod"]
  local router_util_mod = deps["router-util-mod"]
  local session_view = deps["session-view"]
  local base_buffer = deps["base-buffer"]
  local history_api = deps["history-api"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local wrapup = deps.wrapup
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
    pcall(curr.refresh_statusline)
    pcall(deps["update-info-window"], session, false)
  else
    local function _18_()
      if (active_by_prompt[session["prompt-buf"]] == session) then
        router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
        pcall(vim.cmd, "stopinsert")
        clear_hit_highlight_21(curr)
        pcall(vim.cmd, ("sign unplace * buffer=" .. curr.buf.buffer))
        session_view["wipe-temp-buffers"](curr)
        remove_session_21(deps, session)
        return wrapup(curr)
      else
        return nil
      end
    end
    vim.schedule(_18_)
  end
  return curr
end
local function finish_cancel(deps, session)
  local router_prompt_mod = deps["router-prompt-mod"]
  local router_util_mod = deps["router-util-mod"]
  local session_view = deps["session-view"]
  local base_buffer = deps["base-buffer"]
  local history_api = deps["history-api"]
  local wrapup = deps.wrapup
  local curr = session.meta
  router_prompt_mod["begin-session-close!"](session, router_prompt_mod["cancel-prompt-update!"])
  session["last-prompt-text"] = router_util_mod["prompt-text"](session)
  history_api["push-history-entry!"](session, session["last-prompt-text"])
  pcall(vim.cmd, "stopinsert")
  clear_hit_highlight_21(curr)
  pcall(vim.cmd, ("sign unplace * buffer=" .. curr.buf.buffer))
  vim.cmd("silent! nohlsearch")
  if (vim.api.nvim_win_is_valid(session["origin-win"]) and vim.api.nvim_buf_is_valid(session["origin-buf"])) then
    pcall(vim.api.nvim_set_current_win, session["origin-win"])
    pcall(vim.api.nvim_win_set_buf, session["origin-win"], session["origin-buf"])
  else
  end
  base_buffer["switch-buf"](curr.buf.model)
  session_view["wipe-temp-buffers"](curr)
  remove_session_21(deps, session)
  wrapup(curr)
  return curr
end
M["finish!"] = function(deps, kind, prompt_buf)
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
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
  local history_api = deps["history-api"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
  if (session and session["history-browser-active"]) then
    return history_api["apply-history-browser-selection!"](session)
  else
    return M["finish!"](deps, "accept", prompt_buf)
  end
end
M["cancel!"] = function(deps, prompt_buf)
  local history_api = deps["history-api"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
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
  local active_by_prompt = deps["active-by-prompt"]
  local history_store = deps["history-store"]
  local history_api = deps["history-api"]
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
  local history_api = deps["history-api"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
  if session then
    history_api["merge-history-into-session!"](session)
    return history_api["refresh-history-browser!"](session)
  else
    return nil
  end
end
local function append_current_symbol_21(deps, prompt_buf, f)
  local active_by_prompt = deps["active-by-prompt"]
  local router_util_mod = deps["router-util-mod"]
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if session then
    local word
    local function _29_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _29_)
    local token = f(word)
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
M["exclude-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _33_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return ("!" .. word)
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _33_)
end
M["insert-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _35_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _35_)
end
M["toggle-scan-option!"] = function(deps, prompt_buf, which)
  local project_source = deps["project-source"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
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
  local router_util_mod = deps["router-util-mod"]
  local sync_prompt_buffer_name_21 = deps["sync-prompt-buffer-name!"]
  local project_source = deps["project-source"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
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
  local update_info_window = deps["update-info-window"]
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
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
return M
