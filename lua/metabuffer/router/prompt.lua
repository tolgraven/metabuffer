-- [nfnl] fnl/metabuffer/router/prompt.fnl
local source_mod = require("metabuffer.source")
local M = {}
local function last_non_empty_trimmed(lines)
  local n = #(lines or {})
  local step
  local function step0(idx)
    if (idx <= 0) then
      return ""
    else
      local trimmed = vim.trim((lines[idx] or ""))
      if (trimmed ~= "") then
        return trimmed
      else
        return step0((idx - 1))
      end
    end
  end
  step = step0
  return step(n)
end
local function any_active_line_3f(lines)
  local n = #(lines or {})
  local step
  local function step0(idx)
    if (idx > n) then
      return false
    else
      local trimmed = vim.trim((lines[idx] or ""))
      if (trimmed ~= "") then
        return true
      else
        return step0((idx + 1))
      end
    end
  end
  step = step0
  return step(1)
end
local function option_prefix()
  local p = vim.g["meta#prefix"]
  if ((type(p) == "string") and (p ~= "")) then
    return p
  else
    return "#"
  end
end
local function incomplete_directive_token_3f(lines)
  local last_line = ((lines or {})[#(lines or {})] or "")
  local last_char
  if (#last_line > 0) then
    last_char = string.sub(last_line, #last_line, #last_line)
  else
    last_char = ""
  end
  local line_ends_with_space_3f = (last_char == " ")
  local trimmed_right = string.gsub(last_line, "%s+$", "")
  local prefix = option_prefix()
  local token = (string.match(trimmed_right, "%S+$") or "")
  local prefix_len = #prefix
  return ((token ~= "") and not line_ends_with_space_3f and not (string.sub(token, 1, 1) == "\\") and (#token >= prefix_len) and (string.sub(token, 1, prefix_len) == prefix))
end
M["now-ms"] = function()
  return (vim.loop.hrtime() / 1000000)
end
M["prompt-update-delay-ms"] = function(settings, query_mod, prompt_lines, session)
  local base = math.max(0, settings["prompt-update-debounce-ms"])
  local n
  if (session and session.meta and session.meta.buf and session.meta.buf.indices) then
    n = #session.meta.buf.indices
  else
    n = 0
  end
  local short_extra_ms = (settings["prompt-short-query-extra-ms"] or {180, 120, 70})
  local size_thresholds = (settings["prompt-size-scale-thresholds"] or {2000, 10000, 50000})
  local size_extra = (settings["prompt-size-scale-extra"] or {0, 2, 6, 10})
  local lines = prompt_lines(session)
  local parsed0
  if (session["project-mode"] or (session and query_mod["truthy?"](session["default-include-lgrep"]))) then
    parsed0 = query_mod["parse-query-lines"](lines)
  else
    parsed0 = {lines = lines, ["lgrep-lines"] = {}}
  end
  local parsed = query_mod["apply-default-source"](parsed0, (session and query_mod["truthy?"](session["default-include-lgrep"])))
  local qlen
  do
    local last_active = last_non_empty_trimmed((parsed.lines or {}))
    qlen = #(last_active or "")
  end
  local short_extra
  if (qlen <= 1) then
    short_extra = (short_extra_ms[1] or 180)
  else
    if (qlen <= 2) then
      short_extra = (short_extra_ms[2] or 120)
    else
      if (qlen <= 3) then
        short_extra = (short_extra_ms[3] or 70)
      else
        short_extra = 0
      end
    end
  end
  local scale
  if (n < (size_thresholds[1] or 2000)) then
    scale = (size_extra[1] or 0)
  else
    if (n < (size_thresholds[2] or 10000)) then
      scale = (size_extra[2] or 2)
    else
      if (n < (size_thresholds[3] or 50000)) then
        scale = (size_extra[3] or 6)
      else
        scale = (size_extra[4] or 10)
      end
    end
  end
  local extra
  if (session and session["project-mode"] and not session["lazy-stream-done"]) then
    extra = 2
  else
    extra = 0
  end
  local source_extra_ms = source_mod["query-source-debounce-ms"](settings, parsed)
  local source_extra
  if (source_extra_ms > 0) then
    source_extra = math.max(0, (source_extra_ms - (base + short_extra + scale + extra)))
  else
    source_extra = 0
  end
  local directive_extra
  if incomplete_directive_token_3f(prompt_lines(session)) then
    directive_extra = math.max(0, ((settings["prompt-incomplete-directive-ms"] or 1000) - (base + short_extra + scale + extra + source_extra)))
  else
    directive_extra = 0
  end
  return (base + short_extra + scale + extra + source_extra + directive_extra)
end
M["prompt-has-active-query?"] = function(query_mod, prompt_lines, session)
  local parsed = query_mod["apply-default-source"](query_mod["parse-query-lines"](prompt_lines(session)), (session and query_mod["truthy?"](session["default-include-lgrep"])))
  return any_active_line_3f((parsed.lines or {}))
end
M["cancel-prompt-update!"] = function(session)
  if (session and session["prompt-update-timer"]) then
    local timer = session["prompt-update-timer"]
    local stopf = timer.stop
    local closef = timer.close
    if stopf then
      pcall(stopf, timer)
    else
    end
    if closef then
      pcall(closef, timer)
    else
    end
    session["prompt-update-timer"] = nil
    session["prompt-update-pending"] = false
    return nil
  else
    return nil
  end
end
M["begin-session-close!"] = function(session, cancel_prompt_update_21)
  if session then
    session.closing = true
    session["prompt-update-token"] = (1 + (session["prompt-update-token"] or 0))
    session["prompt-update-dirty"] = false
    cancel_prompt_update_21(session)
    session["preview-update-token"] = (1 + (session["preview-update-token"] or 0))
    if session["preview-update-timer"] then
      local timer = session["preview-update-timer"]
      local stopf = timer.stop
      local closef = timer.close
      if stopf then
        pcall(stopf, timer)
      else
      end
      if closef then
        pcall(closef, timer)
      else
      end
      session["preview-update-timer"] = nil
    else
    end
    session["preview-update-pending"] = false
    session["lazy-refresh-dirty"] = false
    session["lazy-refresh-pending"] = false
    session["syntax-refresh-dirty"] = false
    session["syntax-refresh-pending"] = false
    return nil
  else
    return nil
  end
end
M["schedule-prompt-update!"] = function(ctx, session, wait_ms)
  local active_by_prompt = ctx["active-by-prompt"]
  local apply_prompt_lines = ctx["apply-prompt-lines"]
  local prompt_update_delay_ms = ctx["prompt-update-delay-ms"]
  local now_ms = ctx["now-ms"]
  local cancel_prompt_update_21 = ctx["cancel-prompt-update!"]
  if session then
    cancel_prompt_update_21(session)
    session["prompt-update-pending"] = true
    session["prompt-update-token"] = (1 + (session["prompt-update-token"] or 0))
    local token = session["prompt-update-token"]
    local timer = vim.loop.new_timer()
    session["prompt-update-timer"] = timer
    local function _25_()
      if (session["prompt-update-timer"] and (session["prompt-update-timer"] == timer)) then
        cancel_prompt_update_21(session)
      else
      end
      if (session and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and (token == session["prompt-update-token"]) and session["prompt-update-dirty"]) then
        local now = now_ms()
        local quiet_for = (now - (session["prompt-last-change-ms"] or 0))
        local need_quiet = math.max(0, prompt_update_delay_ms(session))
        if (quiet_for < need_quiet) then
          return M["schedule-prompt-update!"](ctx, session, math.max(1, (need_quiet - quiet_for)))
        else
          session["prompt-update-dirty"] = false
          session["prompt-last-apply-ms"] = now
          return apply_prompt_lines(session)
        end
      else
        return nil
      end
    end
    return timer.start(timer, math.max(0, wait_ms), 0, vim.schedule_wrap(_25_))
  else
    return nil
  end
end
local function session_by_prompt(active_by_prompt, prompt_buf)
  return active_by_prompt[prompt_buf]
end
M["prompt-insert-at-cursor!"] = function(active_by_prompt, prompt_buf, text)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"]) and (type(text) == "string") and (text ~= "")) then
    local _let_30_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_30_[1]
    local col = _let_30_[2]
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
    local _let_33_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_33_[1]
    local col = _let_33_[2]
    return {row = math.max(1, row), row0 = math.max(0, (row - 1)), col = math.max(0, col)}
  else
    return {row = 1, row0 = 0, col = 0}
  end
end
local function prompt_line_text(session, row0)
  local lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)
  return (lines[1] or "")
end
M["prompt-home!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_35_ = prompt_row_col(session)
    local row = _let_35_.row
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, 0})
  else
    return nil
  end
end
M["prompt-end!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_37_ = prompt_row_col(session)
    local row = _let_37_.row
    local row0 = _let_37_.row0
    local line = prompt_line_text(session, row0)
    return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, #line})
  else
    return nil
  end
end
M["prompt-kill-backward!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_39_ = prompt_row_col(session)
    local row = _let_39_.row
    local row0 = _let_39_.row0
    local col = _let_39_.col
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
M["prompt-kill-forward!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_42_ = prompt_row_col(session)
    local row = _let_42_.row
    local row0 = _let_42_.row0
    local col = _let_42_.col
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
M["prompt-yank!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  local text = ((session and session["prompt-yank-register"]) or "")
  if (text ~= "") then
    return M["prompt-insert-at-cursor!"](active_by_prompt, prompt_buf, text)
  else
    return nil
  end
end
M["prompt-insert-text!"] = function(active_by_prompt, prompt_buf, text)
  return M["prompt-insert-at-cursor!"](active_by_prompt, prompt_buf, text)
end
local function prompt_buffer_text(session)
  if (session and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
    return table.concat(vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false), "\n")
  else
    return ""
  end
end
local function should_insert_history_fragment_3f(session, fragment)
  local needle = (fragment or "")
  local hay = prompt_buffer_text(session)
  return ((needle ~= "") and not string.find(hay, needle, 1, true))
end
M["insert-last-prompt!"] = function(active_by_prompt, history_api, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  local entry = history_api["history-latest"](session)
  if should_insert_history_fragment_3f(session, entry) then
    M["prompt-insert-at-cursor!"](active_by_prompt, prompt_buf, entry)
  else
  end
  if (session and (entry ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
M["insert-last-token!"] = function(active_by_prompt, history_api, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  local token = history_api["history-latest-token"](session)
  local entry = history_api["history-latest"](session)
  if should_insert_history_fragment_3f(session, token) then
    M["prompt-insert-at-cursor!"](active_by_prompt, prompt_buf, token)
  else
  end
  if (session and (token ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
M["insert-last-tail!"] = function(active_by_prompt, history_api, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  local tail = history_api["history-latest-tail"](session)
  local entry = history_api["history-latest"](session)
  if should_insert_history_fragment_3f(session, tail) then
    M["prompt-insert-at-cursor!"](active_by_prompt, prompt_buf, tail)
  else
  end
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
M["negate-current-token!"] = function(active_by_prompt, prompt_buf)
  local session = session_by_prompt(active_by_prompt, prompt_buf)
  if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
    local _let_57_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
    local row = _let_57_[1]
    local col = _let_57_[2]
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
      local _59_
      if (col >= s0) then
        _59_ = delta
      else
        _59_ = 0
      end
      return pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, math.max(0, (col + _59_))})
    else
      return nil
    end
  else
    return nil
  end
end
return M
