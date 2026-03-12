-- [nfnl] fnl/metabuffer/router/actions.fnl
local M = {}
local function session_by_prompt(active_by_prompt, prompt_buf)
  return active_by_prompt[prompt_buf]
end
local function remove_session_21(deps, session)
  local history_api = deps["history-api"]
  local sign_mod = deps["sign-mod"]
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
    if (sign_mod and session.meta and session.meta.buf and session.meta.buf.buffer) then
      sign_mod["clear-change-signs!"](session.meta.buf.buffer)
    else
    end
    if session["source-buf"] then
      active_by_source[session["source-buf"]] = nil
    else
    end
    if (session.meta and session.meta.buf and session.meta.buf.buffer) then
      active_by_source[session.meta.buf.buffer] = nil
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
local function apply_prompt_window_opts_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    local wo = vim.wo[win]
    wo["winfixheight"] = true
    wo["number"] = false
    wo["relativenumber"] = false
    wo["signcolumn"] = "no"
    wo["foldcolumn"] = "0"
    wo["spell"] = false
    wo["wrap"] = true
    wo["linebreak"] = false
    return nil
  else
    return nil
  end
end
local function hide_session_ui_21(deps, session)
  local router_util_mod = deps["router-util-mod"]
  local info_window = deps["info-window"]
  local preview_window = deps["preview-window"]
  local history_api = deps["history-api"]
  local active_by_source = deps["active-by-source"]
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
    pcall(vim.api.nvim_win_close, session["prompt-win"], true)
  else
  end
  session["prompt-win"] = nil
  info_window["close-window!"](session)
  preview_window["close-window!"](session)
  history_api["close-history-browser!"](session)
  if (session.meta and session.meta.buf and session.meta.buf.buffer) then
    active_by_source[session.meta.buf.buffer] = session
    return nil
  else
    return nil
  end
end
local function restore_session_ui_21(deps, session)
  local prompt_window_mod = deps["prompt-window-mod"]
  local meta_window_mod = deps["meta-window-mod"]
  local sync_prompt_buffer_name_21 = deps["sync-prompt-buffer-name!"]
  local router_util_mod = deps["router-util-mod"]
  local update_info_window = deps["update-info-window"]
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
      local function _18_()
        vim.cmd(("belowright " .. tostring(height) .. "new"))
        return vim.api.nvim_get_current_win()
      end
      prompt_win = vim.api.nvim_win_call(curr.win.window, _18_)
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
    pcall(update_info_window, session, true)
    vim.api.nvim_set_current_win(prompt_win)
    if session["ui-last-insert-mode"] then
      return vim.cmd("startinsert")
    else
      return vim.cmd("stopinsert")
    end
  else
    return nil
  end
end
local function finish_accept(deps, session)
  local active_by_prompt = deps["active-by-prompt"]
  local router_prompt_mod = deps["router-prompt-mod"]
  local sign_mod = deps["sign-mod"]
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
    clear_hit_highlight_21(curr)
    session["results-edit-mode"] = false
    hide_session_ui_21(deps, session)
  else
    local function _31_()
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
    vim.schedule(_31_)
  end
  return curr
end
local function finish_cancel(deps, session)
  local router_prompt_mod = deps["router-prompt-mod"]
  local router_util_mod = deps["router-util-mod"]
  local sign_mod = deps["sign-mod"]
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
  if sign_mod then
    sign_mod["clear-change-signs!"](curr.buf.buffer)
  else
  end
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
    local function _44_()
      return vim.fn.expand("<cword>")
    end
    word = vim.api.nvim_win_call(session.meta.win.window, _44_)
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
  local function _48_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return ("!" .. word)
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _48_)
end
M["insert-symbol-under-cursor!"] = function(deps, prompt_buf)
  local function _50_(word)
    if ((type(word) == "string") and (vim.trim(word) ~= "")) then
      return word
    else
      return ""
    end
  end
  return append_current_symbol_21(deps, prompt_buf, _50_)
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
  local active_by_source = deps["active-by-source"]
  local buf = session.meta.buf.buffer
  active_by_source[buf] = session
  return nil
end
local function path_updates_from_visible(session)
  local meta = session.meta
  local visible = vim.api.nvim_buf_get_lines(meta.buf.buffer, 0, -1, false)
  local idxs = (meta.buf.indices or {})
  local refs = (meta.buf["source-refs"] or {})
  local content = meta.buf.content
  local updates = {}
  for i = 1, math.min(#visible, #idxs) do
    local src_idx = idxs[i]
    local ref = refs[src_idx]
    local kind = ((ref and ref.kind) or "")
    local path = (ref and ref.path)
    local lnum = (ref and ref.lnum)
    local old = (content[src_idx] or "")
    local new = (visible[i] or "")
    if (ref and (kind ~= "file-entry") and (type(path) == "string") and (path ~= "") and (type(lnum) == "number") and (lnum > 0) and (old ~= new)) then
      local per_file = (updates[path] or {})
      per_file[lnum] = {new = new, ["src-idx"] = src_idx}
      updates[path] = per_file
    else
    end
  end
  return updates
end
local function apply_path_updates_21(session, updates)
  local meta = session.meta
  local any_written = false
  local writes = 0
  local wrote = any_written
  local changed = writes
  for path, per_file in pairs(updates) do
    local ok_read,lines = pcall(vim.fn.readfile, path)
    if (ok_read and (type(lines) == "table")) then
      local local_change = false
      for lnum, payload in pairs(per_file) do
        if ((lnum >= 1) and (lnum <= #lines)) then
          local next_line = payload.new
          local src_idx = payload["src-idx"]
          if (lines[lnum] ~= next_line) then
            lines[lnum] = next_line
            meta.buf.content[src_idx] = next_line
            if (meta.buf["source-refs"] and meta.buf["source-refs"][src_idx]) then
              local src_ref = meta.buf["source-refs"][src_idx]
              src_ref["line"] = next_line
            else
            end
            local_change = true
            changed = (changed + 1)
          else
          end
        else
        end
      end
      if local_change then
        local ok_write = pcall(vim.fn.writefile, lines, path)
        if ok_write then
          wrote = true
          local bufnr = vim.fn.bufnr(path)
          if (bufnr and (bufnr > 0) and vim.api.nvim_buf_is_loaded(bufnr)) then
            for lnum, payload in pairs(per_file) do
              if ((lnum >= 1) and (lnum <= #lines)) then
                pcall(vim.api.nvim_buf_set_lines, bufnr, (lnum - 1), lnum, false, {payload.new})
              else
              end
            end
          else
          end
        else
        end
      else
      end
    else
    end
  end
  return {wrote = wrote, changed = changed}
end
local function invalidate_caches_for_paths_21(deps, session, updates)
  local settings = deps.settings
  local project_file_cache = (settings and settings["project-file-cache"])
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
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
  local sign_mod = deps["sign-mod"]
  local update_info_window = deps["update-info-window"]
  local preview_window = deps["preview-window"]
  if session then
    local updates = path_updates_from_visible(session)
    local result = apply_path_updates_21(session, updates)
    local buf = session.meta.buf.buffer
    invalidate_caches_for_paths_21(deps, session, updates)
    if (result.changed > 0) then
      pcall(session.meta["on-update"], 0)
    else
    end
    pcall(vim.api.nvim_set_option_value, "modified", false, {buf = buf})
    pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", false)
    pcall(session.meta.refresh_statusline)
    pcall(update_info_window, session, true)
    pcall(preview_window["maybe-update-for-selection!"], session)
    if sign_mod then
      pcall(sign_mod["refresh-change-signs!"], session)
    else
    end
    local _70_
    if (result.changed > 0) then
      _70_ = ("metabuffer: wrote " .. tostring(result.changed) .. " change(s)")
    else
      _70_ = "metabuffer: no changes"
    end
    return vim.notify(_70_, vim.log.levels.INFO)
  else
    return nil
  end
end
M["enter-edit-mode!"] = function(deps, prompt_buf)
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
  local router_util_mod = deps["router-util-mod"]
  local history_api = deps["history-api"]
  local apply_prompt_lines = deps["apply-prompt-lines"]
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
M["maybe-restore-ui!"] = function(deps, prompt_buf, force)
  local session = session_by_prompt(deps["active-by-prompt"], prompt_buf)
  if (session and session["ui-hidden"] and (force or not session["results-edit-mode"]) and session.meta and session.meta.buf and (vim.api.nvim_get_current_buf() == session.meta.buf.buffer)) then
    session.meta.win.window = vim.api.nvim_get_current_win()
    return restore_session_ui_21(deps, session)
  else
    return nil
  end
end
return M
