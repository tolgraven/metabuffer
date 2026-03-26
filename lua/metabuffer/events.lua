-- [nfnl] fnl/metabuffer/events.fnl
local M = {}
local debug = require("metabuffer.debug")
local default_priority = 50
local handlers_by_event = {}
local profile_3f = false
M["set-profile!"] = function(enabled)
  profile_3f = not not enabled
  return nil
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
    local function _8_(a, b)
      return (a.priority < b.priority)
    end
    table.sort(list, _8_)
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
    local function _12_()
      if ok then
        return ""
      else
        return ("  ERR: " .. tostring(err))
      end
    end
    return debug.log("event-bus", string.format("%s  %s/%s  p=%d  %.1f\194\181s%s", event_key, (spec.domain or "?"), (spec.source or "?"), spec.priority, elapsed_us, _12_()))
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
return M
