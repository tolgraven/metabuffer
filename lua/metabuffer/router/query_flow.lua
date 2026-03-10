-- [nfnl] fnl/metabuffer/router/query_flow.fnl
local router_util_mod = require("metabuffer.router.util")
local router_prompt_mod = require("metabuffer.router.prompt")
local M = {}
local function choose_current_when_nil(query_mod, value, current)
  return query_mod["resolve-option"](value, current)
end
local function prompt_delay_ms(settings, query_mod, session)
  return router_prompt_mod["prompt-update-delay-ms"](settings, query_mod, router_util_mod["prompt-lines"], session)
end
local function prompt_has_active_query_3f(query_mod, session)
  return router_prompt_mod["prompt-has-active-query?"](query_mod, router_util_mod["prompt-lines"], session)
end
local function schedule_update_21(prompt_scheduler_ctx, session, delay)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, delay)
end
local function recent_identical_forced_refresh_3f(settings, session, txt, now)
  return ((txt == (session["prompt-last-applied-text"] or "")) and (math.max(0, (settings["prompt-forced-coalesce-ms"] or 0)) > 0) and ((now - (session["prompt-last-apply-ms"] or 0)) < math.max(0, (settings["prompt-forced-coalesce-ms"] or 0))))
end
local function force_blocked_by_active_input_3f(settings, session, now)
  return ((now - (session["prompt-last-change-ms"] or 0)) < math.max(math.max(0, (settings["prompt-update-idle-ms"] or 0)), math.max(0, (settings["prompt-forced-coalesce-ms"] or 0))))
end
local function force_within_idle_window_3f(settings, session, now)
  return ((math.max(0, (settings["prompt-update-idle-ms"] or 0)) > 0) and ((now - (session["prompt-last-change-ms"] or 0)) < math.max(0, (settings["prompt-update-idle-ms"] or 0))))
end
local function queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, txt, now, delay)
  if not (force and session["prompt-update-pending"]) then
    if (force and force_within_idle_window_3f(settings, session, now)) then
      return schedule_update_21(prompt_scheduler_ctx, session, math.max(delay, settings["prompt-update-idle-ms"]))
    else
      return schedule_update_21(prompt_scheduler_ctx, session, delay)
    end
  else
    return nil
  end
end
local function apply_fresh_prompt_event_21(query_mod, project_source, settings, prompt_scheduler_ctx, session, force, txt, now, delay)
  session["prompt-last-event-text"] = txt
  session["last-prompt-text"] = txt
  session["prompt-update-dirty"] = true
  session["prompt-last-change-ms"] = now
  if not force then
    session["prompt-force-block-until"] = (now + math.max(0, delay))
  else
  end
  session["prompt-change-seq"] = (1 + (session["prompt-change-seq"] or 0))
  if (session["project-mode"] and not session["project-bootstrapped"] and prompt_has_active_query_3f(query_mod, session)) then
    project_source["schedule-project-bootstrap!"](session, settings["project-bootstrap-delay-ms"])
  else
  end
  return queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, txt, now, delay)
end
local function apply_duplicate_text_event_21(prompt_scheduler_ctx, session, now, delay)
  session["prompt-last-change-ms"] = now
  session["prompt-force-block-until"] = (now + math.max(0, delay))
  session["prompt-update-dirty"] = true
  return schedule_update_21(prompt_scheduler_ctx, session, delay)
end
local function invalidate_filter_cache_21(session)
  if (session and session.meta) then
    session.meta._prev_text = ""
    session.meta["_filter-cache"] = {}
    session.meta["_filter-cache-line-count"] = #session.meta.buf.content
    return nil
  else
    return nil
  end
end
M["apply-prompt-lines!"] = function(deps, session)
  local query_mod = deps["query-mod"]
  local project_source = deps["project-source"]
  local update_info_window = deps["update-info-window"]
  local merge_history_into_session_21 = deps["merge-history-into-session!"]
  local save_current_prompt_tag_21 = deps["save-current-prompt-tag!"]
  local restore_saved_prompt_tag_21 = deps["restore-saved-prompt-tag!"]
  local open_saved_browser_21 = deps["open-saved-browser!"]
  if (session and not session.closing and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
    local raw_lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
    do
      local parsed = query_mod["parse-query-lines"](raw_lines)
      local lines = parsed.lines
      local consume_controls_3f = ((parsed["include-hidden"] ~= nil) or (parsed["include-ignored"] ~= nil) or (parsed["include-deps"] ~= nil) or (parsed.prefilter ~= nil) or (parsed.lazy ~= nil) or parsed.history or parsed["saved-browser"] or ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "")) or ((type(parsed["saved-tag"]) == "string") and (vim.trim(parsed["saved-tag"]) ~= "")))
      local effective_lines
      if consume_controls_3f then
        effective_lines = lines
      else
        effective_lines = raw_lines
      end
      local effective_text = table.concat(effective_lines, "\n")
      local prompt_text = table.concat(lines, "\n")
      local raw_text = table.concat(raw_lines, "\n")
      local stripped_3f = (consume_controls_3f and (prompt_text ~= raw_text))
      local _
      if stripped_3f then
        local cursor
        if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
          cursor = vim.api.nvim_win_get_cursor(session["prompt-win"])
        else
          cursor = {1, 0}
        end
        local row = cursor[1]
        local col = cursor[2]
        vim.api.nvim_buf_set_lines(session["prompt-buf"], 0, -1, false, effective_lines)
        if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"])) then
          local line = (effective_lines[row] or "")
          local max_col = #line
          _ = pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, math.min(col, max_col)})
        else
          _ = nil
        end
      else
        _ = nil
      end
      local _0
      if (parsed.history and merge_history_into_session_21) then
        _0 = merge_history_into_session_21(session)
      else
        _0 = nil
      end
      local _1
      if ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "") and save_current_prompt_tag_21) then
        _1 = save_current_prompt_tag_21(session, parsed["save-tag"], prompt_text)
      else
        _1 = nil
      end
      local _2
      if ((type(parsed["saved-tag"]) == "string") and (vim.trim(parsed["saved-tag"]) ~= "") and restore_saved_prompt_tag_21) then
        _2 = restore_saved_prompt_tag_21(session, parsed["saved-tag"])
      else
        _2 = nil
      end
      local _3
      if (parsed["saved-browser"] and open_saved_browser_21) then
        _3 = open_saved_browser_21(session)
      else
        _3 = nil
      end
      local next_hidden = choose_current_when_nil(query_mod, parsed["include-hidden"], session["include-hidden"])
      local next_ignored = choose_current_when_nil(query_mod, parsed["include-ignored"], session["include-ignored"])
      local next_deps = choose_current_when_nil(query_mod, parsed["include-deps"], session["include-deps"])
      local next_prefilter = choose_current_when_nil(query_mod, parsed.prefilter, session["prefilter-mode"])
      local next_lazy = choose_current_when_nil(query_mod, parsed.lazy, session["lazy-mode"])
      local prev_effective_text = (session["prompt-last-applied-text"] or "")
      local text_changed_3f = (effective_text ~= prev_effective_text)
      local changed = ((next_hidden ~= session["effective-include-hidden"]) or (next_ignored ~= session["effective-include-ignored"]) or (next_deps ~= session["effective-include-deps"]) or (next_prefilter ~= session["prefilter-mode"]) or (next_lazy ~= session["lazy-mode"]))
      session["effective-include-hidden"] = next_hidden
      session["effective-include-ignored"] = next_ignored
      session["effective-include-deps"] = next_deps
      session["prefilter-mode"] = next_prefilter
      session["lazy-mode"] = next_lazy
      session["last-parsed-query"] = parsed
      session["last-prompt-text"] = effective_text
      session["prompt-last-applied-text"] = effective_text
      if session["project-mode"] then
        local flags
        local _14_
        if session["effective-include-hidden"] then
          _14_ = "+hidden"
        else
          _14_ = "-hidden"
        end
        local _16_
        if session["effective-include-ignored"] then
          _16_ = "+ignored"
        else
          _16_ = "-ignored"
        end
        local _18_
        if session["effective-include-deps"] then
          _18_ = "+deps"
        else
          _18_ = "-deps"
        end
        local function _20_()
          if session["prefilter-mode"] then
            return "+prefilter"
          else
            return "-prefilter"
          end
        end
        flags = {_14_, _16_, _18_, _20_()}
        if not session["lazy-mode"] then
          table.insert(flags, "-lazy")
        else
        end
        session.meta.debug_out = (" [" .. table.concat(flags, " ") .. "]")
      else
        session.meta.debug_out = ""
      end
      if (changed or text_changed_3f) then
        invalidate_filter_cache_21(session)
      else
      end
      if (session["project-mode"] and changed) then
        project_source["apply-source-set!"](session)
      else
      end
      session.meta["set-query-lines"](effective_lines)
    end
    local ok,err = pcall(session.meta["on-update"], 0)
    if ok then
      session.meta.refresh_statusline()
      return update_info_window(session)
    else
      if string.find(tostring(err), "E565") then
        local function _25_()
          if (session.meta and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
            pcall(session.meta["on-update"], 0)
            pcall(session.meta.refresh_statusline)
            return pcall(update_info_window, session)
          else
            return nil
          end
        end
        return vim.defer_fn(_25_, 1)
      else
        return nil
      end
    end
  else
    return nil
  end
end
M["on-prompt-changed!"] = function(deps, prompt_buf, force, event_tick)
  local active_by_prompt = deps["active-by-prompt"]
  local query_mod = deps["query-mod"]
  local project_source = deps["project-source"]
  local settings = deps.settings
  local prompt_scheduler_ctx = deps["prompt-scheduler-ctx"]
  local session = active_by_prompt[prompt_buf]
  if (session and not session.closing) then
    local now = router_prompt_mod["now-ms"]()
    local delay = prompt_delay_ms(settings, query_mod, session)
    if (not force and event_tick) then
      session["prompt-last-event-tick"] = event_tick
    else
    end
    session["prompt-update-dirty"] = true
    session["prompt-last-change-ms"] = now
    if not force then
      session["prompt-force-block-until"] = (now + math.max(0, delay))
    else
    end
    session["prompt-change-seq"] = (1 + (session["prompt-change-seq"] or 0))
    if (session["project-mode"] and not session["project-bootstrapped"] and prompt_has_active_query_3f(query_mod, session)) then
      project_source["schedule-project-bootstrap!"](session, settings["project-bootstrap-delay-ms"])
    else
    end
    return queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, "", now, delay)
  else
    return nil
  end
end
return M
