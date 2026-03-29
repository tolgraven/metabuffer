local events = require('metabuffer.events')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function unique_name(prefix)
  return string.format('%s-%d', prefix, vim.loop.hrtime())
end

T['posted events can supersede pending duplicates before flush'] = function()
  local calls = {}
  local event_name = unique_name('on-test-post!')

  events['register!']({
    name = unique_name('unit'),
    domain = 'unit',
    events = {
      [event_name] = function(args)
        calls[#calls + 1] = args.value
      end,
    },
  })

  events['set-profile!'](true)
  events['reset-profile-stats!']()

  events['post'](event_name, { value = 'first' }, { ['supersede?'] = true })
  events['post'](event_name, { value = 'second' }, { ['supersede?'] = true })
  events['flush-posted!']()

  local stats = events['profile-stats']()[event_name]

  eq(calls, { 'second' })
  eq(stats.posted_count, 1)
  eq(stats.flushed_count, 1)
  eq(stats.suppressed_count, 1)
  eq(stats.count, 1)
  eq(stats.emissions[1].mode, 'posted')
end

T['posted events keep separate queue entries without supersede'] = function()
  local calls = {}
  local event_name = unique_name('on-test-post-plain!')

  events['register!']({
    name = unique_name('unit'),
    domain = 'unit',
    events = {
      [event_name] = function(args)
        calls[#calls + 1] = args.value
      end,
    },
  })

  events['set-profile!'](true)
  events['reset-profile-stats!']()

  events['post'](event_name, { value = 'first' })
  events['post'](event_name, { value = 'second' })
  events['flush-posted!']()

  local stats = events['profile-stats']()[event_name]

  eq(calls, { 'first', 'second' })
  eq(stats.posted_count, 2)
  eq(stats.flushed_count, 2)
  eq(stats.suppressed_count, nil)
  eq(stats.count, 2)
end

T['posted superseding is isolated by dedupe key'] = function()
  local calls = {}
  local event_name = unique_name('on-test-post-keyed!')

  events['register!']({
    name = unique_name('unit'),
    domain = 'unit',
    events = {
      [event_name] = function(args)
        calls[#calls + 1] = args.value
      end,
    },
  })

  events['set-profile!'](true)
  events['reset-profile-stats!']()

  events['post'](event_name, { value = 'a1' }, { ['supersede?'] = true, ['dedupe-key'] = 'a' })
  events['post'](event_name, { value = 'b1' }, { ['supersede?'] = true, ['dedupe-key'] = 'b' })
  events['post'](event_name, { value = 'a2' }, { ['supersede?'] = true, ['dedupe-key'] = 'a' })
  events['flush-posted!']()

  local stats = events['profile-stats']()[event_name]

  eq(calls, { 'a2', 'b1' })
  eq(stats.posted_count, 2)
  eq(stats.flushed_count, 2)
  eq(stats.suppressed_count, 1)
  eq(stats.count, 2)
end

return T
