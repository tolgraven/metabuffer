local H = require('tests.screen.support.screen_helpers')
local profiler = require('tests.support.profiler')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

local function run_scroll_profile(backend)
  H.configure_animation({
    ui = {
      animation = {
        enabled = true,
        loading_indicator = false,
        prompt = { enabled = false },
        preview = { enabled = false },
        info = { enabled = false },
        loading = { enabled = false },
        scroll = { enabled = true, time_scale = 1.0, backend = backend },
      },
    },
  })

  local lines = {}
  for i = 1, 2200 do
    lines[i] = ('profile line %04d'):format(i)
  end

  H.open_meta_with_lines(lines)
  H.set_session_main_view(120, 126, 12)

  local cycles = profiler.enabled() and 2 or 3
  profiler.measure('bench', 'scroll backend ' .. backend, function()
    for _ = 1, cycles do
      H.scroll_main_and_wait('page-down', 4000)
    end
    for _ = 1, cycles do
      H.scroll_main_and_wait('page-up', 4000)
    end
  end)

  local final_view = H.session_main_view()
  eq(final_view.topline, 120)
  eq(final_view.lnum, 126)
end

T['scroll profiling benchmark uses native backend'] = H.timed_case(function()
  run_scroll_profile('native')
end)

T['scroll profiling benchmark uses mini backend'] = H.timed_case(function()
  run_scroll_profile('mini')
end)

return T
