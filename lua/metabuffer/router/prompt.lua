-- [nfnl] fnl/metabuffer/router/prompt.fnl
local M = {}
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
  local qlen
  do
    local lines = prompt_lines(session)
    local parsed
    if session["project-mode"] then
      parsed = query_mod["parse-query-lines"](lines)
    else
      parsed = {lines = lines}
    end
    local last_active
    do
      local s = ""
      for _, line in ipairs((parsed.lines or {})) do
        local trimmed = vim.trim((line or ""))
        if (trimmed ~= "") then
          s = trimmed
        else
        end
      end
      last_active = s
    end
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
  return (base + short_extra + scale + extra)
end
M["prompt-has-active-query?"] = function(query_mod, prompt_lines, session)
  local parsed = query_mod["parse-query-lines"](prompt_lines(session))
  local has = false
  for _, line in ipairs((parsed.lines or {})) do
    if (not has and (vim.trim((line or "")) ~= "")) then
      has = true
    else
    end
  end
  return has
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
    local function _19_()
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
    return timer.start(timer, math.max(0, wait_ms), 0, vim.schedule_wrap(_19_))
  else
    return nil
  end
end
return M
