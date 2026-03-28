-- [nfnl] fnl/metabuffer/core_events.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local function refresh_hooks(session)
  return ((session and session["refresh-hooks"]) or {})
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
return {name = "core-events", domain = "core", events = {["on-query-update!"] = {handler = refresh_ui_21, priority = 40}, ["on-selection-change!"] = {handler = refresh_selection_ui_21, priority = 40}, ["on-session-ready!"] = {handler = refresh_ui_21, priority = 40}, ["on-restore-ui!"] = {handler = refresh_ui_21, priority = 40}, ["on-project-bootstrap!"] = {handler = refresh_project_info_21, priority = 40}, ["on-project-complete!"] = {handler = refresh_project_info_21, priority = 40}, ["on-source-switch!"] = {handler = reset_source_derived_ui_21, priority = 30}}}
