local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['statusline remains on prompt window only'] = H.timed_case(function()
  H.open_meta_with_lines({
    'meta one',
    'meta two',
    'meta three',
    'meta four',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 4 end, 3000)

  local prompt_sl = H.session_statusline()
  local main_sl = H.session_main_statusline()

  eq(type(prompt_sl), 'string')
  eq(#prompt_sl > 0, true)
  eq(main_sl == '' or main_sl == ' ', true)
end)

return T
