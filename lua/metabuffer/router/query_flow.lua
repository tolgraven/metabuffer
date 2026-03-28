-- [nfnl] fnl/metabuffer/router/query_flow.fnl
local router_util_mod = require("metabuffer.router.util")
local router_prompt_mod = require("metabuffer.router.prompt")
local source_mod = require("metabuffer.source")
local transform_mod = require("metabuffer.transform")
local events = require("metabuffer.events")
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
local function schedule_update_21(prompt_scheduler_ctx, session, delay)
  return router_prompt_mod["schedule-prompt-update!"](prompt_scheduler_ctx, session, delay)
end
local function force_within_idle_window_3f(settings, session, now)
  return ((math.max(0, (settings["prompt-update-idle-ms"] or 0)) > 0) and ((now - (session["prompt-last-change-ms"] or 0)) < math.max(0, (settings["prompt-update-idle-ms"] or 0))))
end
local function queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, now, delay)
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
local function resolve_parsed_query(query_mod, session, parsed)
  return query_mod["apply-default-source"](parsed, (session and query_mod["truthy?"](session["default-include-lgrep"])))
end
local function source_flags_changed_3f(session, parsed)
  local next_hidden = choose_current_when_nil(parsed["include-hidden"], session["include-hidden"])
  local next_ignored = choose_current_when_nil(parsed["include-ignored"], session["include-ignored"])
  local next_deps = choose_current_when_nil(parsed["include-deps"], session["include-deps"])
  local next_binary = choose_current_when_nil(parsed["include-binary"], session["include-binary"])
  local next_files = choose_current_when_nil(parsed["include-files"], session["include-files"])
  local next_transforms = transform_mod["enabled-map"](parsed, session, nil)
  local next_source = source_mod["query-source-signature"](parsed)
  local cur_source = source_mod["query-source-signature"]((session["last-parsed-query"] or {}))
  return ((next_hidden ~= session["effective-include-hidden"]) or (next_ignored ~= session["effective-include-ignored"]) or (next_deps ~= session["effective-include-deps"]) or (next_binary ~= session["effective-include-binary"]) or (next_files ~= session["effective-include-files"]) or (transform_mod.signature(next_transforms) ~= transform_mod.signature((session["effective-transforms"] or {}))) or (next_source ~= cur_source))
end
local function render_flags_changed_3f(session, parsed)
  local next_prefilter = choose_current_when_nil(parsed.prefilter, session["prefilter-mode"])
  local next_lazy = choose_current_when_nil(parsed.lazy, session["lazy-mode"])
  local next_expansion = choose_current_when_nil(parsed.expansion, session["expansion-mode"])
  return ((next_prefilter ~= session["prefilter-mode"]) or (next_lazy ~= session["lazy-mode"]) or (next_expansion ~= session["expansion-mode"]))
end
local function file_lines_changed_3f(session, parsed)
  local prev = (session["file-query-lines"] or {})
  local next = (parsed["file-lines"] or {})
  local n = #next
  if (n ~= #prev) then
    return true
  else
    local diff = false
    for i = 1, n do
      if (not diff and (prev[i] ~= next[i])) then
        diff = true
      else
      end
    end
    return diff
  end
end
local function dispatch_directive_changes_21(session, parsed)
  local directive_mod = require("metabuffer.query.directive")
  local prev = (session["last-parsed-query"] or {})
  local seen = {}
  for _, spec in ipairs(directive_mod["all-specs"]()) do
    local key = spec["token-key"]
    if (key and not seen[key]) then
      seen[key] = true
      local old_val = prev[key]
      local new_val = parsed[key]
      if (old_val ~= new_val) then
        events.send("on-directive!", {session = session, key = key, value = new_val, change = {old = old_val, new = new_val, ["activated?"] = ((old_val == nil) and (new_val ~= nil)), ["deactivated?"] = ((old_val ~= nil) and (new_val == nil)), kind = (spec.kind or ""), ["provider-type"] = (spec["provider-type"] or "")}})
      else
      end
    else
    end
  end
  return nil
end
local function retry_textlock_update_21(session)
  local function _9_()
    if (session.meta and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      pcall(session.meta["on-update"], 0)
      return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true, ["capture-sign-baseline?"] = true})
    else
      return nil
    end
  end
  return vim.defer_fn(_9_, 1)
end
local function run_meta_update_21(session)
  local ok,err = pcall(session.meta["on-update"], 0)
  if ok then
    return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true, ["capture-sign-baseline?"] = true})
  else
    if string.find(tostring(err), "E565") then
      return retry_textlock_update_21(session)
    else
      return nil
    end
  end
end
local function consume_visible_control_token_3f(query_mod, tok)
  local parsed = query_mod["parse-query-lines"]({(tok or "")})
  return (((parsed["include-hidden"] ~= nil) or (parsed["include-ignored"] ~= nil) or (parsed["include-deps"] ~= nil) or (parsed["include-binary"] ~= nil) or (parsed.prefilter ~= nil) or (parsed.lazy ~= nil) or parsed.history or parsed["saved-browser"] or ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "")) or ((type(parsed["saved-tag"]) == "string") and (vim.trim(parsed["saved-tag"]) ~= ""))) and (parsed["include-files"] == nil) and (parsed["include-binary"] == nil) and (transform_mod.signature(transform_mod["enabled-map"](parsed, nil, nil)) == ""))
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
  local mods = deps.mods
  local project = deps.project
  local history = deps.history
  local query_mod = mods.query
  local project_source = project.source
  local merge_history_into_session_21 = history["merge-into-session!"]
  local save_current_prompt_tag_21 = history["save-current-prompt-tag!"]
  local restore_saved_prompt_tag_21 = history["restore-saved-prompt-tag!"]
  local open_saved_browser_21 = history["open-saved-browser!"]
  if (session and not session.closing and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and not session["_rewriting-visible-controls"]) then
    local raw_lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
    local parsed = resolve_parsed_query(query_mod, session, query_mod["parse-query-lines"](raw_lines))
    local lines = parsed.lines
    local consume_visible_controls_3f = false
    local effective_lines = lines
    local effective_text = table.concat(effective_lines, "\n")
    local next_hidden = choose_current_when_nil(parsed["include-hidden"], session["include-hidden"])
    local next_ignored = choose_current_when_nil(parsed["include-ignored"], session["include-ignored"])
    local next_deps = choose_current_when_nil(parsed["include-deps"], session["include-deps"])
    local next_binary = choose_current_when_nil(parsed["include-binary"], session["include-binary"])
    local next_files = choose_current_when_nil(parsed["include-files"], session["include-files"])
    local next_transforms = transform_mod["enabled-map"](parsed, session, nil)
    local next_prefilter = choose_current_when_nil(parsed.prefilter, session["prefilter-mode"])
    local next_lazy = choose_current_when_nil(parsed.lazy, session["lazy-mode"])
    local next_expansion = choose_current_when_nil(parsed.expansion, session["expansion-mode"])
    local schedule_source_set_rebuild_21 = project_source["schedule-source-set-rebuild!"]
    local apply_source_set_21 = project_source["apply-source-set!"]
    local prev_source = source_mod["query-source-signature"]((session["last-parsed-query"] or {}))
    local next_source = source_mod["query-source-signature"](parsed)
    local prev_effective_text = (session["prompt-last-applied-text"] or "")
    local text_changed_3f = (effective_text ~= prev_effective_text)
    local source_changed_3f = source_flags_changed_3f(session, parsed)
    local render_changed_3f = render_flags_changed_3f(session, parsed)
    local changed = (source_changed_3f or render_changed_3f)
    if (parsed.history and merge_history_into_session_21) then
      merge_history_into_session_21(session)
    else
    end
    if ((type(parsed["save-tag"]) == "string") and (vim.trim(parsed["save-tag"]) ~= "") and save_current_prompt_tag_21) then
      save_current_prompt_tag_21(session, parsed["save-tag"], effective_text)
    else
    end
    if ((type(parsed["saved-tag"]) == "string") and (vim.trim(parsed["saved-tag"]) ~= "") and restore_saved_prompt_tag_21) then
      restore_saved_prompt_tag_21(session, parsed["saved-tag"])
    else
    end
    if (parsed["saved-browser"] and open_saved_browser_21) then
      open_saved_browser_21(session)
    else
    end
    dispatch_directive_changes_21(session, parsed)
    session["effective-include-hidden"] = next_hidden
    session["effective-include-ignored"] = next_ignored
    session["effective-include-deps"] = next_deps
    session["effective-include-binary"] = next_binary
    session["effective-include-files"] = next_files
    session["include-hidden"] = next_hidden
    session["include-ignored"] = next_ignored
    session["include-deps"] = next_deps
    session["include-binary"] = next_binary
    session["include-files"] = next_files
    transform_mod["apply-flags!"](session, next_transforms)
    session["prefilter-mode"] = next_prefilter
    session["lazy-mode"] = next_lazy
    session["expansion-mode"] = next_expansion
    session["last-parsed-query"] = parsed
    session["file-query-lines"] = (parsed["file-lines"] or {})
    session["last-prompt-text"] = effective_text
    session["prompt-last-applied-text"] = effective_text
    session.meta["file-query-lines"] = (parsed["file-lines"] or {})
    session.meta["include-binary"] = next_binary
    session.meta["include-files"] = next_files
    transform_mod["apply-flags!"](session.meta, next_transforms)
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
    if (changed or text_changed_3f or file_lines_changed_3f(session, parsed)) then
      invalidate_filter_cache_21(session)
    else
    end
    if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      pcall(vim.api.nvim_buf_set_var, session.meta.buf.buffer, "meta_manual_edit_active", false)
    else
    end
    if ((session["project-mode"] or session["active-source-key"] or source_mod["query-source-active?"](parsed)) and source_changed_3f) then
      if (next_source ~= prev_source) then
        events.send("on-source-switch!", {session = session, ["old-source"] = prev_source, ["new-source"] = next_source})
      else
      end
      if schedule_source_set_rebuild_21 then
        schedule_source_set_rebuild_21(session, 0)
      else
        if apply_source_set_21 then
          apply_source_set_21(session)
        else
        end
      end
    else
    end
    session.meta["set-query-lines"](effective_lines)
    if (session["project-mode"] and source_changed_3f and not text_changed_3f) then
      return events.send("on-query-update!", {session = session, query = effective_text, ["refresh-lines"] = true, ["refresh-signs?"] = true, ["capture-sign-baseline?"] = true})
    else
      return run_meta_update_21(session)
    end
  else
    return nil
  end
end
M["on-prompt-changed!"] = function(deps, prompt_buf, force, event_tick)
  local router = deps.router
  local mods = deps.mods
  local project = deps.project
  local state = deps.state
  local active_by_prompt = router["active-by-prompt"]
  local query_mod = mods.query
  local project_source = project.source
  local settings = router
  local prompt_scheduler_ctx = state["prompt-scheduler-ctx"]
  local session = active_by_prompt[prompt_buf]
  if (session and not session.closing) then
    local lines = router_util_mod["prompt-lines"](session)
    local parsed = resolve_parsed_query(query_mod, session, query_mod["parse-query-lines"](lines))
    local effective_text = table.concat((parsed.lines or {}), "\n")
    local no_flag_change_3f = (not source_flags_changed_3f(session, parsed) and not render_flags_changed_3f(session, parsed))
    local pure_flag_edit_3f = ((effective_text ~= (session["prompt-last-event-text"] or "")) and (effective_text == (session["prompt-last-applied-text"] or "")) and (source_flags_changed_3f(session, parsed) or render_flags_changed_3f(session, parsed)))
    local noop_3f = (not force and no_flag_change_3f and not file_lines_changed_3f(session, parsed) and (effective_text == (session["prompt-last-applied-text"] or "")) and (effective_text == (session["prompt-last-event-text"] or "")))
    local now = router_prompt_mod["now-ms"]()
    local delay = prompt_delay_ms(settings, query_mod, session)
    if not noop_3f then
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
      if (session["project-mode"] and not session["project-bootstrapped"]) then
        project_source["schedule-project-bootstrap!"](session, settings["project-bootstrap-delay-ms"])
      else
      end
      if pure_flag_edit_3f then
        session["prompt-last-event-text"] = effective_text
        session["last-prompt-text"] = effective_text
        session["prompt-last-change-ms"] = now
        session["prompt-update-dirty"] = false
        router_prompt_mod["cancel-prompt-update!"](session)
        return M["apply-prompt-lines!"](deps, session)
      else
        return queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, now, delay)
      end
    else
      return nil
    end
  else
    return nil
  end
end
return M
