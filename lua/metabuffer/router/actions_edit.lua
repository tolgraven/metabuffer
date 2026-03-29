-- [nfnl] fnl/metabuffer/router/actions_edit.fnl
local M = {}
local debug_mod = require("metabuffer.debug")
local actions_writeback_mod = require("metabuffer.router.actions_writeback")
M.new = function(opts)
  local _let_1_ = (opts or {})
  local session_by_prompt = _let_1_["session-by-prompt"]
  local clear_map_entry_21 = _let_1_["clear-map-entry!"]
  local restore_main_window_opts_21 = _let_1_["restore-main-window-opts!"]
  local hide_session_ui_21 = _let_1_["hide-session-ui!"]
  local restore_session_ui_21 = _let_1_["restore-session-ui!"]
  local function ensure_session_for_results_buf_21(deps, session)
    local router = deps.router
    local active_by_source = router["active-by-source"]
    local buf = session.meta.buf.buffer
    active_by_source[buf] = session
    return nil
  end
  local writeback = actions_writeback_mod.new({})
  local apply_live_edits_to_meta_21 = writeback["apply-live-edits-to-meta!"]
  local write_results_core_21 = writeback["write-results!"]
  local function write_results_21(deps, prompt_buf)
    local router = deps.router
    local mods = deps.mods
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    local sign_mod = mods.sign
    if session then
      return write_results_core_21(deps, session, sign_mod)
    else
      return nil
    end
  end
  local function enter_edit_mode_21(deps, prompt_buf)
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
      if (session.meta and session.meta.buf and session.meta.buf["prepare-visible-edit!"]) then
        pcall(session.meta.buf["prepare-visible-edit!"], session.meta.buf)
      else
      end
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
  local function hide_visible_ui_21(deps, prompt_buf)
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
  local function sync_live_edits_21(deps, prompt_buf)
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
  local function maybe_restore_ui_21(deps, prompt_buf, force)
    local router = deps.router
    local session = session_by_prompt(router["active-by-prompt"], prompt_buf)
    if (session and session["ui-hidden"] and not session["restoring-ui?"] and session.meta and session.meta.buf) then
      local current_buf = vim.api.nvim_get_current_buf()
      local results_buf = session.meta.buf.buffer
      if (force or (current_buf == results_buf)) then
        debug_mod.log("router-actions", ("maybe-restore-ui" .. " force=" .. tostring(not not force) .. " current=" .. tostring(current_buf) .. " results=" .. tostring(results_buf) .. " hidden=" .. tostring(not not session["ui-hidden"]) .. " restoring=" .. tostring(not not session["restoring-ui?"]) .. " bootstrapped=" .. tostring(not not session["project-bootstrapped"]) .. " stream-done=" .. tostring(not not session["lazy-stream-done"])))
        session.meta.win.window = vim.api.nvim_get_current_win()
        return restore_session_ui_21(deps, session, {["preserve-focus"] = not force})
      else
        return nil
      end
    else
      return nil
    end
  end
  local function on_results_buffer_wipe_21(deps, results_buf)
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
      local or_12_ = session["last-prompt-text"]
      if not or_12_ then
        if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
          or_12_ = router_util_mod["prompt-text"](session)
        else
          or_12_ = ""
        end
      end
      history_api["push-history-entry!"](session, or_12_)
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
  return {["write-results!"] = write_results_21, ["enter-edit-mode!"] = enter_edit_mode_21, ["hide-visible-ui!"] = hide_visible_ui_21, ["sync-live-edits!"] = sync_live_edits_21, ["maybe-restore-ui!"] = maybe_restore_ui_21, ["on-results-buffer-wipe!"] = on_results_buffer_wipe_21}
end
return M
