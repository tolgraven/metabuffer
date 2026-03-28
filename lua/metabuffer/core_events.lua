-- [nfnl] fnl/metabuffer/core_events.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local events = require("metabuffer.events")
local function refresh_hooks(session)
  return ((session and session["refresh-hooks"]) or {})
end
local function source_refresh_state(session)
  return ((session and session["source-refresh-state"]) or {})
end
local function valid_session_buffer_3f(session)
  return (session and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer))
end
local function prompt_query_active_3f(session)
  local query0 = (session["prompt-last-applied-text"] or "")
  return (vim.trim(query0) ~= "")
end
local function refresh_ui_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  local refresh_lines
  if (args["refresh-lines"] == nil) then
    refresh_lines = true
  else
    refresh_lines = clj.boolean(args["refresh-lines"])
  end
  if session then
    if clj.boolean(args["restore-view?"]) then
      local val_110_auto = hooks["restore-view!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    else
    end
    do
      local val_110_auto = hooks["statusline!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    end
    do
      local val_110_auto = hooks["preview!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    end
    do
      local val_110_auto = hooks["info!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session, refresh_lines)
      else
      end
    end
    do
      local val_110_auto = hooks["context!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    end
    if clj.boolean(args["refresh-signs?"]) then
      local val_110_auto = hooks["refresh-change-signs!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    else
    end
    if clj.boolean(args["capture-sign-baseline?"]) then
      local val_110_auto = hooks["capture-sign-baseline!"]
      if val_110_auto then
        local f = val_110_auto
        return pcall(f, session)
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function refresh_selection_ui_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  if (session and clj.boolean(args["force-refresh?"])) then
    local val_110_auto = hooks["schedule-source-syntax-refresh!"]
    if val_110_auto then
      local f = val_110_auto
      pcall(f, session)
    else
    end
  else
  end
  return refresh_ui_21(args)
end
local function refresh_project_info_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  if session then
    if clj.boolean(args["restore-view?"]) then
      local val_110_auto = hooks["restore-view!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    else
    end
    do
      local val_110_auto = hooks["statusline!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session)
      else
      end
    end
    do
      local val_110_auto = hooks["info!"]
      if val_110_auto then
        local f = val_110_auto
        pcall(f, session, true)
      else
      end
    end
    local val_110_auto = hooks["context!"]
    if val_110_auto then
      local f = val_110_auto
      return pcall(f, session)
    else
      return nil
    end
  else
    return nil
  end
end
local function refresh_statusline_only_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  if session then
    local val_110_auto = hooks["statusline!"]
    if val_110_auto then
      local f = val_110_auto
      return pcall(f, session)
    else
      return nil
    end
  else
    return nil
  end
end
local function reset_source_derived_ui_21(args)
  local session = args.session
  if session then
    session["info-render-sig"] = nil
    session["info-line-meta-range-key"] = nil
    return nil
  else
    return nil
  end
end
local function restore_view_only_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  if session then
    local val_110_auto = hooks["restore-view!"]
    if val_110_auto then
      local f = val_110_auto
      return pcall(f, session)
    else
      return nil
    end
  else
    return nil
  end
end
local function refresh_source_syntax_only_21(args)
  local session = args.session
  local hooks = refresh_hooks(session)
  if session then
    local val_110_auto = hooks["source-syntax!"]
    if val_110_auto then
      local f = val_110_auto
      return pcall(f, session, clj.boolean(args["immediate?"]))
    else
      return nil
    end
  else
    return nil
  end
end
local function update_source_pool_now_21(session, args)
  local phase = args.phase
  local refresh_lines
  if (args["refresh-lines"] == nil) then
    refresh_lines = false
  else
    refresh_lines = clj.boolean(args["refresh-lines"])
  end
  local restore_view_3f = clj.boolean(args["restore-view?"])
  local phase_only_3f = clj.boolean(args["phase-only?"])
  local query_active_3f = prompt_query_active_3f(session)
  local streaming_idle_3f = (not session["lazy-stream-done"] and not query_active_3f)
  local now = math.floor((vim.uv.hrtime() / 1000000))
  local force_3f = clj.boolean(args["force?"])
  if valid_session_buffer_3f(session) then
    if streaming_idle_3f then
      local last_render_ms = (session["lazy-last-render-ms"] or 0)
      local render_interval_ms = 500
      local should_render_3f = (force_3f or ((now - last_render_ms) >= render_interval_ms))
      if should_render_3f then
        session["lazy-last-render-ms"] = now
        session.meta.buf["visible-source-syntax-only"] = false
        if restore_view_3f then
          restore_view_only_21({session = session})
        else
        end
        pcall(session.meta.buf.render)
      else
      end
      return events.send("on-project-bootstrap!", {session = session, ["refresh-lines"] = refresh_lines, ["restore-view?"] = (restore_view_3f and should_render_3f)})
    else
      if not phase_only_3f then
        local ok,err = pcall(session.meta["on-update"], 0)
        if ok then
          events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = refresh_lines})
        else
          if (err and string.find(tostring(err), "E565")) then
            local function _31_()
              if valid_session_buffer_3f(session) then
                pcall(session.meta["on-update"], 0)
                return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = refresh_lines})
              else
                return nil
              end
            end
            vim.defer_fn(_31_, 1)
          else
          end
        end
      else
      end
      if (phase == "bootstrap") then
        events.send("on-project-bootstrap!", {session = session, ["refresh-lines"] = refresh_lines, ["restore-view?"] = restore_view_3f})
      else
      end
      if (phase == "complete") then
        if (not query_active_3f and restore_view_3f) then
          restore_view_only_21({session = session})
        else
        end
        return events.send("on-project-complete!", {session = session, ["refresh-lines"] = refresh_lines, ["restore-view?"] = restore_view_3f})
      else
        return nil
      end
    end
  else
    return nil
  end
end
local function schedule_source_pool_refresh_21(args)
  local session = args.session
  if session then
    local state = source_refresh_state(session)
    local pending = (state.pending or {})
    local merged = {["refresh-lines"] = (pending["refresh-lines"] or clj.boolean(args["refresh-lines"])), ["restore-view?"] = (pending["restore-view?"] or clj.boolean(args["restore-view?"])), ["force?"] = (pending["force?"] or clj.boolean(args["force?"])), ["phase-only?"] = (pending["phase-only?"] or clj.boolean(args["phase-only?"])), phase = (args.phase or pending.phase)}
    state["pending"] = merged
    session["source-refresh-state"] = state
    if clj.boolean(merged["force?"]) then
      state["pending"] = nil
      state["scheduled?"] = false
      return update_source_pool_now_21(session, merged)
    else
      state["dirty?"] = true
      if not state["scheduled?"] then
        state["scheduled?"] = true
        local function _41_()
          if session then
            state["scheduled?"] = false
            if state["dirty?"] then
              state["dirty?"] = false
              do
                local next_args = (state.pending or {})
                state["pending"] = nil
                update_source_pool_now_21(session, next_args)
              end
              if state["dirty?"] then
                return schedule_source_pool_refresh_21({session = session})
              else
                return nil
              end
            else
              return nil
            end
          else
            return nil
          end
        end
        return vim.defer_fn(_41_, math.max((session["project-lazy-refresh-min-ms"] or 0), (session["project-lazy-refresh-debounce-ms"] or 17)))
      else
        return nil
      end
    end
  else
    return nil
  end
end
return {name = "core-events", domain = "core", events = {["on-source-pool-change!"] = {handler = schedule_source_pool_refresh_21, priority = 35}, ["on-query-update!"] = {handler = refresh_ui_21, priority = 40}, ["on-selection-change!"] = {handler = refresh_selection_ui_21, priority = 40}, ["on-session-ready!"] = {handler = refresh_ui_21, priority = 40}, ["on-restore-ui!"] = {handler = refresh_ui_21, priority = 40}, ["on-restore-view!"] = {handler = restore_view_only_21, priority = 40}, ["on-source-syntax-refresh!"] = {handler = refresh_source_syntax_only_21, priority = 40}, ["on-mode-switch!"] = {handler = refresh_statusline_only_21, priority = 40}, ["on-prompt-focus!"] = {handler = refresh_statusline_only_21, priority = 40}, ["on-loading-state!"] = {handler = refresh_statusline_only_21, priority = 40}, ["on-project-bootstrap!"] = {handler = refresh_project_info_21, priority = 40}, ["on-project-complete!"] = {handler = refresh_project_info_21, priority = 40}, ["on-source-switch!"] = {handler = reset_source_derived_ui_21, priority = 30}}}
