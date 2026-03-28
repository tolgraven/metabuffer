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

local function measure_ms(fn)
  local t0 = vim.loop.hrtime()
  fn()
  return (vim.loop.hrtime() - t0) / 1e6
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
  local bootstrap_event_ms = elapsed_ms(after_bootstrap, 'on-project-bootstrap!')
  local complete_event_ms = elapsed_ms(after_bootstrap, 'on-project-complete!')

  profiler.record(
    'event',
    string.format(
      'project bootstrap total=%.3fms bootstrap=%.3fms complete=%.3fms',
      bootstrap_ms, bootstrap_event_ms, complete_event_ms
    ),
    bootstrap_ms
  )
  profiler.record('event-bootstrap', 'on-project-bootstrap handlers', bootstrap_event_ms)
  profiler.record('event-complete', 'on-project-complete handlers', complete_event_ms)

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
  local query_event_ms = elapsed_ms(after_filter, 'on-query-update!')

  profiler.record(
    'event',
    string.format(
      'project filter total=%.3fms query=%.3fms gap=%.3fms',
      filter_ms, query_event_ms, math.max(0, filter_ms - query_event_ms)
    ),
    filter_ms
  )
  profiler.record('event-query', 'on-query-update handlers', query_event_ms)

  eq(bootstrap_event_ms > 0 or complete_event_ms > 0, true)
  eq(query_event_ms > 0, true)
  eq(bootstrap_ms >= bootstrap_event_ms, true)
  eq(filter_ms >= query_event_ms, true)
end)

return T
