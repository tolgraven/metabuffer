-- [nfnl] fnl/metabuffer/events.fnl
local M = {}
local debug = require("metabuffer.debug")
local default_priority = 50
local handlers_by_event = {}
local profile_stats = {}
local profile_3f = false
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
local function accumulate_profile_21(event_key, spec, elapsed_us, ok, err)
  local event_stats = (profile_stats[event_key] or {})
  if (profile_stats[event_key] == nil) then
    profile_stats[event_key] = event_stats
  else
  end
  event_stats.count = (1 + (event_stats.count or 0))
  event_stats.elapsed_us = (elapsed_us + (event_stats.elapsed_us or 0))
  local key = ((spec.domain or "?") .. "/" .. (spec.source or "?"))
  local handler_stats = (event_stats[key] or {})
  if (event_stats[key] == nil) then
    event_stats[key] = handler_stats
  else
  end
  handler_stats.count = (1 + (handler_stats.count or 0))
  handler_stats.elapsed_us = (elapsed_us + (handler_stats.elapsed_us or 0))
  if not ok then
    handler_stats.last_error = tostring(err)
    return nil
  else
    return nil
  end
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
    local function _11_(a, b)
      return (a.priority < b.priority)
    end
    table.sort(list, _11_)
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
local function pcall_handler_21(spec, event_key, args)
  if profile_3f then
    local t0 = vim.uv.hrtime()
    local ok, err = pcall(spec.handler, args)
    local elapsed_us = ((vim.uv.hrtime() - t0) / 1000)
    accumulate_profile_21(event_key, spec, elapsed_us, ok, err)
    local function _15_()
      if ok then
        return ""
      else
        return ("  ERR: " .. tostring(err))
      end
    end
    return debug.log("event-bus", string.format("%s  %s/%s  p=%d  %.1f\194\181s%s", event_key, (spec.domain or "?"), (spec.source or "?"), spec.priority, elapsed_us, _15_()))
  else
    return pcall(spec.handler, args)
  end
end
M.send = function(event_key, args)
  local list = handlers_by_event[event_key]
  local args_2a = (args or {})
  if list then
    for _, spec in ipairs(list) do
      if matches_filter_3f(spec, args_2a) then
        pcall_handler_21(spec, event_key, args_2a)
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
