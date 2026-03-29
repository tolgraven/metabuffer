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
local function invalidate_info_refresh_state_21(session)
  if session then
    session["info-render-sig"] = nil
    session["info-line-meta-range-key"] = nil
    session["info-project-finish-refresh-pending?"] = false
    session["info-highlight-fill-pending?"] = false
    session["info-showing-project-loading?"] = nil
    session["info-project-loading-active?"] = nil
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
  local next = ((parsed and parsed["file-lines"]) or {})
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
  local function _10_()
    if (session.meta and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      pcall(session.meta["on-update"], 0)
      return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true, ["capture-sign-baseline?"] = true})
    else
      return nil
    end
  end
  return vim.defer_fn(_10_, 1)
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
local function handle_history_directives_21(deps, session, parsed, effective_text)
  local history = deps.history
  local merge_history_into_session_21 = history["merge-into-session!"]
  local save_current_prompt_tag_21 = history["save-current-prompt-tag!"]
  local restore_saved_prompt_tag_21 = history["restore-saved-prompt-tag!"]
  local open_saved_browser_21 = history["open-saved-browser!"]
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
    return open_saved_browser_21(session)
  else
    return nil
  end
end
local function apply_query_state_21(session, parsed, state)
  local effective_text = state["effective-text"]
  local next_hidden = state["next-hidden"]
  local next_ignored = state["next-ignored"]
  local next_deps = state["next-deps"]
  local next_binary = state["next-binary"]
  local next_files = state["next-files"]
  local next_transforms = state["next-transforms"]
  local next_prefilter = state["next-prefilter"]
  local next_lazy = state["next-lazy"]
  local next_expansion = state["next-expansion"]
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
  session["prompt-last-event-text"] = effective_text
  session.meta["file-query-lines"] = (parsed["file-lines"] or {})
  session.meta["include-binary"] = next_binary
  session.meta["include-files"] = next_files
  transform_mod["apply-flags!"](session.meta, next_transforms)
  session.meta.debug_out = ""
  return nil
end
local function maybe_rewrite_visible_controls_21(session, query_mod, raw_lines)
  local consume_visible_controls_3f = false
  if consume_visible_controls_3f then
    local visible_lines = consume_visible_controls_lines(query_mod, raw_lines)
    local visible_text = table.concat(visible_lines, "\n")
    local raw_text = table.concat(raw_lines, "\n")
    if (visible_text ~= raw_text) then
      session["_rewriting-visible-controls"] = true
      vim.api.nvim_buf_set_lines(session["prompt-buf"], 0, -1, false, visible_lines)
      session["_rewriting-visible-controls"] = false
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function maybe_rebuild_source_21(session, parsed, project_source, state)
  local schedule_source_set_rebuild_21 = project_source["schedule-source-set-rebuild!"]
  local apply_source_set_21 = project_source["apply-source-set!"]
  local prev_source = state["prev-source"]
  local next_source = state["next-source"]
  local source_changed_3f = state["source-changed?"]
  if ((session["project-mode"] or session["active-source-key"] or source_mod["query-source-active?"](parsed)) and source_changed_3f) then
    if (next_source ~= prev_source) then
      events.send("on-source-switch!", {session = session, ["old-source"] = prev_source, ["new-source"] = next_source})
    else
    end
    if schedule_source_set_rebuild_21 then
      return schedule_source_set_rebuild_21(session, 0)
    else
      if apply_source_set_21 then
        return apply_source_set_21(session)
      else
        return nil
      end
    end
  else
    return nil
  end
end
local function finish_query_apply_21(session, effective_lines, effective_text, state)
  session.meta["set-query-lines"](effective_lines)
  if (session["project-mode"] and state["source-changed?"] and not state["text-changed?"]) then
    return events.send("on-query-update!", {session = session, query = effective_text, ["refresh-lines"] = true, ["refresh-signs?"] = true, ["capture-sign-baseline?"] = true})
  else
    return run_meta_update_21(session)
  end
end
local function prompt_edit_state(settings, query_mod, session, parsed, force)
  local effective_text = table.concat((parsed.lines or {}), "\n")
  local source_changed_3f = source_flags_changed_3f(session, parsed)
  local render_changed_3f = render_flags_changed_3f(session, parsed)
  local no_flag_change_3f = (not source_changed_3f and not render_changed_3f)
  local pure_flag_edit_3f = ((effective_text ~= (session["prompt-last-event-text"] or "")) and (effective_text == (session["prompt-last-applied-text"] or "")) and (source_changed_3f or render_changed_3f))
  local noop_3f = (not force and no_flag_change_3f and not file_lines_changed_3f(session, parsed) and (effective_text == (session["prompt-last-applied-text"] or "")) and (effective_text == (session["prompt-last-event-text"] or "")))
  return {["effective-text"] = effective_text, ["pure-flag-edit?"] = pure_flag_edit_3f, ["noop?"] = noop_3f, now = router_prompt_mod["now-ms"](), delay = prompt_delay_ms(settings, query_mod, session)}
end
local function mark_prompt_edit_21(session, force, event_tick, state)
  local now = state.now
  local delay = state.delay
  local effective_text = state["effective-text"]
  session["prompt-last-event-text"] = effective_text
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
    return nil
  else
    return nil
  end
end
local function maybe_schedule_bootstrap_21(settings, project_source, session)
  if (session["project-mode"] and not session["project-bootstrapped"]) then
    return project_source["schedule-project-bootstrap!"](session, settings["project-bootstrap-delay-ms"])
  else
    return nil
  end
end
local function run_prompt_edit_21(deps, session, force, state)
  local router = deps.router
  local project = deps.project
  local deps_state = deps.state
  local settings = router
  local project_source = project.source
  local prompt_scheduler_ctx = deps_state["prompt-scheduler-ctx"]
  local now = state.now
  local delay = state.delay
  maybe_schedule_bootstrap_21(settings, project_source, session)
  if state["pure-flag-edit?"] then
    session["last-prompt-text"] = state["effective-text"]
    session["prompt-last-change-ms"] = now
    session["prompt-update-dirty"] = false
    router_prompt_mod["cancel-prompt-update!"](session)
    return M["apply-prompt-lines!"](deps, session)
  else
    return queue_update_after_edit_21(settings, prompt_scheduler_ctx, session, force, now, delay)
  end
end
M["apply-prompt-lines!"] = function(deps, session)
  local mods = deps.mods
  local project = deps.project
  local query_mod = mods.query
  local project_source = project.source
  if (session and not session.closing and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and not session["_rewriting-visible-controls"]) then
    local raw_lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
    local parsed = resolve_parsed_query(query_mod, session, query_mod["parse-query-lines"](raw_lines))
    local lines = parsed.lines
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
    local prev_source = source_mod["query-source-signature"]((session["last-parsed-query"] or {}))
    local next_source = source_mod["query-source-signature"](parsed)
    local prev_effective_text = (session["prompt-last-applied-text"] or "")
    local text_changed_3f = (effective_text ~= prev_effective_text)
    local source_changed_3f = source_flags_changed_3f(session, parsed)
    local render_changed_3f = render_flags_changed_3f(session, parsed)
    local changed = (source_changed_3f or render_changed_3f)
    local state = {["effective-text"] = effective_text, ["next-hidden"] = next_hidden, ["next-ignored"] = next_ignored, ["next-deps"] = next_deps, ["next-binary"] = next_binary, ["next-files"] = next_files, ["next-transforms"] = next_transforms, ["next-prefilter"] = next_prefilter, ["next-lazy"] = next_lazy, ["next-expansion"] = next_expansion, ["prev-source"] = prev_source, ["next-source"] = next_source, ["text-changed?"] = text_changed_3f, ["source-changed?"] = source_changed_3f}
    handle_history_directives_21(deps, session, parsed, effective_text)
    dispatch_directive_changes_21(session, parsed)
    apply_query_state_21(session, parsed, state)
    maybe_rewrite_visible_controls_21(session, query_mod, raw_lines)
    if (changed or text_changed_3f or file_lines_changed_3f(session, parsed)) then
      invalidate_filter_cache_21(session)
    else
    end
    if (text_changed_3f or file_lines_changed_3f(session)) then
      invalidate_info_refresh_state_21(session)
    else
    end
    if (session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      pcall(vim.api.nvim_buf_set_var, session.meta.buf.buffer, "meta_manual_edit_active", false)
    else
    end
    maybe_rebuild_source_21(session, parsed, project_source, state)
    return finish_query_apply_21(session, effective_lines, effective_text, state)
  else
    return nil
  end
end
M["on-prompt-changed!"] = function(deps, prompt_buf, force, event_tick)
  local router = deps.router
  local mods = deps.mods
  local active_by_prompt = router["active-by-prompt"]
  local query_mod = mods.query
  local settings = router
  local session = active_by_prompt[prompt_buf]
  if (session and not session.closing) then
    local lines = router_util_mod["prompt-lines"](session)
    local parsed = resolve_parsed_query(query_mod, session, query_mod["parse-query-lines"](lines))
    local edit_state = prompt_edit_state(settings, query_mod, session, parsed, force)
    if not edit_state["noop?"] then
      mark_prompt_edit_21(session, force, event_tick, edit_state)
      return run_prompt_edit_21(deps, session, force, edit_state)
    else
      return nil
    end
  else
    return nil
  end
end
return M
