local H = require('tests.screen.support.screen_helpers')
local profiler = require('tests.support.profiler')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function reset_event_profile()
  child.lua([[
    local events = require('metabuffer.events')
    events['set-profile!'](true)
    events['reset-profile-stats!']()
  ]])
end

local function event_profile_stats()
  local encoded = child.lua_get([[
    (function()
      local events = require('metabuffer.events')
      return vim.json.encode(events['profile-stats']())
    end)()
  ]])
  return vim.json.decode(encoded)
end

local function elapsed_ms(stats, key)
  local item = stats[key] or {}
  return (item.elapsed_us or 0) / 1000
end

local function cpu_ms(stats, key)
  local item = stats[key] or {}
  return (item.cpu_us or 0) / 1000
end

local function measure_ms(fn)
  local t0 = vim.loop.hrtime()
  fn()
  return (vim.loop.hrtime() - t0) / 1e6
end

local function sorted_event_keys(stats)
  local keys = {}
  for key, value in pairs(stats or {}) do
    if type(key) == 'string' and type(value) == 'table' then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return keys
end

local function emission_ms(item, key)
  return (item[key] or 0) / 1000
end

local function record_event_trace(phase, stats)
  for _, event_key in ipairs(sorted_event_keys(stats)) do
    local item = stats[event_key] or {}
    profiler.note(string.format(
      '%s %s totals | emits=%d handlers=%d wall=%.3fms cpu=%.3fms',
      phase,
      event_key,
      item.count or 0,
      item.handler_count or 0,
      emission_ms(item, 'elapsed_us'),
      emission_ms(item, 'cpu_us')
    ))
    for i, emission in ipairs(item.emissions or {}) do
      profiler.note(string.format(
        '%s %s emit#%d | handlers=%d wall=%.3fms cpu=%.3fms',
        phase,
        event_key,
        i,
        emission.handler_count or 0,
        emission_ms(emission, 'elapsed_us'),
        emission_ms(emission, 'cpu_us')
      ))
      for j, handler in ipairs(emission.handlers or {}) do
        profiler.note(string.format(
          '%s %s emit#%d handler#%d %s/%s p=%s | wall=%.3fms cpu=%.3fms%s',
          phase,
          event_key,
          i,
          j,
          handler.domain or '?',
          handler.source or '?',
          tostring(handler.priority or '?'),
          emission_ms(handler, 'elapsed_us'),
          emission_ms(handler, 'cpu_us'),
          handler.error and (' err=' .. handler.error) or ''
        ))
      end
    end
  end
end

T['project bootstrap and filtering profile through event bus'] = H.timed_case(function()
  reset_event_profile()

  local bootstrap_ms = measure_ms(function()
    H.open_project_meta_from_file('README.md')
    H.wait_for(function()
      return H.session_source_path_count() > 1
    end, 6000)
  end)
  profiler.record('bench', 'project bootstrap total', bootstrap_ms)

  local after_bootstrap = event_profile_stats()
  local source_change_ms = elapsed_ms(after_bootstrap, 'on-source-pool-change!')
  local source_change_cpu_ms = cpu_ms(after_bootstrap, 'on-source-pool-change!')
  local bootstrap_event_ms = elapsed_ms(after_bootstrap, 'on-project-bootstrap!')
  local complete_event_ms = elapsed_ms(after_bootstrap, 'on-project-complete!')
  local bootstrap_cpu_ms = cpu_ms(after_bootstrap, 'on-project-bootstrap!')
  local complete_cpu_ms = cpu_ms(after_bootstrap, 'on-project-complete!')

  profiler.record(
    'event',
    string.format(
      'project bootstrap total=%.3fms source=%.3fms cpu=%.3fms bootstrap=%.3fms cpu=%.3fms complete=%.3fms cpu=%.3fms',
      bootstrap_ms, source_change_ms, source_change_cpu_ms, bootstrap_event_ms, bootstrap_cpu_ms, complete_event_ms, complete_cpu_ms
    ),
    bootstrap_ms
  )
  profiler.record('event-source', 'on-source-pool-change handlers', source_change_ms)
  profiler.record('event-bootstrap', 'on-project-bootstrap handlers', bootstrap_event_ms)
  profiler.record('event-complete', 'on-project-complete handlers', complete_event_ms)
  record_event_trace('bootstrap', after_bootstrap)

  reset_event_profile()

  local filter_ms = measure_ms(function()
    H.type_prompt_text('meta docs')
    H.wait_for(function()
      return H.session_query_text() == 'meta docs'
    end, 6000)
    H.wait_for(function()
      return H.session_hit_count() > 0
    end, 6000)
  end)
  profiler.record('bench', 'project filter total', filter_ms)

  local after_filter = event_profile_stats()
  local filter_source_change_ms = elapsed_ms(after_filter, 'on-source-pool-change!')
  local filter_source_change_cpu_ms = cpu_ms(after_filter, 'on-source-pool-change!')
  local query_event_ms = elapsed_ms(after_filter, 'on-query-update!')
  local query_cpu_ms = cpu_ms(after_filter, 'on-query-update!')

  profiler.record(
    'event',
    string.format(
      'project filter total=%.3fms source=%.3fms cpu=%.3fms query=%.3fms cpu=%.3fms gap=%.3fms',
      filter_ms, filter_source_change_ms, filter_source_change_cpu_ms, query_event_ms, query_cpu_ms, math.max(0, filter_ms - filter_source_change_ms - query_event_ms)
    ),
    filter_ms
  )
  profiler.record('event-source', 'on-source-pool-change handlers', filter_source_change_ms)
  profiler.record('event-query', 'on-query-update handlers', query_event_ms)
  record_event_trace('filter', after_filter)

  eq(source_change_ms > 0, true)
  eq(bootstrap_event_ms > 0 or complete_event_ms > 0, true)
  eq(query_event_ms > 0, true)
  eq(bootstrap_ms >= source_change_ms, true)
  eq(filter_ms >= (filter_source_change_ms + query_event_ms), true)
end)

return T
