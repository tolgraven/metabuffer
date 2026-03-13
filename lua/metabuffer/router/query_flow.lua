-- [nfnl] fnl/metabuffer/router/query_flow.fnl
local router_util_mod = require("metabuffer.router.util")
local router_prompt_mod = require("metabuffer.router.prompt")
local M = {}
local function choose_current_when_nil(value, current)
  local val_113_auto = value
  if (nil ~= val_113_auto) then
    local v = val_113_auto
    return v
  else
    return current
  end
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
local function consume_visible_control_token_3f(query_mod, tok)
  local parsed = query_mod["parse-query-lines"]({(tok or "")})
  return (((parsed["include-hidden"] ~= nil) or (parsed["include-ignored"] ~= nil) or (parsed["include-deps"] ~= nil) or (parsed["include-binary"] ~= nil) or (parsed["include-hex"] ~= nil) or (parsed.prefilter ~= nil) or (parsed.lazy ~= nil) or parsed.history or parsed["saved-browser"] or ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "")) or ((type(parsed["saved-tag"]) == "string") and (vim.trim(parsed["saved-tag"]) ~= ""))) and (parsed["include-files"] == nil) and (parsed["include-binary"] == nil) and (parsed["include-hex"] == nil))
end
local function consume_visible_controls_lines(query_mod, raw_lines)
  local out = {}
  for _, line in ipairs((raw_lines or {})) do
    local parts = vim.split((line or ""), "%s+", {trimempty = true})
    local kept = {}
    for _0, tok in ipairs(parts) do
      if not consume_visible_control_token_3f(query_mod, tok) then
        table.insert(kept, tok)
      else
      end
    end
    table.insert(out, table.concat(kept, " "))
  end
  return out
end
M["apply-prompt-lines!"] = function(deps, session)
  local query_mod = deps["query-mod"]
  local project_source = deps["project-source"]
  local update_info_window = deps["update-info-window"]
  local refresh_change_signs_21 = deps["refresh-change-signs!"]
  local capture_sign_baseline_21 = deps["capture-sign-baseline!"]
  local settings = deps.settings
  local merge_history_into_session_21 = deps["merge-history-into-session!"]
  local save_current_prompt_tag_21 = deps["save-current-prompt-tag!"]
  local restore_saved_prompt_tag_21 = deps["restore-saved-prompt-tag!"]
  local open_saved_browser_21 = deps["open-saved-browser!"]
  if (session and not session.closing and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and not session["_rewriting-visible-controls"]) then
    local raw_lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
    do
      local parsed = query_mod["parse-query-lines"](raw_lines)
      local lines = parsed.lines
      local consume_visible_controls_3f = false
      local effective_lines = lines
      local effective_text = table.concat(effective_lines, "\n")
      local _ = false
      local _0
      if (parsed.history and merge_history_into_session_21) then
        _0 = merge_history_into_session_21(session)
      else
        _0 = nil
      end
      local _1
      if ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "") and save_current_prompt_tag_21) then
        _1 = save_current_prompt_tag_21(session, parsed["save-tag"], effective_text)
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
      local next_hidden = choose_current_when_nil(parsed["include-hidden"], session["include-hidden"])
      local next_ignored = choose_current_when_nil(parsed["include-ignored"], session["include-ignored"])
      local next_deps = choose_current_when_nil(parsed["include-deps"], session["include-deps"])
      local next_binary = choose_current_when_nil(parsed["include-binary"], session["include-binary"])
      local next_hex = choose_current_when_nil(parsed["include-hex"], session["include-hex"])
      local next_files = choose_current_when_nil(parsed["include-files"], session["include-files"])
      local next_prefilter = choose_current_when_nil(parsed.prefilter, session["prefilter-mode"])
      local next_lazy = choose_current_when_nil(parsed.lazy, session["lazy-mode"])
      local prev_effective_text = (session["prompt-last-applied-text"] or "")
      local text_changed_3f = (effective_text ~= prev_effective_text)
      local changed = ((next_hidden ~= session["effective-include-hidden"]) or (next_ignored ~= session["effective-include-ignored"]) or (next_deps ~= session["effective-include-deps"]) or (next_binary ~= session["effective-include-binary"]) or (next_hex ~= session["effective-include-hex"]) or (next_files ~= session["effective-include-files"]) or (next_prefilter ~= session["prefilter-mode"]) or (next_lazy ~= session["lazy-mode"]))
      session["effective-include-hidden"] = next_hidden
      session["effective-include-ignored"] = next_ignored
      session["effective-include-deps"] = next_deps
      session["effective-include-binary"] = next_binary
      session["effective-include-hex"] = next_hex
      session["effective-include-files"] = next_files
      session["include-hidden"] = next_hidden
      session["include-ignored"] = next_ignored
      session["include-deps"] = next_deps
      session["include-binary"] = next_binary
      session["include-hex"] = next_hex
      session["include-files"] = next_files
      session["prefilter-mode"] = next_prefilter
      session["lazy-mode"] = next_lazy
      session["last-parsed-query"] = parsed
      session["file-query-lines"] = (parsed["file-lines"] or {})
      session["last-prompt-text"] = effective_text
      session["prompt-last-applied-text"] = effective_text
      session.meta["file-query-lines"] = (parsed["file-lines"] or {})
      session.meta["include-binary"] = next_binary
      session.meta["include-hex"] = next_hex
      session.meta["include-files"] = next_files
      if consume_visible_controls_3f then
        local visible_lines = consume_visible_controls_lines(query_mod, raw_lines)
        local visible_text = table.concat(visible_lines, "\n")
        local raw_text = table.concat(raw_lines, "\n")
        if (visible_text ~= raw_text) then
          session["_rewriting-visible-controls"] = true
          vim.api.nvim_buf_set_lines(session["prompt-buf"], 0, -1, false, visible_lines)
          session["_rewriting-visible-controls"] = false
        else
        end
      else
      end
      session.meta.debug_out = ""
      if (changed or text_changed_3f) then
        invalidate_filter_cache_21(session)
      else
      end
      if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        pcall(vim.api.nvim_buf_set_var, session.meta.buf.buffer, "meta_manual_edit_active", false)
      else
      end
      if (session["project-mode"] and changed and project_source["schedule-source-set-rebuild!"]) then
        project_source["schedule-source-set-rebuild!"](session, 0)
      else
      end
      session.meta["set-query-lines"](effective_lines)
    end
    local ok,err = pcall(session.meta["on-update"], 0)
    if ok then
      session.meta.refresh_statusline()
      update_info_window(session)
      if refresh_change_signs_21 then
        refresh_change_signs_21(session)
      else
      end
      if capture_sign_baseline_21 then
        return capture_sign_baseline_21(session)
      else
        return nil
      end
    else
      if string.find(tostring(err), "E565") then
        local function _19_()
          if (session.meta and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
            pcall(session.meta["on-update"], 0)
            pcall(session.meta.refresh_statusline)
            pcall(update_info_window, session)
            if refresh_change_signs_21 then
              pcall(refresh_change_signs_21, session)
            else
            end
            if capture_sign_baseline_21 then
              return pcall(capture_sign_baseline_21, session)
            else
              return nil
            end
          else
            return nil
          end
        end
        return vim.defer_fn(_19_, 1)
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
    if not force then
      session["prompt-last-change-ms"] = now
      session["prompt-force-block-until"] = (now + math.max(0, delay))
    else
    end
    if not force then
      session["prompt-change-seq"] = (1 + (session["prompt-change-seq"] or 0))
    else
    end
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
