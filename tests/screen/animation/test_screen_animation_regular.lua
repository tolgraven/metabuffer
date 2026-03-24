local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular Meta uses animated mini backend during scroll'] = H.timed_case(function()
  H.configure_animation({
    ui = {
      animation = {
        enabled = true,
        loading_indicator = true,
        backend = 'mini',
      },
    },
  })

  local lines = {}
  for i = 1, 120 do
    lines[i] = string.format('regular animated line %03d', i)
  end

  H.open_meta_with_lines(lines)
  local before = H.session_main_view()
  local target = H.scroll_main_and_wait('half-down', 3000)
  local after = H.session_main_view()

  eq(H.session_active(), true)
  eq(H.session_preview_visible(), true)
  eq(after.topline, target.topline)
  eq(after.lnum, target.lnum)
  eq(after.topline > before.topline, true)
end)

return T
