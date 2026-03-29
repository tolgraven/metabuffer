-- [nfnl] fnl/metabuffer/router/failsafe.fnl
local M = {}
local function clear_table_21(tbl)
  for k, _ in pairs((tbl or {})) do
    tbl[k] = nil
  end
  return nil
end
local function add_session_21(seen, sessions, session)
  if (session and (type(session) == "table") and not seen[session]) then
    seen[session] = true
    return table.insert(sessions, session)
  else
    return nil
  end
end
local function maybe_close_win_21(win)
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_close, win, true)
  else
    return nil
  end
end
local function maybe_delete_buf_21(base_buffer, buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    base_buffer["clear-modified!"](buf)
    return pcall(vim.api.nvim_buf_delete, buf, {force = true})
  else
    return nil
  end
end
M.new = function(opts)
  local router = opts.router
  local base_buffer = opts["base-buffer"]
  local router_actions_mod = opts["router-actions-mod"]
  local actions_deps = opts["actions-deps"]
  local info_window = opts["info-window"]
  local preview_window = opts["preview-window"]
  local context_window = opts["context-window"]
  local history_api = opts["history-api"]
  local function fail_safe_teardown_21(where, err)
    router["_last-failsafe"] = {where = where, error = tostring(err)}
    if not router["_teardown-in-progress"] then
      router["_teardown-in-progress"] = true
      do
        local seen = {}
        local sessions = {}
        for _, session in pairs((router.instances or {})) do
          add_session_21(seen, sessions, session)
        end
        for _, session in pairs((router["active-by-prompt"] or {})) do
          add_session_21(seen, sessions, session)
        end
        for _, session in pairs((router["active-by-source"] or {})) do
          add_session_21(seen, sessions, session)
        end
        for _, session in ipairs(sessions) do
          pcall(router_actions_mod["remove-session!"], actions_deps, session)
          maybe_close_win_21(session["prompt-win"])
          maybe_delete_buf_21(base_buffer, session["prompt-buf"])
          if (session.meta and session.meta.win) then
            maybe_close_win_21(session.meta.win.window)
          else
          end
          if (session.meta and session.meta.buf) then
            maybe_delete_buf_21(base_buffer, session.meta.buf.buffer)
          else
          end
          if ((type(info_window) == "table") and info_window["close-window!"]) then
            pcall(info_window["close-window!"], session)
          else
          end
          if ((type(preview_window) == "table") and preview_window["close-window!"]) then
            pcall(preview_window["close-window!"], session)
          else
          end
          if ((type(context_window) == "table") and context_window["close-window!"]) then
            pcall(context_window["close-window!"], session)
          else
          end
          if history_api then
            pcall(history_api["close-history-browser!"], session)
          else
          end
        end
      end
      clear_table_21(router.instances)
      clear_table_21(router["active-by-prompt"])
      clear_table_21(router["active-by-source"])
      clear_table_21(router["launching-by-source"])
      router["_teardown-in-progress"] = false
    else
    end
    local function _11_()
      return vim.notify(("metabuffer: torn down after error in " .. tostring(where) .. "\n" .. tostring(err)), vim.log.levels.ERROR)
    end
    return vim.schedule(_11_)
  end
  local function wrap_public_api_with_failsafe_21()
    if not router["_failsafe-wrapped"] then
      for k, v in pairs(router) do
        if ((type(k) == "string") and (type(v) == "function") and not vim.startswith(k, "_") and (k ~= "configure") and (k ~= "fail-safe-teardown!")) then
          local function _12_(...)
            local res = {pcall(v, ...)}
            local ok = res[1]
            local result = res[2]
            if ok then
              return unpack(res, 2)
            else
              fail_safe_teardown_21(k, result)
              return error(result)
            end
          end
          router[k] = _12_
        else
        end
      end
      router["_failsafe-wrapped"] = true
      return nil
    else
      return nil
    end
  end
  return {["fail-safe-teardown!"] = fail_safe_teardown_21, ["wrap-public-api-with-failsafe!"] = wrap_public_api_with_failsafe_21}
end
return M
