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

T['query update profile stays below end-to-end elapsed time'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'beta two',
    'alpha three',
    'delta four',
  })

  H.wait_for(function()
    return H.session_hit_count() == 4
  end)

  reset_event_profile()

  local t0 = vim.loop.hrtime()
  H.type_prompt_text('alpha')
  H.wait_for(function()
    return H.session_hit_count() == 2
  end)
  local total_us = (vim.loop.hrtime() - t0) / 1000

  local stats = event_profile_stats()
  local query = stats['on-query-update!'] or {}
  local event_ms = (query.elapsed_us or 0) / 1000
  local total_ms = total_us / 1000
  local uncovered_ms = math.max(0, total_ms - event_ms)

  profiler.record(
    'event',
    string.format('query total=%.3fms event=%.3fms gap=%.3fms', total_ms, event_ms, uncovered_ms),
    total_ms
  )
  profiler.record('event-handlers', 'on-query-update handlers', event_ms)
  profiler.record('event-gap', 'query update outside event handlers', uncovered_ms)

  eq(type(query.elapsed_us), 'number')
  eq(query.elapsed_us > 0, true)
  eq(total_us >= query.elapsed_us, true)
end)

return T
