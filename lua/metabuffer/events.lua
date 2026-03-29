-- [nfnl] fnl/metabuffer/events.fnl
local M = {}
local debug = require("metabuffer.debug")
local default_priority = 50
local handlers_by_event = {}
local profile_stats = {}
local profile_3f = false
local function cpu_us()
  local uv = (vim.uv or vim.loop)
  local usage = (uv and uv.getrusage and uv.getrusage())
  if usage then
    return ((usage.utime.sec * 1000000) + usage.utime.usec + (usage.stime.sec * 1000000) + usage.stime.usec)
  else
    return 0
  end
end
M["set-profile!"] = function(enabled)
  profile_3f = not not enabled
  return nil
end
local function clear_profile_stats_21()
  for k, _ in pairs(profile_stats) do
    profile_stats[k] = nil
  end
  return nil
end
local function event_stats_for(event_key)
  local event_stats = (profile_stats[event_key] or {})
  if (profile_stats[event_key] == nil) then
    profile_stats[event_key] = event_stats
  else
  end
  if (event_stats.emissions == nil) then
    event_stats["emissions"] = {}
  else
  end
  return event_stats
end
local function handler_key(spec)
  return ((spec.domain or "?") .. "/" .. (spec.source or "?"))
end
local function handler_stats_for(event_stats, key)
  local handler_stats = (event_stats[key] or {})
  if (event_stats[key] == nil) then
    event_stats[key] = handler_stats
  else
  end
  return handler_stats
end
local function start_emission_21(event_key)
  local event_stats = event_stats_for(event_key)
  local emissions = event_stats.emissions
  local emission = {index = (#emissions + 1), event = event_key, elapsed_us = 0, cpu_us = 0, handler_count = 0, handlers = {}}
  table.insert(emissions, emission)
  event_stats.count = (1 + (event_stats.count or 0))
  return {event_stats, emission}
end
local function accumulate_profile_21(event_stats, emission, spec, elapsed_us, cpu_elapsed_us, ok, err)
  event_stats.handler_count = (1 + (event_stats.handler_count or 0))
  event_stats.elapsed_us = (elapsed_us + (event_stats.elapsed_us or 0))
  event_stats.cpu_us = (cpu_elapsed_us + (event_stats.cpu_us or 0))
  emission.handler_count = (1 + (emission.handler_count or 0))
  emission.elapsed_us = (elapsed_us + (emission.elapsed_us or 0))
  emission.cpu_us = (cpu_elapsed_us + (emission.cpu_us or 0))
  local handler_key0 = handler_key(spec)
  local handler_stats = handler_stats_for(event_stats, handler_key0)
  local handler_run = {domain = (spec.domain or "?"), source = (spec.source or "?"), priority = (spec.priority or default_priority), elapsed_us = elapsed_us, cpu_us = cpu_elapsed_us, ok = ok}
  handler_stats.count = (1 + (handler_stats.count or 0))
  handler_stats.elapsed_us = (elapsed_us + (handler_stats.elapsed_us or 0))
  handler_stats.cpu_us = (cpu_elapsed_us + (handler_stats.cpu_us or 0))
  if not ok then
    handler_stats.last_error = tostring(err)
    handler_run.error = tostring(err)
  else
  end
  return table.insert(emission.handlers, handler_run)
end
local function normalize_spec(spec)
  if (type(spec) == "function") then
    return {handler = spec, priority = default_priority}
  else
    local out = vim.deepcopy(spec)
    if not out.priority then
      out.priority = default_priority
    else
    end
    return out
  end
end
local function register_module_21(mod)
  local events = (mod.events or {})
  local mod_name = (mod.name or "?")
  local mod_domain = (mod.domain or "?")
  for _, list in pairs(handlers_by_event) do
    local i = #list
    while (i > 0) do
      do
        local spec = list[i]
        if (((spec.source or "?") == mod_name) and ((spec.domain or "?") == mod_domain)) then
          table.remove(list, i)
        else
        end
      end
      i = (i - 1)
    end
  end
  for event_key, raw in pairs(events) do
    local specs
    if ((type(raw) == "table") and raw[1]) then
      specs = raw
    else
      specs = {raw}
    end
    for _, raw_spec in ipairs(specs) do
      local spec = normalize_spec(raw_spec)
      if (type(spec.handler) == "function") then
        if not spec.source then
          spec.source = mod_name
        else
        end
        if not spec.domain then
          spec.domain = mod_domain
        else
        end
        if not handlers_by_event[event_key] then
          handlers_by_event[event_key] = {}
        else
        end
        table.insert(handlers_by_event[event_key], spec)
      else
      end
    end
  end
  return nil
end
local function sort_handlers_21()
  for _, list in pairs(handlers_by_event) do
    local function _14_(a, b)
      return (a.priority < b.priority)
    end
    table.sort(list, _14_)
  end
  return nil
end
local function matches_filter_3f(spec, args)
  if (spec["role-filter"] and not (spec["role-filter"] == nil)) then
    local filter = spec["role-filter"]
    local role = args.role
    local roles
    if (type(filter) == "table") then
      roles = filter
    else
      roles = {filter}
    end
    local hit = false
    local found = hit
    for _, r in ipairs(roles) do
      if found then break end
      if (r == role) then
        found = true
      else
      end
    end
    return found
  else
    return true
  end
end
local function pcall_handler_21(spec, event_key, args, event_stats, emission)
  if profile_3f then
    local t0 = vim.uv.hrtime()
    local cpu0 = cpu_us()
    local ok, err = pcall(spec.handler, args)
    local elapsed_us = ((vim.uv.hrtime() - t0) / 1000)
    local cpu_elapsed_us = math.max(0, (cpu_us() - cpu0))
    accumulate_profile_21(event_stats, emission, spec, elapsed_us, cpu_elapsed_us, ok, err)
    local function _18_()
      if ok then
        return ""
      else
        return ("  ERR: " .. tostring(err))
      end
    end
    return debug.log("event-bus", string.format("%s  %s/%s  p=%d  wall=%.1f\194\181s cpu=%.1f\194\181s%s", event_key, (spec.domain or "?"), (spec.source or "?"), spec.priority, elapsed_us, cpu_elapsed_us, _18_()))
  else
    return pcall(spec.handler, args)
  end
end
M.send = function(event_key, args)
  local list = handlers_by_event[event_key]
  local args_2a = (args or {})
  local function _20_()
    if (profile_3f and list) then
      return start_emission_21(event_key)
    else
      return {nil, nil}
    end
  end
  local _let_21_ = _20_()
  local event_stats = _let_21_[1]
  local emission = _let_21_[2]
  if list then
    for _, spec in ipairs(list) do
      if matches_filter_3f(spec, args_2a) then
        pcall_handler_21(spec, event_key, args_2a, event_stats, emission)
      else
      end
    end
    return nil
  else
    return nil
  end
end
M["register!"] = function(mod)
  register_module_21(mod)
  return sort_handlers_21()
end
M["load-providers!"] = function(providers)
  for _, mod in ipairs((providers or {})) do
    register_module_21(mod)
  end
  return sort_handlers_21()
end
M["registered-events"] = function()
  local names = {}
  for k, _ in pairs(handlers_by_event) do
    table.insert(names, k)
  end
  table.sort(names)
  return names
end
M["handlers-for"] = function(event_key)
  return handlers_by_event[event_key]
end
M["profile-stats"] = function()
  return vim.deepcopy(profile_stats)
end
M["reset-profile-stats!"] = function()
  return clear_profile_stats_21()
end
return M
