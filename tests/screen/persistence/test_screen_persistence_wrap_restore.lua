local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['results wrap persists across regular Meta reopen'] = H.timed_case(function()
  local lines = {}
  for i = 1, 160 do
    lines[#lines + 1] = ('this is a deliberately long metabuffer wrap restore line number ' .. i .. ' with enough text to wrap')
  end

  H.open_meta_with_lines(lines)
  H.wait_for(function() return H.session_active() end, 3000)

  H.set_session_main_wrap(true)
  H.wait_for(function() return H.session_main_wrap() == true end, 3000)

  H.feed_prompt_key('<Esc>', 'insert')
  H.wait_for(function() return H.session_ui_hidden() == true end, 3000)

  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(function() return H.session_active() and H.session_ui_hidden() == false end, 3000)
  H.wait_for(function() return H.session_main_wrap() == true end, 3000)

  eq(H.session_main_wrap(), true)
end)

return T
